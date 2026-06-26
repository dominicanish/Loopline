import SwiftUI

@main
struct LooplineApp: App {
    @StateObject private var model = AppModel()
    @AppStorage("colorSchemePref") private var schemePref = "light"

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(model)
                .tint(Palette.green)
                .preferredColorScheme(colorScheme)
        }
    }

    private var colorScheme: ColorScheme? {
        switch schemePref {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
    }
}
