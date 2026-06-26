import SwiftUI

/// Placeholder for the upcoming "Screen" feature. Kept as its own tab so the
/// next work can build on it.
struct ScreenView: View {
    @AppStorage("colorSchemePref") private var schemePref = "system"

    var body: some View {
        ZStack {
            WallBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .top) {
                        Text("Screen").font(.system(size: 34, weight: .bold))
                        Spacer()
                        ThemeToggleButton(schemePref: $schemePref)
                    }
                    .padding(.horizontal, 16).padding(.top, 8)

                    GlassCard {
                        VStack(spacing: 14) {
                            IconTile(systemImage: "rectangle.on.rectangle", color: Palette.indigo, size: 56, corner: 16)
                            Text("Coming soon")
                                .font(.system(size: 17, weight: .medium))
                            Text("This is where Screen will live. Next steps build on top of this tab.")
                                .font(.system(size: 14))
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24).padding(.horizontal, 16)
                    }
                    .padding(.horizontal, 16).padding(.top, 12)
                }
                .padding(.vertical, 8)
            }
        }
    }
}
