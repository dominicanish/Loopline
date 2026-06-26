import SwiftUI

/// Shared visual language for Loopline — the "Liquid Glass" look from the
/// design: translucent glass cards floating over a soft radial-gradient wall.
enum Palette {
    static let blue   = Color(red: 0x0A/255, green: 0x84/255, blue: 0xFF/255)
    static let green  = Color(red: 0x34/255, green: 0xC7/255, blue: 0x59/255)
    static let red    = Color(red: 0xFF/255, green: 0x3B/255, blue: 0x30/255)
    static let indigo = Color(red: 0x5E/255, green: 0x5C/255, blue: 0xE6/255)
    static let teal   = Color(red: 0x30/255, green: 0xB0/255, blue: 0xC7/255)
    static let orange = Color(red: 0xFF/255, green: 0x95/255, blue: 0x00/255)
}

/// The colourful gradient "wall" the glass refracts (light + dark variants).
struct WallBackground: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let light = scheme != .dark
        ZStack {
            LinearGradient(
                colors: light
                    ? [Color(hex: 0xEEF1F6), Color(hex: 0xE6EAF1)]
                    : [Color(hex: 0x0A0B12), Color(hex: 0x05060A)],
                startPoint: .topLeading, endPoint: .bottomTrailing)
            blob(light ? 0xFFD9EA : 0x4A1D6B, x: 0.12, y: 0.0)
            blob(light ? 0xD6E6FF : 0x102E6E, x: 1.0, y: 0.06)
            blob(light ? 0xCFFAEC : 0x0B463F, x: 0.82, y: 1.0)
            blob(light ? 0xFFF0CB : 0x360F4A, x: 0.0, y: 1.0)
        }
        .ignoresSafeArea()
    }

    private func blob(_ hex: UInt, x: Double, y: Double) -> some View {
        RadialGradient(colors: [Color(hex: hex), .clear],
                       center: UnitPoint(x: x, y: y),
                       startRadius: 0, endRadius: 420)
    }
}

/// A translucent Liquid Glass card with the design's 22pt rounding.
struct GlassCard<Content: View>: View {
    var cornerRadius: CGFloat = 22
    @ViewBuilder var content: Content

    var body: some View {
        content
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.18))
            )
    }
}

/// Grey, uppercase, inset section header like the mockup's "PAIRED" / "AUDIO".
struct SectionHeader: View {
    let text: String
    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 13))
            .tracking(0.2)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 32)
            .padding(.trailing, 16)
            .padding(.top, 22)
            .padding(.bottom, 7)
    }
}

/// Hairline divider inset from the left like a grouped-list separator.
struct RowDivider: View {
    var inset: CGFloat = 16
    var body: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.10))
            .frame(height: 0.5)
            .padding(.leading, inset)
    }
}

/// A rounded-square coloured icon tile with a white SF Symbol.
struct IconTile: View {
    let systemImage: String
    let color: Color
    var size: CGFloat = 38
    var corner: CGFloat = 10

    var body: some View {
        RoundedRectangle(cornerRadius: corner, style: .continuous)
            .fill(color)
            .frame(width: size, height: size)
            .overlay(
                Image(systemName: systemImage)
                    .font(.system(size: size * 0.44, weight: .semibold))
                    .foregroundStyle(.white)
            )
    }
}

/// The round glass sun/moon button that toggles light/dark, top-right of screens.
struct ThemeToggleButton: View {
    @Binding var schemePref: String
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        Button {
            schemePref = (effectiveDark) ? "light" : "dark"
        } label: {
            Image(systemName: effectiveDark ? "moon.fill" : "sun.max.fill")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.primary)
                .frame(width: 36, height: 36)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .circle)
    }

    private var effectiveDark: Bool {
        switch schemePref {
        case "dark": return true
        case "light": return false
        default: return scheme == .dark
        }
    }
}

/// A live, spectrum-style level meter (bars scale with the audio level).
struct MeterView: View {
    var level: Float
    var color: Color
    var bars: Int = 18

    var body: some View {
        TimelineView(.animation(minimumInterval: 0.06)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            GeometryReader { geo in
                HStack(alignment: .bottom, spacing: 2) {
                    ForEach(0 ..< bars, id: \.self) { i in
                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                            .fill(color)
                            .frame(maxWidth: .infinity)
                            .frame(height: barHeight(i, t: t, max: geo.size.height))
                    }
                }
                .frame(height: geo.size.height, alignment: .bottom)
            }
        }
        .frame(height: 30)
    }

    private func barHeight(_ i: Int, t: Double, max maxH: CGFloat) -> CGFloat {
        let lvl = CGFloat(min(1, max(0, level)))
        let phase = sin(t * 6 + Double(i) * 0.7) * 0.5 + 0.5
        let envelope = 0.35 + 0.65 * phase
        return Swift.max(3, (0.16 + 0.84 * lvl * CGFloat(envelope)) * maxH)
    }
}

extension Color {
    init(hex: UInt) {
        self.init(red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255)
    }
}
