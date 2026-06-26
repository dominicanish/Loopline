using Loopline.Server;
using Loopline.Server.Audio;
using Loopline.Server.Protocol;
using Loopline.Server.Usbmux;
using NAudio.CoreAudioApi;

const int defaultPort = 7001;

bool listOnly = args.Contains("--list");
bool noSwitch = args.Contains("--no-default-switch");
int port = ReadIntArg(args, "--port", defaultPort);

Banner();

var picker = new DevicePicker();

if (listOnly)
{
    var (renders, captures) = picker.ListNames();
    Console.WriteLine("Playback (render) devices:");
    foreach (var r in renders) Console.WriteLine("  • " + r);
    Console.WriteLine("\nRecording (capture) devices:");
    foreach (var c in captures) Console.WriteLine("  • " + c);
    return;
}

var devices = picker.Resolve();
ReportDevices(devices);

if (!devices.IsComplete)
{
    Warn("No encontré los cables virtuales necesarios. Instala VB-Cable A+B (o VoiceMeeter)\n" +
         "      y vuelve a correr. Usa `Loopline.Server --list` para ver tus dispositivos.");
}
else if (IsSingleCable(devices))
{
    Warn("Detecté UN SOLO cable virtual (sin A/B). El micrófono funciona, pero el\n" +
         "      altavoz comparte el mismo cable, así que el audio de la PC puede no oírse\n" +
         "      o mezclarse con tu micrófono. Para full-duplex instala VB-CABLE A+B\n" +
         "      (gratis) — ver docs/setup-windows.md.");
    Info("Para verificar el altavoz: reproduce algo en la PC y observa el medidor 'spk'\n" +
         "      abajo. Si no se mueve, el audio de la PC no está entrando al cable.");
}

// Switch Windows defaults so every app routes through Loopline, and remember
// the originals so we can restore them on exit.
var switcher = new DefaultDeviceSwitcher();
string prevPlayback = null, prevRecording = null;
bool switched = false;

if (!noSwitch && devices.DefaultPlayback != null && devices.DefaultRecording != null)
{
    prevPlayback = switcher.GetDefault(DataFlow.Render);
    prevRecording = switcher.GetDefault(DataFlow.Capture);
    switcher.SetDefault(devices.DefaultPlayback.ID);
    switcher.SetDefault(devices.DefaultRecording.ID);
    switched = true;
    Ok($"Default de Windows → playback: {Short(devices.DefaultPlayback.FriendlyName)} | " +
       $"recording: {Short(devices.DefaultRecording.FriendlyName)}");
}

var cts = new CancellationTokenSource();
bool restored = false;

void Restore()
{
    if (restored) return;
    restored = true;
    if (switched)
    {
        try { switcher.SetDefault(prevPlayback); } catch { }
        try { switcher.SetDefault(prevRecording); } catch { }
        Console.WriteLine();
        Ok("Dispositivos de audio por defecto restaurados.");
    }
}

AppDomain.CurrentDomain.ProcessExit += (_, _) => Restore();
Console.CancelKeyPress += (_, e) => { e.Cancel = true; cts.Cancel(); };

Console.WriteLine();
Info("Esperando iPhone por USB…  (Ctrl+C para salir)");

var usb = new UsbmuxClient();
string lastStatus = "";

