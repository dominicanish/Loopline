using System.Buffers.Binary;
using System.Net.Sockets;

namespace Loopline.Server.Usbmux;

public sealed record UsbDevice(int DeviceId, string Serial, string ConnectionType);

/// <summary>
/// Minimal usbmux client for Apple's Mobile Device Service on Windows
/// (TCP 127.0.0.1:27015). Lets us list connected iPhones and open a raw tunnel
/// to a TCP port the Loopline app is listening on — all over USB.
/// </summary>
public sealed class UsbmuxClient
{
    private const string Host = "127.0.0.1";
    private const int Port = 27015;
    private const uint PlistMessage = 8;
    private const uint Version = 1;
    private int _tag = 1;

    /// <summary>Lists currently attached devices.</summary>
    public List<UsbDevice> ListDevices()
    {
        using var client = Connect();
        var stream = client.GetStream();
        var req = new Dictionary<string, object>
        {
            ["MessageType"] = "ListDevices",
            ["ClientVersionString"] = "Loopline",
            ["ProgName"] = "Loopline",
            ["kLibUSBMuxVersion"] = 3,
        };
        SendPlist(stream, req);
        var reply = ReadPlist(stream);

        var result = new List<UsbDevice>();
        if (reply is Dictionary<string, object> dict &&
            dict.TryGetValue("DeviceList", out var listObj) &&
            listObj is List<object> list)
        {
            foreach (var item in list)
            {
                if (item is not Dictionary<string, object> dev) continue;
                int id = dev.TryGetValue("DeviceID", out var idv) ? (int)(long)idv : 0;
                string serial = "";
                string conn = "";
                if (dev.TryGetValue("Properties", out var p) && p is Dictionary<string, object> props)
                {
                    serial = props.TryGetValue("SerialNumber", out var s) ? s?.ToString() : "";
                    conn = props.TryGetValue("ConnectionType", out var c) ? c?.ToString() : "";
                }
                result.Add(new UsbDevice(id, serial, conn));
            }
        }
        return result;
    }

    /// <summary>
    /// Opens a raw byte tunnel to <paramref name="devicePort"/> on the device.
    /// On success the returned <see cref="NetworkStream"/> carries app data
    /// directly; the caller owns the socket via <paramref name="ownedClient"/>.
    /// Returns null if the device port is not listening (app not running).
    /// </summary>
    public NetworkStream Connect(int deviceId, int devicePort, out TcpClient ownedClient)
    {
        var client = Connect();
        var stream = client.GetStream();
        // PortNumber is expected in network byte order.
        int netPort = ((devicePort & 0xFF) << 8) | ((devicePort >> 8) & 0xFF);
        var req = new Dictionary<string, object>
        {
            ["MessageType"] = "Connect",
            ["DeviceID"] = deviceId,
            ["PortNumber"] = netPort,
            ["ClientVersionString"] = "Loopline",
            ["ProgName"] = "Loopline",
        };
        SendPlist(stream, req);
        var reply = ReadPlist(stream);

        long number = -1;
        if (reply is Dictionary<string, object> dict && dict.TryGetValue("Number", out var nv))
            number = (long)nv;

        if (number != 0)
        {
            client.Dispose();
            ownedClient = null;
            return null;
        }
        ownedClient = client;
        return stream; // now a raw tunnel
    }

    // --- low level ---

    private static TcpClient Connect()
    {
        var client = new TcpClient { NoDelay = true };
        client.Connect(Host, Port);
        return client;
    }

    private void SendPlist(NetworkStream stream, Dictionary<string, object> dict)
    {
        byte[] payload = PlistLite.Build(dict);
        Span<byte> header = stackalloc byte[16];
        BinaryPrimitives.WriteUInt32LittleEndian(header.Slice(0, 4), (uint)(16 + payload.Length));
        BinaryPrimitives.WriteUInt32LittleEndian(header.Slice(4, 4), Version);
        BinaryPrimitives.WriteUInt32LittleEndian(header.Slice(8, 4), PlistMessage);
        BinaryPrimitives.WriteUInt32LittleEndian(header.Slice(12, 4), (uint)System.Threading.Interlocked.Increment(ref _tag));
        stream.Write(header);
        stream.Write(payload);
        stream.Flush();
    }

    private static object ReadPlist(NetworkStream stream)
    {
        var header = ReadExactly(stream, 16);
        uint length = BinaryPrimitives.ReadUInt32LittleEndian(header.AsSpan(0, 4));
        int payloadLen = (int)length - 16;
        if (payloadLen <= 0) return null;
        var payload = ReadExactly(stream, payloadLen);
        return PlistLite.Parse(payload);
    }

    private static byte[] ReadExactly(NetworkStream stream, int count)
    {
        var buf = new byte[count];
        int read = 0;
        while (read < count)
        {
            int n = stream.Read(buf, read, count - read);
            if (n <= 0) throw new IOException("usbmux connection closed");
            read += n;
        }
        return buf;
    }
}
