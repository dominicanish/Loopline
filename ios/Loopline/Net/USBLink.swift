import Foundation
import Network

/// A TCP listener the iPhone exposes on a fixed port. The PC reaches it over
/// USB through Apple's usbmux tunnel, so this never touches Wi-Fi. We accept a
/// single active connection at a time (the most recent wins).
final class USBLink {
    enum State: Equatable { case idle, listening, connected }

    static let port: NWEndpoint.Port = 7001

    private let queue = DispatchQueue(label: "black.dominican.loopline.usblink")
    private var listener: NWListener?
    private var connection: NWConnection?
    private let parser = WireCodec.Parser()

    /// Callbacks are delivered on the link's internal queue.
    var onState: ((State) -> Void)?
    var onMessage: ((WireType, Data) -> Void)?

    private(set) var state: State = .idle {
        didSet { if oldValue != state { onState?(state) } }
    }

    init() {
        parser.onMessage = { [weak self] type, payload in
            self?.onMessage?(type, payload)
        }
    }

    func start() {
        queue.async { self.startLocked() }
    }

    private func startLocked() {
        guard listener == nil else { return }
        do {
            let params = NWParameters.tcp
            params.allowLocalEndpointReuse = true
            if let tcp = params.defaultProtocolStack.internetProtocol as? NWProtocolIP.Options {
                tcp.version = .any
            }
            let listener = try NWListener(using: params, on: USBLink.port)
            self.listener = listener
            listener.newConnectionHandler = { [weak self] conn in
                self?.adopt(conn)
            }
            listener.stateUpdateHandler = { [weak self] st in
                switch st {
                case .ready: self?.state = .listening
                case .failed, .cancelled: self?.state = .idle
                default: break
                }
            }
            listener.start(queue: queue)
        } catch {
            NSLog("Loopline: listener failed: \(error)")
        }
    }

    private func adopt(_ conn: NWConnection) {
        // Replace any existing connection with the newest one.
        connection?.cancel()
        connection = conn
        conn.stateUpdateHandler = { [weak self] st in
            guard let self else { return }
            switch st {
            case .ready:
                self.state = .connected
                self.receiveLoop(conn)
            case .failed, .cancelled:
                if self.connection === conn {
                    self.connection = nil
                    self.state = self.listener != nil ? .listening : .idle
                }
            default: break
            }
        }
        conn.start(queue: queue)
    }

    private func receiveLoop(_ conn: NWConnection) {
        conn.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            guard let self else { return }
            if let data, !data.isEmpty { self.parser.feed(data) }
            if let error {
                NSLog("Loopline: receive error \(error)")
                conn.cancel(); return
            }
            if isComplete { conn.cancel(); return }
            self.receiveLoop(conn)
        }
    }

    /// Sends a framed message. Audio is sent fire-and-forget for low latency.
    func send(_ type: WireType, _ payload: Data) {
        guard let conn = connection, state == .connected else { return }
        let frame = WireCodec.encode(type, payload)
        conn.send(content: frame, completion: .contentProcessed { _ in })
    }

    func stop() {
        queue.async {
            self.connection?.cancel(); self.connection = nil
            self.listener?.cancel(); self.listener = nil
            self.state = .idle
        }
    }
}
