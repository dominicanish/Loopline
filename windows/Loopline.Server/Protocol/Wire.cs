using System.Buffers.Binary;
using System.Text;
using System.Text.Json;

namespace Loopline.Server.Protocol;

public enum WireType : byte
{
    Hello  = 0x01,
    MicPcm = 0x10,
    SpkPcm = 0x11,
    Ping   = 0x20,
    Pong   = 0x21,
    Bye    = 0x30,
    // Remote-control input (phone -> PC), used by the Screen trackpad.
    MouseMove   = 0x40,   // [int16 dx LE][int16 dy LE] (relative)
    MouseButton = 0x41,   // [u8 button (0=L,1=R,2=M)][u8 down]
    MouseScroll = 0x42,   // [int16 delta LE]
    KeyText     = 0x43,   // UTF-8 text to type
    KeyCode     = 0x44,   // [u8 special code]
    // Screen mirroring
    ScreenFrame   = 0x50, // PC -> iPhone: a JPEG frame
    ScreenControl = 0x51, // iPhone -> PC: [u8 on] start/stop streaming
}

/// <summary>Fixed audio format shared with the iPhone app (see docs/protocol.md).</summary>
public static class AudioSpec
{
    public const int SampleRate = 48_000;
    public const int Channels = 1;
    public const int FrameSamples = 480; // 10 ms
}

public static class Wire
{
    /// <summary>Builds a framed message: [type:1][len:uint32 LE][payload].</summary>
    public static byte[] Encode(WireType type, ReadOnlySpan<byte> payload)
    {
        var frame = new byte[5 + payload.Length];
        frame[0] = (byte)type;
        BinaryPrimitives.WriteUInt32LittleEndian(frame.AsSpan(1, 4), (uint)payload.Length);
        payload.CopyTo(frame.AsSpan(5));
        return frame;
    }

    public static byte[] Hello(string name) =>
        JsonSerializer.SerializeToUtf8Bytes(new HelloMsg
        {
            role = "pc", name = name, version = 1,
            sampleRate = AudioSpec.SampleRate, channels = AudioSpec.Channels
        });
}

public sealed class HelloMsg
{
    public string role { get; set; }
    public string name { get; set; }
    public int version { get; set; }
    public int sampleRate { get; set; }
    public int channels { get; set; }

    public static HelloMsg Decode(ReadOnlySpan<byte> data)
    {
        try { return JsonSerializer.Deserialize<HelloMsg>(data); }
        catch { return null; }
    }
}

/// <summary>Incremental frame parser over a byte stream.</summary>
public sealed class FrameParser
{
    private byte[] _buf = new byte[1 << 16];
    private int _len;

    public void Feed(ReadOnlySpan<byte> data, Action<WireType, byte[]> onMessage)
    {
        EnsureCapacity(_len + data.Length);
        data.CopyTo(_buf.AsSpan(_len));
        _len += data.Length;

        int offset = 0;
        while (_len - offset >= 5)
        {
            var span = _buf.AsSpan(offset);
            uint payloadLen = BinaryPrimitives.ReadUInt32LittleEndian(span.Slice(1, 4));
            int total = 5 + (int)payloadLen;
            if (_len - offset < total) break;

            var type = (WireType)span[0];
            var payload = span.Slice(5, (int)payloadLen).ToArray();
            onMessage(type, payload);
            offset += total;
        }

        if (offset > 0)
        {
            int remaining = _len - offset;
            Array.Copy(_buf, offset, _buf, 0, remaining);
            _len = remaining;
        }
    }

    private void EnsureCapacity(int needed)
    {
        if (needed <= _buf.Length) return;
        int newSize = _buf.Length;
        while (newSize < needed) newSize <<= 1;
        Array.Resize(ref _buf, newSize);
    }
}
