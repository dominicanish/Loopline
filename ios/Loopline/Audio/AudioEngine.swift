import Foundation
import AVFoundation
import os

/// Plays the PC audio stream and (optionally) captures the mic to send back.
///
/// Playback uses a jitter buffer (ported from the proven DeskLink receiver):
/// incoming int16 frames are converted to float and written into a ring buffer;
/// an `AVAudioSourceNode` *pulls* from it on the audio thread. We pre-roll until
/// ~100 ms has buffered, then play continuously; if we drift too far ahead we
/// drop the oldest audio, and on underrun we output silence (never garbage).
/// This is what keeps playback clean — a ring with no pre-roll under-runs
/// constantly and sounds choppy.
final class AudioEngine {
    /// Called on the audio thread with a 48 kHz mono int16 packet from the mic.
    var onMicData: ((Data) -> Void)?
    private(set) var micLevel: Float = 0
    private(set) var spkLevel: Float = 0

    /// When false, incoming audio is dropped (listening paused).
    var speakerEnabled = true
    /// When true the mic session uses `.voiceChat` (echo cancellation); else `.default`.
    var echoCancellation = true

    private let engine = AVAudioEngine()
    private let sampleRate: Double = 48_000

    // SPSC ring buffer of mono float frames.
    private let capFrames = 48_000 * 4            // 4 s headroom
    private var ring: [Float]
    private var writeIdx = 0
    private var readIdx = 0
    private var lock = os_unfair_lock()
    private var playing = false                   // false until the jitter buffer fills
    private let targetFrames = Int(48_000 * 0.1)  // ~100 ms pre-roll

