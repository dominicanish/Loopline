using System.Buffers.Binary;
using System.Net.Sockets;
using Loopline.Server.Protocol;

namespace Loopline.Server;

/// <summary>Owns the raw USB tunnel to the phone and pumps framed messages.</summary>
public sealed class PhoneSession : IDisposable
{
    private readonly NetworkStream _stream;
    private readonly object _writeLock = new();
    private readonly FrameParser _parser = new();

    public Action<byte[]> OnMic;
    public Action<string> OnPeerName;
    public Action OnBye;
    public string PeerName { get; private set; } = "";
    public volatile int LatencyMs;

    public PhoneSession(NetworkStream stream) => _stream = stream;

    public void SendHello(string name) => Send(WireType.Hello, Wire.Hello(name));
    public void SendSpeaker(byte[] pcm) => Send(WireType.SpkPcm, pcm);

    public void Send(WireType type, ReadOnlySpan<byte> payload)
    {
        var frame = Wire.Encode(type, payload);
        lock (_writeLock)
        {
            try { _stream.Write(frame, 0, frame.Length); }
            catch { /* peer gone; Run() will exit */ }
        }
    }

    public void SendPing()
    {
        Span<byte> b = stackalloc byte[8];
        BinaryPrimitives.WriteInt64LittleEndian(b, DateTimeOffset.UtcNow.ToUnixTimeMilliseconds());
        Send(WireType.Ping, b);
    }

    public void Run(CancellationToken ct)
    {
        var buf = new byte[65536];
        while (!ct.IsCancellationRequested)
        {
            int n;
            try { n = _stream.Read(buf, 0, buf.Length); }
            catch { break; }
            if (n <= 0) break;
            _parser.Feed(buf.AsSpan(0, n), HandleMessage);
        }
    }

    private void HandleMessage(WireType type, byte[] payload)
    {
        switch (type)
        {
            case WireType.MicPcm:
                OnMic?.Invoke(payload);
                break;
            case WireType.Hello:
                var h = HelloMsg.Decode(payload);
                if (h != null) { PeerName = h.name ?? ""; OnPeerName?.Invoke(PeerName); }
                break;
            case WireType.Ping:
                Send(WireType.Pong, payload);
                break;
            case WireType.Pong:
                if (payload.Length == 8)
                {
                    long sent = BinaryPrimitives.ReadInt64LittleEndian(payload);
                    long now = DateTimeOffset.UtcNow.ToUnixTimeMilliseconds();
                    LatencyMs = (int)Math.Max(0, now - sent);
                }
                break;
            case WireType.Bye:
                OnBye?.Invoke();
                break;
        }
    }

    public void Dispose() => _stream?.Dispose();
}
