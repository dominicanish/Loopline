import SwiftUI

struct ConnectView: View {
    @EnvironmentObject private var model: AppModel
    var goToSession: () -> Void
    @AppStorage("colorSchemePref") private var schemePref = "light"

    private var connected: Bool { model.status == .connected }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                List {
                    Section {
                        Text("Your iPhone, bridged to your PC over a USB cable.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .listRowBackground(Color.clear)
                            .listRowInsets(EdgeInsets(top: 0, leading: 4, bottom: 8, trailing: 4))
                    }

                    Section("Computer") {
                        if connected {
                            DeviceRow(
                                tile: IconTile(systemImage: "desktopcomputer", color: Palette.computerTile, size: 44),
                                title: model.peerName.isEmpty ? "Your PC" : model.peerName,
                                subtitle: "Connected · \(model.sampleRate / 1000) kHz · \(model.latencyMs) ms",
                                subtitleColor: Palette.outgoing,
                                accessory: .check)
                        } else {
                            DeviceRow(
                                tile: IconTile(systemImage: "desktopcomputer", color: .gray, size: 44),
                                title: "Waiting for your PC",
                                subtitle: "Run Loopline.Server.exe on Windows",
                                subtitleColor: .secondary,
                                accessory: .spinner)
                        }
                    }

                    Section("Session") {
                        Button {
                            goToSession()
                        } label: {
                            Label(connected ? "Open live session" : "Go to session", systemImage: "waveform")
                        }
                        .disabled(false)
                    }

                    Section {
                        EmptyView()
                    } footer: {
                        Text("Loopline links your iPhone and PC over USB — no Wi-Fi or network needed. Make sure Apple Devices (or iTunes) is installed so Windows can see your iPhone.")
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Connect")
            .toolbar { AppearanceToolbarButton(schemePref: $schemePref) }
        }
    }
}

/// A grouped-list device row matching the mockup's paired/available cells.
struct DeviceRow<Tile: View>: View {
    enum Accessory { case check, chevron, spinner, none }
    let tile: Tile
    let title: String
    let subtitle: String
    var subtitleColor: Color = .secondary
    var accessory: Accessory = .none

    var body: some View {
        HStack(spacing: 12) {
            tile
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.body.weight(.semibold)).foregroundStyle(.primary)
                Text(subtitle).font(.footnote).foregroundStyle(subtitleColor)
            }
            Spacer()
            switch accessory {
            case .check:
                Image(systemName: "checkmark.circle.fill").foregroundStyle(Palette.outgoing).font(.title3)
            case .chevron:
                Image(systemName: "chevron.right").foregroundStyle(.tertiary).font(.footnote.weight(.semibold))
            case .spinner:
                ProgressView()
            case .none:
                EmptyView()
            }
        }
        .padding(.vertical, 4)
    }
}

/// The little sun/moon button in the top-right of every screen.
struct AppearanceToolbarButton: ToolbarContent {
    @Binding var schemePref: String

    var body: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                schemePref = (schemePref == "dark") ? "light" : "dark"
            } label: {
                Image(systemName: schemePref == "dark" ? "moon.stars.fill" : "sun.max.fill")
            }
        }
    }
}