    private var sourceNode: AVAudioSourceNode?
    private lazy var playFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: sampleRate,
                                                channels: 1, interleaved: false)!
    private var outputVolume: Float = 1

    private var micActive = false
    private var recordSessionActive = false
    private lazy var micWireFormat = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: 48_000,
                                                   channels: 1, interleaved: true)!
    private var micConverter: AVAudioConverter?

    init() { ring = [Float](repeating: 0, count: capFrames) }

    // MARK: Lifecycle

    /// Start in playback-only (`.playback`) mode — high quality and it never
    /// touches the mic input node (which would crash without permission). We
    /// upgrade to `.playAndRecord` lazily in `startMic()`.
    func start() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .default, options: [])
        try session.setPreferredSampleRate(sampleRate)
        try session.setPreferredIOBufferDuration(0.01)
        try session.setActive(true)
        try startPlaybackGraph()
    }

    func stop() {
        stopMic()
        recordSessionActive = false
        if engine.isRunning { engine.stop() }
        if let n = sourceNode { engine.detach(n); sourceNode = nil }
        resetJitter()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    func setOutputVolume(_ v: Float) {
        outputVolume = max(0, min(1, v))
        engine.mainMixerNode.outputVolume = outputVolume
    }

    private func startPlaybackGraph() throws {
        if engine.isRunning { engine.stop() }
        if sourceNode == nil {
            let node = AVAudioSourceNode(format: playFormat) { [weak self] _, _, frameCount, abl -> OSStatus in
                self?.render(frameCount: Int(frameCount), abl: abl) ?? noErr
            }
            engine.attach(node)
            sourceNode = node
        }
        engine.connect(sourceNode!, to: engine.mainMixerNode, format: playFormat)
        engine.mainMixerNode.outputVolume = outputVolume
        resetJitter()
        engine.prepare()
        try engine.start()
    }

    private func resetJitter() {
        os_unfair_lock_lock(&lock); writeIdx = 0; readIdx = 0; playing = false; os_unfair_lock_unlock(&lock)
    }

    // MARK: Playback (PC -> phone)

    /// Feed one 48 kHz mono int16 packet into the ring. Called off the audio thread.
    func enqueueSpeaker(_ data: Data) {
        guard speakerEnabled else { return }
        let count = data.count / 2
        guard count > 0 else { return }
        var sum: Float = 0
        data.withUnsafeBytes { (raw: UnsafeRawBufferPointer) in
            let i16 = raw.bindMemory(to: Int16.self)
            os_unfair_lock_lock(&lock)
            var w = writeIdx
            for f in 0..<count {
                let s = Float(Int16(littleEndian: i16[f])) / 32768.0
                ring[w % capFrames] = s
                sum += s * s
                w += 1
            }
            writeIdx = w
            if writeIdx - readIdx > capFrames { readIdx = writeIdx - targetFrames }
            os_unfair_lock_unlock(&lock)
        }
        spkLevel = min(1, (sum / Float(count)).squareRoot() * 4)
    }

    private func render(frameCount n: Int, abl audioBufferList: UnsafeMutablePointer<AudioBufferList>) -> OSStatus {
        let abl = UnsafeMutableAudioBufferListPointer(audioBufferList)
        let out = abl[0].mData!.assumingMemoryBound(to: Float.self)

        os_unfair_lock_lock(&lock)
        let available = writeIdx - readIdx
        if !playing {
            if available >= targetFrames {
                playing = true
            } else {
                for i in 0..<n { out[i] = 0 }
                os_unfair_lock_unlock(&lock)
                return noErr
            }
        }
        // Drop-oldest if we drifted too far ahead (bounds latency).
        let maxBuf = targetFrames * 2 + Int(sampleRate * 0.1)
        if available > maxBuf { readIdx = writeIdx - targetFrames }

        var produced = 0
        while produced < n {
            if readIdx >= writeIdx {              // underrun → silence, re-arm pre-roll
                for i in produced..<n { out[i] = 0 }
                playing = false
                break
            }
            out[produced] = ring[readIdx % capFrames]
            readIdx += 1; produced += 1
        }
        os_unfair_lock_unlock(&lock)
        return noErr
    }

    // MARK: Mic (phone -> PC)

    /// Enable mic capture. Caller guarantees record permission is granted.
    @discardableResult
    func startMic() -> Bool {
        guard !micActive else { return true }
        if !recordSessionActive {
            do {
                let session = AVAudioSession.sharedInstance()
                let mode: AVAudioSession.Mode = echoCancellation ? .voiceChat : .default
                try session.setCategory(.playAndRecord, mode: mode, options: [.defaultToSpeaker])
                try session.setPreferredSampleRate(sampleRate)
                try session.setPreferredIOBufferDuration(0.01)
                try session.setActive(true)
                try? session.overrideOutputAudioPort(.speaker)
                try startPlaybackGraph()
                recordSessionActive = true
            } catch {
                recordSessionActive = false
                try? start()    // roll back to playback-only
                return false
            }
        }
        micConverter = nil
        engine.inputNode.installTap(onBus: 0, bufferSize: 1024, format: nil) { [weak self] buffer, _ in
            self?.handleMicBuffer(buffer)
        }
        micActive = true
        return true
    }

    func stopMic() {
        guard micActive else { return }
        engine.inputNode.removeTap(onBus: 0)
        micActive = false
    }

    private func handleMicBuffer(_ buffer: AVAudioPCMBuffer) {
        let inFormat = buffer.format
        if micConverter == nil
            || micConverter!.inputFormat.sampleRate != inFormat.sampleRate
            || micConverter!.inputFormat.channelCount != inFormat.channelCount {
            micConverter = AVAudioConverter(from: inFormat, to: micWireFormat)
        }
        guard let conv = micConverter, buffer.frameLength > 0 else { return }
        let ratio = micWireFormat.sampleRate / inFormat.sampleRate
        let cap = AVAudioFrameCount(Double(buffer.frameLength) * ratio + 16)
        guard cap > 0, let out = AVAudioPCMBuffer(pcmFormat: micWireFormat, frameCapacity: cap) else { return }
        var fed = false
        var err: NSError?
        conv.convert(to: out, error: &err) { _, status in
            if fed { status.pointee = .noDataNow; return nil }
            fed = true; status.pointee = .haveData; return buffer
        }
        guard err == nil, out.frameLength > 0, let ch = out.int16ChannelData else { return }
        let count = Int(out.frameLength)
        let samples = UnsafeBufferPointer(start: ch[0], count: count)
        var sum: Float = 0
        for v in samples { let f = Float(v) / 32768.0; sum += f * f }
        micLevel = min(1, (sum / Float(count)).squareRoot() * 4)
        onMicData?(Data(bytes: ch[0], count: count * 2))
    }
}
