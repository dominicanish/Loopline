import Foundation
import AVFoundation

/// Captures the microphone and plays back PCM coming from the PC.
///
/// Uses `.playAndRecord` + `.voiceChat` so iOS applies hardware echo
/// cancellation — essential when the phone is a loudspeaker and a microphone
/// at the same time, otherwise the PC would hear its own output echoed back.
final class AudioEngine {
    /// Called on the audio thread with a 48 kHz mono int16 packet from the mic.
    var onMicData: ((Data) -> Void)?
    /// Latest linear levels (0...1) for the UI meters.
    private(set) var micLevel: Float = 0
    private(set) var spkLevel: Float = 0

    /// Gates: only send mic / only render speaker when enabled.
    var micEnabled = false
    var speakerEnabled = true
    /// Playback jitter-buffer depth in ms (latency mode). Settable live.
    var targetLatencyMs: Double = 80

    private let engine = AVAudioEngine()
    private var sourceNode: AVAudioSourceNode?
    private var playing = false             // false until the jitter buffer pre-rolls
    private var speakerOn = true            // loudspeaker vs earpiece route
    private let playbackBuffer = FloatRingBuffer(capacity: Int(AudioFormatSpec.sampleRate) * 2) // 2 s
    private let wireFormat = AVAudioFormat(commonFormat: .pcmFormatInt16,
                                           sampleRate: AudioFormatSpec.sampleRate,
                                           channels: AudioFormatSpec.channels,
                                           interleaved: true)!
    private var micConverter: AVAudioConverter?
    private var running = false

    // MARK: - Lifecycle

    func start(captureEnabled: Bool = true) throws {
        guard !running else { return }
        try configureSession()

        let output = engine.outputNode
        let mainMixer = engine.mainMixerNode

        // Playback path: a source node pulls mono float samples from the ring.
        let srcFormat = AVAudioFormat(standardFormatWithSampleRate: AudioFormatSpec.sampleRate, channels: 1)!
        let source = AVAudioSourceNode(format: srcFormat) { [weak self] _, _, frameCount, audioBufferList -> OSStatus in
            let abl = UnsafeMutableAudioBufferListPointer(audioBufferList)
            guard let self else {
                for buffer in abl { memset(buffer.mData, 0, Int(buffer.mDataByteSize)) }
                return noErr
            }
            let n = Int(frameCount)
            let ptr = abl[0].mData!.assumingMemoryBound(to: Float.self)
            let dst = UnsafeMutableBufferPointer(start: ptr, count: n)
            self.renderPlayback(into: dst)
            // Duplicate to any extra channels.
            for ch in 1 ..< abl.count {
                if let m = abl[ch].mData { memcpy(m, ptr, n * MemoryLayout<Float>.size) }
            }
            return noErr
        }
        self.sourceNode = source
        engine.attach(source)
        engine.connect(source, to: mainMixer, format: srcFormat)
        engine.connect(mainMixer, to: output, format: nil)

        // Capture path: tap the input node and convert to the wire format.
        // Only when we actually hold mic permission AND the input format is
        // valid — connecting a 0 Hz / 0-channel input node crashes CoreAudio.
        let input = engine.inputNode
        let inFormat = input.inputFormat(forBus: 0)
        if captureEnabled, inFormat.sampleRate > 0, inFormat.channelCount > 0 {
            micConverter = AVAudioConverter(from: inFormat, to: wireFormat)
            input.installTap(onBus: 0, bufferSize: 1024, format: inFormat) { [weak self] buffer, _ in
                self?.handleMic(buffer)
            }
        } else if captureEnabled {
            NSLog("Loopline: mic input unavailable (format \(inFormat)); running playback-only")
        }

        playing = false           // arm the jitter buffer pre-roll
        engine.prepare()
        try engine.start()
        running = true
    }

