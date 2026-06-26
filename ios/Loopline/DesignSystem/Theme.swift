import SwiftUI

/// Brand palette and shared surfaces for Loopline.
enum Brand {
    static let blue   = Color(red: 0x54/255, green: 0x68/255, blue: 0xFF/255)
    static let indigo = Color(red: 0x5B/255, green: 0x8D/255, blue: 0xEF/255)
    static let purple = Color(red: 0x7A/255, green: 0x3F/255, blue: 0xF2/255)
    static let mic    = Color(red: 0x32/255, green: 0xD7/255, blue: 0x4D/255)   // green
    static let speaker = Color(red: 0x0A/255, green: 0xBF/255, blue: 0xE6/255)  // cyan
}

/// The full-screen backdrop that the Liquid Glass surfaces refract.
struct BackdropView: View {
    @State private var animate = false

    var body: some View {
        ZStack {
            LinearGradient(colors: [Brand.indigo, Brand.blue, Brand.purple],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            // Soft moving blobs for depth behind the glass.
            Circle()
                .fill(Brand.speaker.opacity(0.45))
                .frame(width: 360, height: 360)
                .blur(radius: 90)
                .offset(x: animate ? -120 : 120, y: animate ? -220 : -160)
            Circle()
                .fill(Brand.purple.opacity(0.55))
                .frame(width: 420, height: 420)
                .blur(radius: 110)
                .offset(x: animate ? 140 : -100, y: animate ? 280 : 220)
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.easeInOut(duration: 9).repeatForever(autoreverses: true)) {
                animate = true
            }
        }
    }
}
