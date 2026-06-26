import SwiftUI
import UIKit

// MARK: - Trackpad

/// A multi-touch surface: one-finger drag moves the PC cursor, one-finger tap is
/// a left click, two-finger tap is a right click, two-finger drag scrolls.
struct TrackpadView: UIViewRepresentable {
    var onMove: (CGFloat, CGFloat) -> Void
    var onLeftClick: () -> Void
    var onRightClick: () -> Void
    var onScroll: (CGFloat) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> UIView {
        let v = UIView()
        v.backgroundColor = .clear
        v.isMultipleTouchEnabled = true
        let c = context.coordinator

        let pan = UIPanGestureRecognizer(target: c, action: #selector(Coordinator.pan(_:)))
        pan.minimumNumberOfTouches = 1
        pan.maximumNumberOfTouches = 2
        let tap = UITapGestureRecognizer(target: c, action: #selector(Coordinator.tap(_:)))
        let twoTap = UITapGestureRecognizer(target: c, action: #selector(Coordinator.twoTap(_:)))
        twoTap.numberOfTouchesRequired = 2
        v.addGestureRecognizer(pan)
        v.addGestureRecognizer(tap)
        v.addGestureRecognizer(twoTap)
        return v
    }

    func updateUIView(_ uiView: UIView, context: Context) { context.coordinator.parent = self }

    final class Coordinator: NSObject {
        var parent: TrackpadView
        private var last = CGPoint.zero
        init(_ p: TrackpadView) { parent = p }

        @objc func pan(_ g: UIPanGestureRecognizer) {
            let t = g.translation(in: g.view)
            if g.state == .began { last = t; return }
            let dx = t.x - last.x, dy = t.y - last.y
            last = t
            if g.numberOfTouches >= 2 { parent.onScroll(dy) }
            else { parent.onMove(dx, dy) }
        }
        @objc func tap(_ g: UITapGestureRecognizer) { parent.onLeftClick() }
        @objc func twoTap(_ g: UITapGestureRecognizer) { parent.onRightClick() }
    }
}

// MARK: - Keyboard catcher

/// A hidden first-responder that surfaces the iOS keyboard and reports each
/// inserted character / backspace so we can forward keystrokes to the PC.
struct KeyboardCatcher: UIViewRepresentable {
    @Binding var active: Bool
    var onText: (String) -> Void
    var onBackspace: () -> Void

    func makeUIView(context: Context) -> KeyCatcherView {
        let v = KeyCatcherView()
        v.onText = onText
        v.onBackspace = onBackspace
        return v
    }

    func updateUIView(_ uiView: KeyCatcherView, context: Context) {
        uiView.onText = onText
        uiView.onBackspace = onBackspace
        if active, !uiView.isFirstResponder { uiView.becomeFirstResponder() }
        else if !active, uiView.isFirstResponder { uiView.resignFirstResponder() }
    }
}

final class KeyCatcherView: UIView, UIKeyInput {
    var onText: ((String) -> Void)?
    var onBackspace: (() -> Void)?
    var autocorrectionType: UITextAutocorrectionType = .no
    var keyboardType: UIKeyboardType = .default

    override var canBecomeFirstResponder: Bool { true }
    var hasText: Bool { true }
    func insertText(_ text: String) { onText?(text) }
    func deleteBackward() { onBackspace?() }
}

// MARK: - Screen decode (latest-frame-wins)

/// Decodes incoming JPEG screen frames on a background queue, always skipping to
/// the most recent frame so a slow decode never builds up latency.
final class ScreenDecoder {
    var onImage: ((UIImage?) -> Void)?   // delivered on the main thread

    private let queue = DispatchQueue(label: "loopline.screen.decode", qos: .userInteractive)
    private let lock = NSLock()
    private var pending: Data?
    private var draining = false

    func submit(_ data: Data) {
        lock.lock()
        pending = data
        if draining { lock.unlock(); return }
        draining = true
        lock.unlock()
        queue.async { [weak self] in self?.drain() }
    }

    private func drain() {
        while true {
            lock.lock()
            guard let data = pending else { draining = false; lock.unlock(); return }
            pending = nil
            lock.unlock()
            let img = UIImage(data: data)
            DispatchQueue.main.async { [weak self] in self?.onImage?(img) }
        }
    }
}

// MARK: - Orientation

/// Locks the app to portrait everywhere except the Screen tab, which requests
/// landscape to give the trackpad the whole display.
final class AppDelegate: NSObject, UIApplicationDelegate {
    static var lock: UIInterfaceOrientationMask = .portrait

    func application(_ application: UIApplication,
                     supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        AppDelegate.lock
    }
}

enum Orientation {
    static func goLandscape() { apply(.landscapeRight, lock: .landscape) }
    static func goPortrait() { apply(.portrait, lock: .portrait) }

    private static func apply(_ mask: UIInterfaceOrientationMask, lock: UIInterfaceOrientationMask) {
        AppDelegate.lock = lock
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene }).first else { return }
        scene.requestGeometryUpdate(.iOS(interfaceOrientations: mask)) { _ in }
        scene.windows.first?.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
    }
}
