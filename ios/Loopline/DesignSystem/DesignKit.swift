import SwiftUI

/// Shared visual language for Loopline — a light, Apple-HIG look with inset
/// grouped lists, soft tinted background and live audio meters.
enum Palette {
    static let incoming = Color(red: 0x0A/255, green: 0x84/255, blue: 0xFF/255) // blue
    static let outgoing = Color(red: 0x34/255, green: 0xC7/255, blue: 0x59/255) // green
    static let computerTile = Color(red: 0x0A/255, green: 0x84/255, blue: 0xFF/255)
    static let phoneTile = Color(red: 0x7A/255, green: 0x5A/255, blue: 0xF0/255)
}

/// Soft full-screen backdrop that sits behind the translucent lists.
struct AppBackground: View {
    var body: some View {
        ZStack {
            Color(.systemGroupedBackground)
            LinearGradient(
                colors: [
                    Color(red: 0xFF/255, green: 0xE9/255, blue: 0xF2/255).opacity(0.7),
                    Color.clear,
                    Color(red: 0xE6/255, green: 0xFB/255, blue: 0xEF/255).opacity(0.7),
                ],
                startPoint: .topTrailing, endPoint: .bottomLeading)
            LinearGradient(
                colors: [Color.clear, Color(red: 0xEE/255, green: 0xE7/255, blue: 0xFF/255).opacity(0.6)],
                startPoint: .top, endPoint: .bottom)
        }
        .ignoresSafeArea()
    }
}

/// A rounded white card used for the bespoke Session screen blocks.
struct Card<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.05))
            )
    }
}

/// A rounded-square app icon tile (computer / phone) with an SF Symbol.
struct IconTile: View {
    let systemImage: String
    let color: Color
    var size: CGFloat = 56

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.27, style: .continuous)
            .fill(color.gradient)
            .frame(width: size, height: size)
            .overlay(
                Image(systemName: systemImage)
                    .font(.system(size: size * 0.46, weight: .medium))
                    .foregroundStyle(.white)
            )
            .shadow(color: color.opacity(0.35), radius: 6, y: 3)
    }
}

/// A live, spectrum-style level meter. Bars animate around the supplied level.
struct MeterView: View {
    var level: Float          // 0...1
    var color: Color
    var bars: Int = 22

    var body: some View {
        TimelineView(.animation(minimumInterval: 0.06)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            GeometryReader { geo in
                let w = (geo.size.width - CGFloat(bars - 1) * 4) / CGFloat(bars)
                HStack(alignment: .center, spacing: 4) {
                    ForEach(0 ..< bars, id: \.self) { i in
                        Capsule(style: .continuous)
                            .fill(color.opacity(level > 0.02 ? 0.95 : 0.28))
                            .frame(width: max(2, w), height: barHeight(i, t: t, max: geo.size.height))
                    }
                }
                .frame(maxHeight: .infinity, alignment: .center)
            }
        }
        .frame(height: 40)
    }

    private func barHeight(_ i: Int, t: Double, max maxH: CGFloat) -> CGFloat {
        let lvl = CGFloat(min(1, max(0, level)))
        // A gentle standing-wave envelope so the bars look organic, scaled by level.
        let phase = sin(t * 6 + Double(i) * 0.7) * 0.5 + 0.5
        let envelope = 0.35 + 0.65 * phase
        let h = (0.12 + 0.88 * lvl * CGFloat(envelope)) * maxH
        return Swift.max(3, h)
    }
}

/// Small grey uppercase caption used as a faux section header inside cards.
struct Overline: View {
    let text: String
    var body: some View {
        Text(text.uppercased())
            .font(.caption2.weight(.semibold))
            .tracking(0.6)
            .foregroundStyle(.secondary)
    }
}
