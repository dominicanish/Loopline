using System.Drawing;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;
using System.Runtime.Versioning;

namespace Loopline.Server;

/// <summary>
/// Captures the primary screen (with the cursor drawn in), scales it down,
/// JPEG-encodes it and hands each frame to <see cref="OnFrame"/>. Runs only
/// while enabled, so it costs nothing when the phone isn't on the Screen tab.
/// </summary>
[SupportedOSPlatform("windows")]
public sealed class ScreenStreamer : IDisposable
{
    public Action<byte[]> OnFrame;

    private Thread _thread;
    private volatile bool _running;
    private volatile bool _enabled;

    private const int MaxWidth = 1280;
    private const int Fps = 60;
    private const long Quality = 45;

    public void SetEnabled(bool on)
    {
        _enabled = on;
        if (on && !_running)
        {
            _running = true;
            _thread = new Thread(Loop) { IsBackground = true, Name = "Loopline-screen" };
            _thread.Start();
        }
    }

    private void Loop()
    {
        var encoder = ImageCodecInfo.GetImageEncoders().First(e => e.FormatID == ImageFormat.Jpeg.Guid);
        var ep = new EncoderParameters(1);
        ep.Param[0] = new EncoderParameter(Encoder.Quality, Quality);
        int frameMs = Math.Max(2, 1000 / Fps);   // ~16ms target; actual fps is bounded by capture cost

        while (_running)
        {
            if (!_enabled) { Thread.Sleep(60); continue; }
            try
            {
                int sw = GetSystemMetrics(0), sh = GetSystemMetrics(1);
                if (sw <= 0 || sh <= 0) { Thread.Sleep(frameMs); continue; }

                using var full = new Bitmap(sw, sh, PixelFormat.Format24bppRgb);
                using (var g = Graphics.FromImage(full))
                {
                    g.CopyFromScreen(0, 0, 0, 0, new Size(sw, sh), CopyPixelOperation.SourceCopy);
                    DrawCursor(g);
                }

                int w = Math.Min(MaxWidth, sw);
                int h = sh * w / sw;
                using var scaled = new Bitmap(w, h, PixelFormat.Format24bppRgb);
                using (var g = Graphics.FromImage(scaled))
                {
                    g.InterpolationMode = System.Drawing.Drawing2D.InterpolationMode.Low;
                    g.DrawImage(full, 0, 0, w, h);
                }

                using var ms = new MemoryStream();
                scaled.Save(ms, encoder, ep);
                OnFrame?.Invoke(ms.ToArray());
            }
            catch { /* keep streaming on transient capture errors */ }

            Thread.Sleep(frameMs);
        }
    }

    private static void DrawCursor(Graphics g)
    {
        var ci = new CURSORINFO { cbSize = Marshal.SizeOf<CURSORINFO>() };
        if (!GetCursorInfo(ref ci) || ci.flags != CURSOR_SHOWING || ci.hCursor == IntPtr.Zero) return;
        IntPtr hdc = g.GetHdc();
        try { DrawIconEx(hdc, ci.ptScreenPos.x, ci.ptScreenPos.y, ci.hCursor, 0, 0, 0, IntPtr.Zero, DI_NORMAL); }
        finally { g.ReleaseHdc(hdc); }
    }

    public void Dispose()
    {
        _running = false;
        _enabled = false;
        try { _thread?.Join(500); } catch { }
    }

    // --- interop ---

    private const int CURSOR_SHOWING = 0x0001;
    private const int DI_NORMAL = 0x0003;

    [StructLayout(LayoutKind.Sequential)]
    private struct POINT { public int x; public int y; }

    [StructLayout(LayoutKind.Sequential)]
    private struct CURSORINFO { public int cbSize; public int flags; public IntPtr hCursor; public POINT ptScreenPos; }

    [DllImport("user32.dll")] private static extern bool GetCursorInfo(ref CURSORINFO pci);
    [DllImport("user32.dll")] private static extern bool DrawIconEx(IntPtr hdc, int x, int y, IntPtr hIcon, int w, int h, int frame, IntPtr brush, int flags);
    [DllImport("user32.dll")] private static extern int GetSystemMetrics(int index);
}
