import SwiftUI

struct SessionView: View {
    @EnvironmentObject private var model: AppModel
    @AppStorage("colorSchemePref") private var schemePref = "system"

    private var connected: Bool { model.status == .connected }

    var body: some View {
        ZStack {
            WallBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    header
                    bridgeCard.padding(.horizontal, 16).padding(.top, 18)

                    SectionHeader(text: "Incoming · Computer audio")
                    incomingCard.padding(.horizontal, 16)

                    SectionHeader(text: "Outgoing · Your microphone")
                    outgoingCard.padding(.horizontal, 16)

                    actionButton.padding(.horizontal, 16).padding(.top, 24)
                    elapsed
                }
                .padding(.vertical, 8)
            }
        }
    }

    // MARK: header

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                HStack(spacing: 7) {
                    Circle().fill(connected ? Palette.green : .orange).frame(width: 8, height: 8)
                    Text(connected ? (model.peerName.isEmpty ? "PC CONNECTED" : model.peerName.uppercased())
                                   : "WAITING FOR PC")
                        .font(.system(size: 13, weight: .semibold))
                }
                .padding(.leading, 9).padding(.trailing, 11).padding(.vertical, 6)
                .glassEffect(.regular, in: .capsule)
                Spacer()
                ThemeToggleButton(schemePref: $schemePref)
            }
            Text("Loopline").font(.system(size: 34, weight: .bold))
            Text("Two-way audio bridge over USB")
                .font(.system(size: 15)).foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    // MARK: bridge

    private var bridgeCard: some View {
        GlassCard(cornerRadius: 26) {
            VStack(spacing: 16) {
                HStack {
                    endpoint("desktopcomputer", Palette.blue, "Computer")
                    Spacer()
                    FlowDots(active: connected)
                    Spacer()
                    endpoint("iphone", Palette.indigo, "iPhone")
                }
                RowDivider(inset: 0)
                HStack(spacing: 8) {
                    Text("\(model.latencyMs) ms latency")
                    Text("·").foregroundStyle(.tertiary)
                    Text("\(model.sampleRate / 1000) kHz")
                    Text("·").foregroundStyle(.tertiary)
                    Text("PCM")
                }
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 18).padding(.vertical, 20)
        }
    }

    private func endpoint(_ symbol: String, _ color: Color, _ label: String) -> some View {
        VStack(spacing: 9) {
            IconTile(systemImage: symbol, color: color, size: 50, corner: 14)
            Text(label).font(.system(size: 12, weight: .semibold)).foregroundStyle(.secondary)
        }
    }

    // MARK: incoming

    private var incomingCard: some View {
        GlassCard {
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    IconTile(systemImage: "speaker.wave.2.fill", color: Palette.blue, size: 30, corner: 8)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Computer Audio").font(.system(size: 17, weight: .medium))
                        Text("System mix · Stereo").font(.system(size: 13)).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Toggle("", isOn: $model.speakerEnabled).labelsHidden().tint(Palette.green)
                }
                .padding(.horizontal, 16).padding(.vertical, 12)

                RowDivider()
                MeterView(level: model.speakerEnabled ? model.speakerLevel : 0, color: Palette.blue)
                    .opacity(model.speakerEnabled ? 1 : 0.25)
                    .padding(.horizontal, 16).padding(.vertical, 15)

                RowDivider()
                HStack(spacing: 11) {
                    Image(systemName: "speaker.fill").font(.system(size: 13)).foregroundStyle(.secondary)
                    Slider(value: $model.speakerVolume, in: 0...1).tint(.secondary)
                    Image(systemName: "speaker.wave.3.fill").font(.system(size: 13)).foregroundStyle(.secondary)
                }
                .padding(.horizontal, 16).padding(.vertical, 14)
            }
        }
    }

    // MARK: outgoing

    private var outgoingCard: some View {
        GlassCard {
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    IconTile(systemImage: "mic.fill", color: Palette.green, size: 30, corner: 8)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("iPhone Microphone").font(.system(size: 17, weight: .medium))
                        Text("Built-in · echo cancelled")
                            .font(.system(size: 13)).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Toggle("", isOn: $model.micEnabled).labelsHidden().tint(Palette.green)
                }
                .padding(.horizontal, 16).padding(.vertical, 12)

                RowDivider()
                VStack(spacing: 9) {
                    HStack {
                        Text("Input level").font(.system(size: 13, weight: .medium)).foregroundStyle(.secondary)
                        Spacer()
                        Text(model.micEnabled ? "Live" : "Muted")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(model.micEnabled ? Palette.green : Palette.red)
                    }
                    MeterView(level: model.micEnabled ? model.micLevel : 0, color: Palette.green)
                        .opacity(model.micEnabled ? 1 : 0.2)
                }
                .padding(.horizontal, 16).padding(.top, 13).padding(.bottom, 15)
            }
        }
    }

    // MARK: action

    private var actionButton: some View {
        Button {
            if model.running { model.stop() } else { model.start() }
        } label: {
            Text(model.running ? "End Session" : "Start Session")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(model.running
                              ? LinearGradient(colors: [Color(hex: 0xFF5A50), Color(hex: 0xFF2D28)],
                                               startPoint: .top, endPoint: .bottom)
                              : LinearGradient(colors: [Palette.green, Palette.green],
                                               startPoint: .top, endPoint: .bottom))
                )
                .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var elapsed: some View {
        TimelineView(.periodic(from: .now, by: 1)) { _ in
            Text(elapsedText)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.top, 9)
        }
    }

    private var elapsedText: String {
        guard connected, let since = model.connectedSince else {
            return model.running ? "Linking…" : "Not connected"
        }
        let s = Int(Date().timeIntervalSince(since))
        let m = s / 60, sec = s % 60
        return String(format: "Connected · %d:%02d elapsed", m, sec)
    }
}

/// Six dots pulsing between the two endpoints (the design's flowPulse).
struct FlowDots: View {
    var active: Bool
    var count: Int = 6

    var body: some View {
        TimelineView(.animation(minimumInterval: 0.08)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            HStack(spacing: 7) {
                ForEach(0 ..< count, id: \.self) { i in
                    Circle()
                        .fill(Palette.blue)
                        .frame(width: 6, height: 6)
                        .opacity(active ? pulse(i, t: t) : 0.18)
                }
            }
        }
    }

    private func pulse(_ i: Int, t: Double) -> Double {
        let cycle = 1.6
        let phase = ((t - Double(i) * 0.27) / cycle).truncatingRemainder(dividingBy: 1)
        return 0.18 + 0.82 * (sin(phase * .pi * 2) * 0.5 + 0.5)
    }
}
