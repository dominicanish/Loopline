import SwiftUI

struct ConnectView: View {
    @EnvironmentObject private var model: AppModel
    @AppStorage("colorSchemePref") private var schemePref = "system"

    private var connected: Bool { model.status == .connected }

    var body: some View {
        ZStack {
            WallBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    header

                    SectionHeader(text: "Paired")
                    pairedCard.padding(.horizontal, 16)

                    startButton.padding(.horizontal, 16).padding(.top, 18)

                    Text("Loopline links your iPhone and PC directly over the USB cable — no Wi-Fi or network needed. Make sure Apple Devices (or iTunes) is installed so Windows can see your iPhone.")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 32)
                        .padding(.top, 18)
                }
                .padding(.vertical, 8)
            }
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Connect")
                    .font(.system(size: 34, weight: .bold))
                Text("Your iPhone, bridged to your PC over USB")
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            ThemeToggleButton(schemePref: $schemePref)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    private var pairedCard: some View {
        GlassCard {
            HStack(spacing: 13) {
                IconTile(systemImage: "desktopcomputer",
                         color: connected ? Palette.blue : Palette.indigo.opacity(0.65))
                VStack(alignment: .leading, spacing: 1) {
                    Text(title).font(.system(size: 17, weight: .medium))
                    Text(subtitle)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(connected ? Palette.green : .secondary)
                }
                Spacer()
                if connected {
                    ZStack {
                        Circle().fill(Palette.green).frame(width: 24, height: 24)
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)
                    }
                } else if model.running {
                    ProgressView()
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 13)
        }
    }

    private var title: String {
        if connected { return model.peerName.isEmpty ? "Your PC" : model.peerName }
        return model.running ? "Looking for your PC…" : "No computer connected"
    }

    private var subtitle: String {
        if connected { return "Connected · \(model.sampleRate / 1000) kHz · \(model.latencyMs) ms" }
        return model.running
            ? "Keep your iPhone plugged in with Loopline open on your PC"
            : "Tap Start Session to begin"
    }

    private var startButton: some View {
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
}
