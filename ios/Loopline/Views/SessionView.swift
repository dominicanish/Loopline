import SwiftUI

struct SessionView: View {
    @EnvironmentObject private var model: AppModel
    @AppStorage("colorSchemePref") private var schemePref = "light"

    private var connected: Bool { model.status == .connected }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        header
                        bridgeCard
                        incomingBlock
                        outgoingBlock
                        actionButton
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) { EmptyView() }
                AppearanceToolbarButton(schemePref: $schemePref)
            }
        }
    }

    // MARK: header

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Circle().fill(connected ? Palette.outgoing : .orange).frame(width: 8, height: 8)
                Text(connected ? (model.peerName.isEmpty ? "PC CONNECTED" : model.peerName.uppercased())
                               : "WAITING FOR PC")
                    .font(.caption2.weight(.bold)).tracking(0.5)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(Capsule().fill(Color(.secondarySystemGroupedBackground)))
            .overlay(Capsule().strokeBorder(Color.primary.opacity(0.06)))

            Text("Loopline")
                .font(.largeTitle.bold())
            Text("Two-way audio bridge over USB")
                .font(.subheadline).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 4)
    }

    // MARK: bridge diagram

    private var bridgeCard: some View {
        Card {
            VStack(spacing: 14) {
                HStack {
                    endpoint(tile: IconTile(systemImage: "desktopcomputer", color: Palette.computerTile),
                             label: "Computer")
                    Spacer()
                    FlowDots(active: connected)
                    Spacer()
                    endpoint(tile: IconTile(systemImage: "iphone", color: Palette.phoneTile),
                             label: "iPhone")
                }
                Divider().opacity(0.5)
                Text("\(model.latencyMs) ms latency  ·  \(model.sampleRate / 1000) kHz  ·  PCM")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
    }

    private func endpoint<V: View>(tile: V, label: String) -> some View {
        VStack(spacing: 8) {
            tile
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
    }

    // MARK: incoming (computer -> iPhone)

    private var incomingBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Overline(text: "Incoming · Computer audio")
            Card {
                VStack(spacing: 14) {
                    HStack(spacing: 12) {
                        IconTile(systemImage: "speaker.wave.2.fill", color: Palette.incoming, size: 40)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Computer Audio").font(.body.weight(.semibold))
                            Text("System mix · Stereo").font(.footnote).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Toggle("", isOn: $model.speakerEnabled).labelsHidden().tint(Palette.outgoing)
                    }
                    MeterView(level: model.speakerEnabled ? model.speakerLevel : 0, color: Palette.incoming)
                    HStack(spacing: 10) {
                        Image(systemName: "speaker.fill").foregroundStyle(.secondary).font(.footnote)
                        Slider(value: $model.speakerVolume, in: 0...1)
                            .tint(Palette.incoming)
                        Image(systemName: "speaker.wave.3.fill").foregroundStyle(.secondary).font(.footnote)
                    }
                }
            }
        }
    }

    // MARK: outgoing (iPhone mic -> computer)

    private var outgoingBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Overline(text: "Outgoing · Your microphone")
            Card {
                VStack(spacing: 14) {
                    HStack(spacing: 12) {
                        IconTile(systemImage: "mic.fill", color: Palette.outgoing, size: 40)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("iPhone Microphone").font(.body.weight(.semibold))
                            Text(model.echoCancellation ? "Built-in · Voice isolation" : "Built-in")
                                .font(.footnote).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Toggle("", isOn: $model.micEnabled).labelsHidden().tint(Palette.outgoing)
                    }
                    ZStack(alignment: .topTrailing) {
                        MeterView(level: model.micEnabled ? model.micLevel : 0, color: Palette.outgoing)
                        if model.micEnabled && model.running {
                            Text("LIVE")
                                .font(.caption2.weight(.bold)).foregroundStyle(Palette.outgoing)
                        }
                    }
                }
            }
        }
    }

    // MARK: action

    private var actionButton: some View {
        Button {
            if model.running { model.stop() } else { model.start() }
        } label: {
            Text(model.running ? "End Session" : "Start Session")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
        }
        .buttonStyle(.borderedProminent)
        .tint(model.running ? .red : Palette.outgoing)
        .controlSize(.large)
        .padding(.top, 4)
    }
}

/// Animated row of dots flowing between the two endpoints in the bridge card.
struct FlowDots: View {
    var active: Bool
    var count: Int = 5

    var body: some View {
        TimelineView(.animation(minimumInterval: 0.1)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            HStack(spacing: 6) {
                ForEach(0 ..< count, id: \.self) { i in
                    Circle()
                        .fill(Palette.incoming)
                        .frame(width: 6, height: 6)
                        .opacity(active ? dotOpacity(i, t: t) : 0.2)
                }
            }
        }
    }

    private func dotOpacity(_ i: Int, t: Double) -> Double {
        let phase = (t * 1.6).truncatingRemainder(dividingBy: Double(count))
        let d = abs(phase - Double(i))
        return max(0.25, 1 - d * 0.6)
    }
}
