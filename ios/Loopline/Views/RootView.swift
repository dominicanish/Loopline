import SwiftUI

struct RootView: View {
    @EnvironmentObject private var model: AppModel
    @State private var selection: Screen = .session

    enum Screen { case connect, session, settings }

    var body: some View {
        TabView(selection: $selection) {
            Tab("Connect", systemImage: "personalhotspot", value: Screen.connect) {
                ConnectView(goToSession: { selection = .session })
            }
            Tab("Session", systemImage: "waveform", value: Screen.session) {
                SessionView()
            }
            Tab("Settings", systemImage: "gearshape", value: Screen.settings) {
                SettingsView()
            }
        }
    }
}

#Preview {
    RootView().environmentObject(AppModel())
}