while (!cts.IsCancellationRequested)
{
    try
    {
        var list = SafeListDevices(usb);
        var dev = list.FirstOrDefault(d => d.ConnectionType == "USB") ?? list.FirstOrDefault();
        if (dev == null) { Status(ref lastStatus, "Esperando iPhone por USB…"); Wait(cts, 1000); continue; }

        var stream = usb.Connect(dev.DeviceId, port, out var owned);
        if (stream == null)
        {
            Status(ref lastStatus, "iPhone detectado — abre la app Loopline en el teléfono…");
            Wait(cts, 1000);
            continue;
        }

        using (owned)
        using (var session = new PhoneSession(stream))
        using (var router = new AudioRouter(devices.MicRender, devices.SpeakerCapture))
        {
            session.OnMic = router.EnqueueMic;
            router.OnSpeakerPacket = session.SendSpeaker;
            session.OnPeerName = name =>
            {
                Console.WriteLine();
                Ok($"Conectado a {name}.");
            };
            session.OnBye = () => { };

            router.Start();
            session.SendHello(Environment.MachineName);

            using var ping = new Timer(_ => session.SendPing(), null, 1000, 1000);
            using var meter = new Timer(_ => Meter(session, router), null, 200, 200);

            lastStatus = "";
            session.Run(cts.Token);
        }

        Console.WriteLine();
        Info("iPhone desconectado. Esperando reconexión…");
    }
    catch (Exception ex)
    {
        Status(ref lastStatus, "Reintentando… (" + ex.Message + ")");
        Wait(cts, 1000);
    }
}

Restore();
Console.WriteLine("Loopline detenido. ¡Hasta luego!");
return;

// ---------------- helpers ----------------

static List<UsbDevice> SafeListDevices(UsbmuxClient usb)
{
    try { return usb.ListDevices(); }
    catch { return new List<UsbDevice>(); }
}

static void Meter(PhoneSession session, AudioRouter router)
{
    string mic = Bar(router.MicLevel);
    string spk = Bar(router.SpeakerLevel);
    Console.Write($"\r  mic {mic}  spk {spk}   {session.LatencyMs,3} ms   ");
}

static string Bar(float level)
{
    const int width = 12;
    int lit = (int)Math.Round(Math.Clamp(level, 0, 1) * width);
    return "[" + new string('#', lit) + new string('·', width - lit) + "]";
}

static void Status(ref string last, string s)
{
    if (s == last) return;
    last = s;
    Console.Write("\r" + s.PadRight(64) + "\r" + s);
}

static void Wait(CancellationTokenSource cts, int ms) => cts.Token.WaitHandle.WaitOne(ms);

static int ReadIntArg(string[] args, string name, int fallback)
{
    int i = Array.IndexOf(args, name);
    if (i >= 0 && i + 1 < args.Length && int.TryParse(args[i + 1], out var v)) return v;
    return fallback;
}

static void ReportDevices(RoutedDevices d)
{
    Console.WriteLine("Ruteo de audio:");
    Line("  mic del iPhone  → ", d.MicRender);
    Line("  audio de la PC  ← ", d.SpeakerCapture);
    Console.WriteLine();

    static void Line(string label, MMDevice dev) =>
        Console.WriteLine(label + (dev != null ? Short(dev.FriendlyName) : "(no encontrado)"));
}

static bool IsSingleCable(RoutedDevices d)
{
    if (d.MicRender == null || d.SpeakerCapture == null) return false;
    string[] twoCableHints = { "CABLE-A", "CABLE-B", "VoiceMeeter" };
    bool mic = twoCableHints.Any(h => d.MicRender.FriendlyName.Contains(h, StringComparison.OrdinalIgnoreCase));
    bool spk = twoCableHints.Any(h => d.SpeakerCapture.FriendlyName.Contains(h, StringComparison.OrdinalIgnoreCase));
    return !mic && !spk;
}

static string Short(string name) => name.Length > 42 ? name[..42] + "…" : name;

static void Banner()
{
    Console.WriteLine("┌────────────────────────────────────────────┐");
    Console.WriteLine("│  Loopline · iPhone como mic y altavoz (USB)  │");
    Console.WriteLine("└────────────────────────────────────────────┘");
}

static void Ok(string s)   => WriteTag("[ok] ", ConsoleColor.Green, s);
static void Info(string s) => WriteTag("[··] ", ConsoleColor.Cyan, s);
static void Warn(string s)  => WriteTag("[!!] ", ConsoleColor.Yellow, s);

static void WriteTag(string tag, ConsoleColor color, string s)
{
    var prev = Console.ForegroundColor;
    Console.ForegroundColor = color;
    Console.Write(tag);
    Console.ForegroundColor = prev;
    Console.WriteLine(s);
}
