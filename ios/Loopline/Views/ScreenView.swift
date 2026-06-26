import SwiftUI

/// The Screen tab: a remote trackpad + keyboard for the PC (landscape).
struct ScreenView: View {
    @EnvironmentObject private var model: AppModel
    var exit: () -> Void

    @State private var keyboardActive = false
    @State private var paletteOffset = CGSize(width: -300, height: -120)
    @GestureState private var paletteDrag = CGSize.zero

    private let moveScale: CGFloat = 1.7
    private let scrollScale: CGFloat = 0.35

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let img = model.screenImage {
                Image(uiImage: img)
                    .resizable()
                    .interpolation(.medium)
                    .aspectRatio(contentMode: .fit)
                    .ignoresSafeArea()
            }

            TrackpadView(
                onMove: { dx, dy in
                    model.sendMouseMove(dx: Int((dx * moveScale).rounded()),
                                        dy: Int((dy * moveScale).rounded()))
                },
                onLeftClick: { model.sendClick(0) },
                onRightClick: { model.sendClick(1) },
                onScroll: { dy in model.sendScroll(Int((-dy * scrollScale).rounded())) }
            )
            .ignoresSafeArea()

            if model.screenImage == nil { hint.allowsHitTesting(false) }

            floatingButtons

            KeyboardCatcher(active: $keyboardActive,
                            onText: { t in t == "\n" ? model.sendKeyCode(2) : model.sendKeyText(t) },
                            onBackspace: { model.sendKeyCode(1) })
                .frame(width: 0, height: 0)
        }
        .statusBarHidden(true)
        .onAppear { Orientation.goLandscape(); model.setScreenStreaming(true) }
        .onDisappear { keyboardActive = false; model.setScreenStreaming(false); Orientation.goPortrait() }
    }

    private var hint: some View {
        VStack(spacing: 10) {
            ProgressView().tint(.white)
            Text("Waiting for the PC screen…").font(.headline)
            Text("Drag to move · tap to click · two fingers to scroll / right-click")
                .font(.caption)
        }
        .foregroundStyle(.white.opacity(0.5))
    }

    private var floatingButtons: some View {
        HStack(spacing: 12) {
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white.opacity(0.5))
            fbutton("keyboard", active: keyboardActive) { keyboardActive.toggle() }
            fbutton("xmark", active: false) { keyboardActive = false; exit() }
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(.white.opacity(0.15)))
        .offset(x: paletteOffset.width + paletteDrag.width,
                y: paletteOffset.height + paletteDrag.height)
        .gesture(
            DragGesture(minimumDistance: 10)
                .updating($paletteDrag) { v, s, _ in s = v.translation }
                .onEnded { v in
                    paletteOffset.width += v.translation.width
                    paletteOffset.height += v.translation.height
                }
        )
    }

    private func fbutton(_ icon: String, active: Bool, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 19, weight: .medium))
                .foregroundStyle(active ? Palette.green : .white)
                .frame(width: 46, height: 46)
                .background(.white.opacity(0.12), in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
    }
}
