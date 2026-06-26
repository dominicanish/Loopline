import SwiftUI

/// A small status pill that floats on a glass capsule.
struct StatusPill: View {
    let connected: Bool
    let text: String

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(connected ? Brand.mic : .orange)
                .frame(width: 9, height: 9)
                .shadow(color: connected ? Brand.mic : .orange, radius: 5)
            Text(text)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 9)
        .glassEffect(.regular, in: .capsule)
    }
}

/// A horizontal level meter rendered as a row of rounded bars.
struct LevelMeter: View {
    var level: Float          // 0...1
    var tint: Color
    var bars: Int = 14

    var body: some View {
        GeometryReader { geo in
            let lit = Int((Float(bars) * level).rounded())
            HStack(spacing: 3) {
                ForEach(0 ..< bars, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(i < lit ? tint : Color.white.opacity(0.18))
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(height: geo.size.height)
            .animation(.linear(duration: 0.08), value: lit)
        }
        .frame(height: 18)
    }
}

/// A big glass tile that toggles a route (mic or speaker) and shows its level.
struct RouteTile: View {
    let title: String
    let systemImage: String
    let tint: Color
    @Binding var isOn: Bool
    var level: Float
    var enabled: Bool

    var body: some View {
        Button {
            isOn.toggle()
        } label: {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Image(systemName: systemImage)
                        .font(.title2)
                        .foregroundStyle(isOn ? tint : .white.opacity(0.7))
                    Spacer()
                    Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(isOn ? tint : .white.opacity(0.35))
                }
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.white)
                LevelMeter(level: isOn ? level : 0, tint: tint)
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(.rect(cornerRadius: 24))
        }
        .buttonStyle(.plain)
        .glassEffect(isOn ? .regular.tint(tint.opacity(0.25)).interactive()
                          : .regular.interactive(),
                     in: .rect(cornerRadius: 24))
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.5)
    }
}

/// The central animated orb reacting to the combined audio level.
struct ConnectionOrb: View {
    var connected: Bool
    var level: Float
    var latencyMs: Int
    var peerName: String

    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                ForEach(0 ..< 3, id: \.self) { ring in
                    Circle()
                        .strokeBorder(.white.opacity(0.18), lineWidth: 1)
                        .scaleEffect(1 + CGFloat(ring) * 0.14 + CGFloat(level) * 0.10)
                        .opacity(connected ? 1 : 0.4)
                        .animation(.easeOut(duration: 0.15), value: level)
                }
                Circle()
                    .fill(.white.opacity(0.08))
                    .overlay(
                        Image(systemName: connected ? "iphone.gen3" : "iphone.slash")
                            .font(.system(size: 44, weight: .light))
                            .foregroundStyle(.white)
                    )
                    .frame(width: 132, height: 132)
                    .glassEffect(.regular.interactive(), in: .circle)
            }
            .frame(width: 196, height: 196)

            Text(connected ? (peerName.isEmpty ? "Conectado" : peerName) : "Sin conexión")
                .font(.footnote.weight(.medium))
                .foregroundStyle(.white)
            Text(connected ? "\(latencyMs) ms" : "—")
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.white.opacity(0.7))
        }
    }
}
