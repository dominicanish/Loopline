import Foundation
import SwiftUI
import UIKit
import AVFAudio

/// Orchestrates the audio engine and the USB link and exposes observable state
/// for the SwiftUI views.
@MainActor
final class AppModel: ObservableObject {
    enum Status: Equatable { case waiting, connected }

    @Published var status: Status = .waiting
    @Published var peerName: String = ""
    @Published var micEnabled: Bool = false { didSet { audio.micEnabled = micEnabled } }
    @Published var speakerEnabled: Bool = true { didSet { audio.speakerEnabled = speakerEnabled } }
    @Published var micLevel: Float = 0
    @Published var speakerLevel: Float = 0
    @Published var latencyMs: Int = 0
    @Published var running: Bool = false

    private let audio = AudioEngine()
    private let link = USBLink()
    private var meterTimer: Timer?
    private var pingTimer: Timer?

    init() {
        audio.onMicData = { [weak self] data in
            self?.link.send(.micPCM, data)
        }
        link.onState = { [weak self] state in
            Task { @MainActor in self?.handleLinkState(state) }
        }
        link.onMessage = { [weak self] type, payload in
            self?.handleMessage(type, payload)
        }
    }

    // MARK: - Control

    func start() {
        guard !running else { return }
        AVAudioApplication.requestRecordPermission { _ in }
        audio.micEnabled = micEnabled
        audio.speakerEnabled = speakerEnabled
        do {
            try audio.start()
        } catch {
            NSLog("Loopline: audio start failed \(error)")
        }
        link.start()
        running = true
        UIApplication.shared.isIdleTimerDisabled = true
        startMeters()
    }

    func stop() {
        guard running else { return }
        link.send(.bye, Data())
        link.stop()
        audio.stop()
        running = false
        status = .waiting
        peerName = ""
        UIApplication.shared.isIdleTimerDisabled = false
        meterTimer?.invalidate(); meterTimer = nil
        pingTimer?.invalidate(); pingTimer = nil
        micLevel = 0; speakerLevel = 0
    }

    // MARK: - Link

    private func handleLinkState(_ state: USBLink.State) {
        switch state {
        case .connected:
            status = .connected
            let name = Hello.phone(name: UIDevice.current.name)
            link.send(.hello, name.data)
            startPing()
        case .listening, .idle:
            status = .waiting
            peerName = ""
            pingTimer?.invalidate(); pingTimer = nil
        }
    }

    private nonisolated func handleMessage(_ type: WireType, _ payload: Data) {
        switch type {
        case .spkPCM:
            audio.enqueueSpeaker(payload)
        case .hello:
            if let hello = Hello.decode(payload) {
                Task { @MainActor in self.peerName = hello.name }
            }
        case .ping:
            link.send(.pong, payload)
        case .pong:
            let now = UInt64(Date().timeIntervalSince1970 * 1000)
            if payload.count == 8 {
                let sent = payload.withUnsafeBytes { $0.load(as: UInt64.self) }
                let rtt = Int(now &- UInt64(littleEndian: sent))
                Task { @MainActor in self.latencyMs = max(0, rtt) }
            }
        case .bye:
            Task { @MainActor in self.status = .waiting }
        default:
            break
        }
    }

    // MARK: - Timers

    private func startMeters() {
        meterTimer?.invalidate()
        meterTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.micLevel = self.audio.micLevel
                self.speakerLevel = self.audio.speakerLevel
            }
        }
    }

    private func startPing() {
        pingTimer?.invalidate()
        pingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            var ts = UInt64(Date().timeIntervalSince1970 * 1000).littleEndian
            let data = withUnsafeBytes(of: &ts) { Data($0) }
            self.link.send(.ping, data)
        }
    }
}
