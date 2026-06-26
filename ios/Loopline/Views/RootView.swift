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
            // Session is only reachable while a session is open.
            if model.running {
                Tab("Session", systemImage: "waveform", value: Screen.session) {
                    SessionView()
                }
            }
            Tab("Screen", systemImage: "rectangle.on.rectangle", value: Screen.screen) {
                ScreenView()
            }
            Tab("Settings", systemImage: "gearshape", value: Screen.settings) {
                SettingsView()
            }
        }
        .onChange(of: model.running) { _, running in
            selection = running ? .session : .connect
        }
    }
}

#Preview {
    RootView().environmentObject(AppModel())
}
