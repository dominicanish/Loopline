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
    @Published var micEnabled: Bool = false { didSet { applyMic() } }
    @Published var speakerEnabled: Bool = true { didSet { audio.speakerEnabled = speakerEnabled } }
    @Published var micLevel: Float = 0
    @Published var speakerLevel: Float = 0
    @Published var latencyMs: Int = 0
    @Published var running: Bool = false
    @Published var speakerVolume: Double = 1.0 { didSet { audio.setOutputVolume(Float(speakerVolume)) } }
    @Published var echoCancellation: Bool = true { didSet { audio.echoCancellation = echoCancellation } }

    @Published var connectedSince: Date?

    let sampleRate = Int(AudioFormatSpec.sampleRate)
    let bitDepth = 16

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
        // Mark running immediately so the UI reflects the tap, but only touch the
        // audio HW after the mic permission prompt resolves — starting a
        // playAndRecord engine with an undetermined permission crashes CoreAudio.
        running = true
        UIApplication.shared.isIdleTimerDisabled = true

        let begin: (Bool) -> Void = { [weak self] granted in
            Task { @MainActor in self?.beginSession(micGranted: granted) }
        }

        switch AVAudioApplication.shared.recordPermission {
        case .granted:
            begin(true)
        case .denied:
            begin(false)
        default:
            AVAudioApplication.requestRecordPermission(completionHandler: begin)
        }
    }

    private func beginSession(micGranted: Bool) {
        guard running else { return }  // stopped while the prompt was up
        audio.speakerEnabled = speakerEnabled
        audio.echoCancellation = echoCancellation
        do {
            try audio.start(micCapable: micGranted)
            audio.setOutputVolume(Float(speakerVolume))
        } catch {
            NSLog("Loopline: audio start failed \(error)")
        }
        if micGranted {
            if micEnabled { audio.setMicSending(true) }
        } else {
            micEnabled = false
        }
        link.start()
        startMeters()
    }

    /// Apply the mic toggle at runtime (idempotent), requesting permission if needed.
    private func applyMic() {
        guard running else { return }
        guard micEnabled else { audio.setMicSending(false); return }
        switch AVAudioApplication.shared.recordPermission {
        case .granted:
            enableMicSending()
        case .denied:
            micEnabled = false
        default:
            AVAudioApplication.requestRecordPermission { [weak self] granted in
                Task { @MainActor in
                    guard let self else { return }
                    if granted { self.enableMicSending() } else { self.micEnabled = false }
                }
            }
        }
    }

    private func enableMicSending() {
        // If the session was started playback-only (permission granted after
        // Start), reconfigure it once into a mic-capable session, then tap.
        if !audio.micCapable {
            do {
                try audio.start(micCapable: true)
                audio.setOutputVolume(Float(speakerVolume))
            } catch {
                NSLog("Loopline: mic reconfigure failed \(error)")
            }
        }
        audio.setMicSending(true)
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
            connectedSince = Date()
            let name = Hello.phone(name: UIDevice.current.name)
            link.send(.hello, name.data)
            startPing()
        case .listening, .idle:
            status = .waiting
            peerName = ""
            connectedSince = nil
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
                self.speakerLevel = self.audio.spkLevel
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
