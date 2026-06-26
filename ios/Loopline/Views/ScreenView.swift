import SwiftUI

/// The Screen tab: the live PC screen filling the display, with a remote
/// trackpad + keyboard on top (landscape, presented full-screen).
struct ScreenView: View {
    @EnvironmentObject private var model: AppModel
    var exit: () -> Void

    @State private var keyboardActive = false
    @State private var paletteOffset = CGSize(width: -300, height: -150)
    @GestureState private var paletteDrag = CGSize.zero

    private let moveScale: CGFloat = 1.7
    private let scrollScale: CGFloat = 0.35

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let img = model.screenImage {
                GeometryReader { geo in
                    Image(uiImage: img)
                        .resizable()
                        .interpolation(.medium)
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                }
                .ignoresSafeArea()
            } else {
                hint
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

            controls
                .offset(x: paletteOffset.width + paletteDrag.width,
                        y: paletteOffset.height + paletteDrag.height)
                .gesture(
                    DragGesture(minimumDistance: 12)
                        .updating($paletteDrag) { v, s, _ in s = v.translation }
                        .onEnded { v in
                            paletteOffset.width += v.translation.width
                            paletteOffset.height += v.translation.height
                        }
                )

            KeyboardCatcher(active: $keyboardActive,
                            onText: { t in t == "\n" ? model.sendKeyCode(2) : model.sendKeyText(t) },
                            onBackspace: { model.sendKeyCode(1) })
                .frame(width: 0, height: 0)
        }
        .statusBarHidden(true)
        .ignoresSafeArea(.keyboard, edges: .all)   // the keyboard never shifts the layout
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
        .allowsHitTesting(false)
    }

    private var controls: some View {
        HStack(spacing: 12) {
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white.opacity(0.5))
            cbutton("keyboard", active: keyboardActive) { keyboardActive.toggle() }
            cbutton("xmark", active: false) { keyboardActive = false; exit() }
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(.white.opacity(0.15)))
    }

    private func cbutton(_ icon: String, active: Bool, _ action: @escaping () -> Void) -> some View {
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