    func stop() {
        guard running else { return }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        if let s = sourceNode { engine.detach(s) }
        sourceNode = nil
        playbackBuffer.clear()
        playing = false
        running = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    // MARK: - Incoming speaker PCM (from PC)

    /// Feed a 48 kHz mono int16 packet to the speaker ring buffer.
    func enqueueSpeaker(_ data: Data) {
        guard speakerEnabled else { return }
        data.withUnsafeBytes { raw in
            let i16 = raw.bindMemory(to: Int16.self)
            var floats = [Float](repeating: 0, count: i16.count)
            for i in 0 ..< i16.count { floats[i] = Float(i16[i]) / 32768.0 }
            floats.withUnsafeBufferPointer { playbackBuffer.write($0) }
        }
    }

    // MARK: - Private

    /// Sets the playback volume of the incoming (computer) audio. 0...1.
    func setOutputVolume(_ v: Float) {
        engine.mainMixerNode.outputVolume = max(0, min(1, v))
    }

    /// Live route toggle, exactly like a phone call's speaker button:
    /// on → loudspeaker, off → earpiece. Safe to call during a session.
    func setSpeaker(_ on: Bool) {
        speakerOn = on
        applyRoute()
    }

    private func applyRoute() {
        try? AVAudioSession.sharedInstance().overrideOutputAudioPort(speakerOn ? .speaker : .none)
    }

    /// Audio-thread render: jitter buffer with a live target depth (latency mode).
    /// Pre-rolls until `targetLatencyMs` has buffered, drops the oldest when too
    /// far ahead, and outputs silence on underrun (re-arming the pre-roll).
    private func renderPlayback(into dst: UnsafeMutableBufferPointer<Float>) {
        let n = dst.count
        guard speakerEnabled else {
            for i in 0 ..< n { dst[i] = 0 }
            spkLevel = 0
            return
        }
        let target = max(1, Int(targetLatencyMs / 1000 * AudioFormatSpec.sampleRate))
        let available = playbackBuffer.available
        if !playing {
            if available >= target {
                playing = true
            } else {
                for i in 0 ..< n { dst[i] = 0 }
                return
            }
        }
        let maxBuf = target * 2 + Int(AudioFormatSpec.sampleRate * 0.1)
        if available > maxBuf { playbackBuffer.drop(available - target) }
        let read = playbackBuffer.read(into: dst)   // zero-fills any underrun
        if read < n { playing = false }             // underrun → re-arm pre-roll
        spkLevel = AudioEngine.rms(dst)
    }

    private func configureSession() throws {
        let session = AVAudioSession.sharedInstance()
        // Always the call profile (.voiceChat): hardware echo cancellation so the
        // PC never hears its own audio back through the mic. The loudspeaker vs
        // earpiece route is controlled live via setSpeaker().
        try session.setCategory(.playAndRecord, mode: .voiceChat,
                                options: [.allowBluetoothA2DP, .allowBluetoothHFP])
        try session.setPreferredSampleRate(AudioFormatSpec.sampleRate)
        try session.setPreferredIOBufferDuration(0.01)
        try session.setActive(true, options: [])
        applyRoute()
    }

    private func handleMic(_ buffer: AVAudioPCMBuffer) {
        guard let converter = micConverter else { return }
        let ratio = wireFormat.sampleRate / buffer.format.sampleRate
        let outCapacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio + 64)
        guard let out = AVAudioPCMBuffer(pcmFormat: wireFormat, frameCapacity: outCapacity) else { return }

        var fed = false
        var err: NSError?
        converter.convert(to: out, error: &err) { _, status in
            if fed { status.pointee = .noDataNow; return nil }
            fed = true
            status.pointee = .haveData
            return buffer
        }
        if let err { NSLog("Loopline: mic convert error \(err)"); return }
        guard out.frameLength > 0, let ch = out.int16ChannelData else { return }

        let count = Int(out.frameLength)
        let samples = UnsafeBufferPointer(start: ch[0], count: count)
        micLevel = AudioEngine.rms16(samples)

        if micEnabled {
            let data = Data(bytes: ch[0], count: count * MemoryLayout<Int16>.size)
            onMicData?(data)
        }
    }

    private static func rms(_ s: UnsafeMutableBufferPointer<Float>) -> Float {
        guard s.count > 0 else { return 0 }
        var sum: Float = 0
        for v in s { sum += v * v }
        return min(1, (sum / Float(s.count)).squareRoot() * 4)
    }

    private static func rms16(_ s: UnsafeBufferPointer<Int16>) -> Float {
        guard s.count > 0 else { return 0 }
        var sum: Float = 0
        for v in s { let f = Float(v) / 32768.0; sum += f * f }
        return min(1, (sum / Float(s.count)).squareRoot() * 4)
    }
}
