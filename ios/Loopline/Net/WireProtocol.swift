import Foundation

/// Message types on the Loopline wire (see docs/protocol.md).
enum WireType: UInt8 {
    case hello   = 0x01
    case micPCM  = 0x10
    case spkPCM  = 0x11
    case ping    = 0x20
    case pong    = 0x21
    case bye     = 0x30
}

/// Fixed audio format shared by both ends. No negotiation.
enum AudioFormatSpec {
    static let sampleRate: Double = 48_000
    static let channels: UInt32 = 1
    /// 10 ms packet at 48 kHz mono int16 = 480 samples = 960 bytes.
    static let frameSamples = 480
}

/// Encodes a single framed message: [type:1][length:uint32 LE][payload].
enum WireCodec {
    static func encode(_ type: WireType, _ payload: Data) -> Data {
        var out = Data(capacity: 5 + payload.count)
        out.append(type.rawValue)
        var len = UInt32(payload.count).littleEndian
        withUnsafeBytes(of: &len) { out.append(contentsOf: $0) }
        out.append(payload)
        return out
    }

    /// Streaming parser. Feed bytes; emits complete messages via `onMessage`.
    final class Parser {
        private var buffer = Data()
        var onMessage: ((WireType, Data) -> Void)?

        func feed(_ data: Data) {
            buffer.append(data)
            while true {
                guard buffer.count >= 5 else { return }
                let type = buffer[buffer.startIndex]
                let length = buffer.withUnsafeBytes { raw -> UInt32 in
                    var v: UInt32 = 0
                    withUnsafeMutableBytes(of: &v) { dst in
                        dst.copyBytes(from: UnsafeRawBufferPointer(start: raw.baseAddress!.advanced(by: 1), count: 4))
                    }
                    return UInt32(littleEndian: v)
                }
                let total = 5 + Int(length)
                guard buffer.count >= total else { return }
                let payloadStart = buffer.startIndex + 5
                let payload = buffer.subdata(in: payloadStart ..< buffer.startIndex + total)
                buffer.removeSubrange(buffer.startIndex ..< buffer.startIndex + total)
                if let t = WireType(rawValue: type) {
                    onMessage?(t, payload)
                }
            }
        }
    }
}

/// HELLO handshake payload (JSON).
struct Hello: Codable {
    var role: String
    var name: String
    var version: Int
    var sampleRate: Int
    var channels: Int

    static func phone(name: String) -> Hello {
        Hello(role: "phone", name: name, version: 1,
              sampleRate: Int(AudioFormatSpec.sampleRate), channels: Int(AudioFormatSpec.channels))
    }

    var data: Data { (try? JSONEncoder().encode(self)) ?? Data() }
    static func decode(_ data: Data) -> Hello? { try? JSONDecoder().decode(Hello.self, from: data) }
}
