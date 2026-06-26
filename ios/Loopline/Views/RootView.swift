import SwiftUI

struct RootView: View {
    @EnvironmentObject private var model: AppModel
    @State private var selection: Screen = .connect

    enum Screen: Hashable { case connect, session, screen, settings }

    var body: some View {
        TabView(selection: $selection) {
            Tab("Connect", systemImage: "personalhotspot", value: Screen.connect) {
                ConnectView()
            }
            // Session and Screen only exist once the server handshake is confirmed.
            if connected {
                Tab("Session", systemImage: "waveform", value: Screen.session) {
                    SessionView()
                }
                Tab("Screen", systemImage: "rectangle.on.rectangle", value: Screen.screen) {
                    ScreenView()
                }
            }
            Tab("Settings", systemImage: "gearshape", value: Screen.settings) {
                SettingsView()
            }
        }
        .onChange(of: connected) { _, isConnected in
            if isConnected {
                selection = .session
            } else if selection == .session || selection == .screen {
                selection = .connect
            }
        }
    }

    private var connected: Bool { model.status == .connected }
}

#Preview {
    RootView().environmentObject(AppModel())
}
