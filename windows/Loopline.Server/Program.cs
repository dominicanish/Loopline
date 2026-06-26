using Loopline.Server;
using Loopline.Server.Audio;
using Loopline.Server.Protocol;
using NAudio.CoreAudioApi;

Console.OutputEncoding = System.Text.Encoding.UTF8;
try { Console.Title = "Loopline"; } catch { }

// Power-user shortcut kept; everything else is the interactive menu.
if (args.Contains("--list")) { ListAndExit(); return; }

var bridge = new Bridge
{
    MutePc = args.Contains("--mute-pc"),
    SwitchDefaults = !args.Contains("--no-default-switch"),
    Gain = ReadFloatArg(args, "--gain", 1f),
};
bridge.Start();
AppDomain.CurrentDomain.ProcessExit += (_, _) => bridge.Stop();

try { Console.CursorVisible = false; } catch { }
Console.Clear();

bool running = true;
var lastDraw = DateTime.MinValue;
while (running)
{
    if ((DateTime.Now - lastDraw).TotalMilliseconds >= 250) { Draw(bridge); lastDraw = DateTime.Now; }
    if (Console.KeyAvailable)
    {
        HandleKey(Console.ReadKey(true).Key, bridge, ref running);
        lastDraw = DateTime.MinValue;
    }
    else
    {
        Thread.Sleep(40);
    }
}

try { Console.CursorVisible = true; } catch { }
Console.Clear();
bridge.Stop();
Console.WriteLine("Loopline stopped. See you!");
return;

// ---------------- UI ----------------

static void Draw(Bridge b)
{
    var sb = new System.Text.StringBuilder();
    int w = Width();
    void L(string s = "") => sb.Append(s.Length >= w ? s[..(w - 1)] : s.PadRight(w - 1)).Append('\n');

    string title = "  Loopline · iPhone as PC mic & speaker (USB)  ";
    string bar = new string('─', title.Length);
    L("┌" + bar + "┐");
    L("│" + title + "│");
    L("└" + bar + "┘");
    L();

    string dot = b.Connected ? "●" : "○";
    string status = b.Connected
        ? $"Connected to {b.PeerName}   ({AudioSpec.SampleRate / 1000} kHz · {b.LatencyMs} ms)"
        : b.StatusText;
    L($"  Status:   {dot} {status}");
    L($"            mic {Bar(b.MicLevel)}   spk {Bar(b.SpeakerLevel)}");
    L();
    L($"  Routing:  mic   → {Name(b.Devices.MicRender)}");
    L($"            audio ← loopback of {Name(b.Devices.LoopbackRender)}");
    L();
    L("  Options (press a key):");
    L($"    [M]   Mute PC ................. {(b.MutePc ? "ON" : "OFF")}");
    L($"    [+/-] Audio gain ............. x{b.Gain:0.0#}");
    L( "    [D]   Output device (loopback)");
    L($"    [S]   iPhone as default mic ... {(b.SwitchDefaults ? "ON" : "OFF")}");
    L( "    [L]   List all devices");
    L( "    [R]   Restart link");
    L( "    [Q]   Quit");

    try { Console.SetCursorPosition(0, 0); } catch { }
    Console.Write(sb.ToString());
}

static void HandleKey(ConsoleKey key, Bridge b, ref bool running)
{
    switch (key)
    {
        case ConsoleKey.M: b.SetMute(!b.MutePc); break;
        case ConsoleKey.Add: case ConsoleKey.OemPlus: b.SetGain(b.Gain + 0.5f); break;
        case ConsoleKey.Subtract: case ConsoleKey.OemMinus: b.SetGain(b.Gain - 0.5f); break;
        case ConsoleKey.D: DeviceMenu(b); break;
        case ConsoleKey.S: b.SwitchDefaults = !b.SwitchDefaults; b.Restart(); break;
        case ConsoleKey.L: ListMenu(b); break;
        case ConsoleKey.R: b.Restart(); break;
        case ConsoleKey.Q: case ConsoleKey.Escape: running = false; break;
    }
}

static void DeviceMenu(Bridge b)
{
    Console.Clear();
    var devs = b.Picker.RenderDevices();
    Console.WriteLine();
    Console.WriteLine("  Output device to capture (loopback):");
    Console.WriteLine();
    Console.WriteLine("    [0]  System default");
    for (int i = 0; i < devs.Count && i < 9; i++)
        Console.WriteLine($"    [{i + 1}]  {Short(devs[i].FriendlyName)}");
    Console.WriteLine();
    Console.WriteLine("    Press a number (Esc to cancel)…");

    var k = Console.ReadKey(true);
    if (k.Key == ConsoleKey.D0) { b.LoopbackOverrideId = null; b.Restart(); }
    else if (char.IsDigit(k.KeyChar))
    {
        int idx = k.KeyChar - '1';
        if (idx >= 0 && idx < devs.Count) { b.LoopbackOverrideId = devs[idx].ID; b.Restart(); }
    }
    Console.Clear();
}

static void ListMenu(Bridge b)
{
    Console.Clear();
    var (renders, captures) = b.Picker.ListNames();
    Console.WriteLine();
    Console.WriteLine("  Playback (render):");
    foreach (var r in renders) Console.WriteLine("    • " + Short(r));
    Console.WriteLine();
    Console.WriteLine("  Recording (capture):");
    foreach (var c in captures) Console.WriteLine("    • " + Short(c));
    Console.WriteLine();
    Console.WriteLine("  Press any key to go back…");
    Console.ReadKey(true);
    Console.Clear();
}

static void ListAndExit()
{
    var picker = new DevicePicker();
    var (renders, captures) = picker.ListNames();
    Console.WriteLine("Playback (render) devices:");
    foreach (var r in renders) Console.WriteLine("  • " + r);
    Console.WriteLine("\nRecording (capture) devices:");
    foreach (var c in captures) Console.WriteLine("  • " + c);
}

// ---------------- helpers ----------------

static int Width()
{
    try { return Math.Max(48, Console.WindowWidth); } catch { return 60; }
}

static string Bar(float level)
{
    const int width = 12;
    int lit = (int)Math.Round(Math.Clamp(level, 0, 1) * width);
    return "[" + new string('#', lit) + new string('·', width - lit) + "]";
}

static string Name(MMDevice dev) => dev != null ? Short(dev.FriendlyName) : "(no encontrado)";

static string Short(string name) => name.Length > 40 ? name[..40] + "…" : name;

static float ReadFloatArg(string[] args, string name, float fallback)
{
    int i = Array.IndexOf(args, name);
    if (i >= 0 && i + 1 < args.Length &&
        float.TryParse(args[i + 1], System.Globalization.NumberStyles.Float,
                       System.Globalization.CultureInfo.InvariantCulture, out var v))
        return v;
    return fallback;
}
