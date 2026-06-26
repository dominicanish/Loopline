import SwiftUI

struct ConnectView: View {
    @EnvironmentObject private var model: AppModel
    var goToSession: () -> Void
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

                    SectionHeader(text: "Session")
                    GlassCard {
                        Button(action: goToSession) {
                            HStack(spacing: 13) {
                                IconTile(systemImage: "waveform", color: Palette.indigo)
                                Text(connected ? "Open live session" : "Go to session")
                                    .font(.system(size: 17, weight: .medium))
                                    .foregroundStyle(.primary)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(.horizontal, 16).padding(.vertical, 13)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 16)

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
                IconTile(systemImage: "desktopcomputer", color: connected ? Palette.blue : .gray)
                VStack(alignment: .leading, spacing: 1) {
                    Text(connected ? (model.peerName.isEmpty ? "Your PC" : model.peerName) : "Waiting for your PC")
                        .font(.system(size: 17, weight: .medium))
                    Text(connected
                         ? "Connected · \(model.sampleRate / 1000) kHz · \(model.latencyMs) ms"
                         : "Run Loopline.Server.exe on Windows")
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
                } else {
                    ProgressView()
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 13)
        }
    }
}
