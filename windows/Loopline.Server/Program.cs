using Loopline.Server;
using Loopline.Server.Audio;
using Loopline.Server.Protocol;
using Loopline.Server.Usbmux;
using NAudio.CoreAudioApi;

const int defaultPort = 7001;

bool listOnly = args.Contains("--list");
bool noSwitch = args.Contains("--no-default-switch");
bool mutePc = args.Contains("--mute-pc");
float gain = ReadFloatArg(args, "--gain", 1.0f);
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

if (devices.MicRender == null)
{
    Warn("No encontré un cable de audio virtual para el micrófono. Instala VB-CABLE\n" +
         "      (gratis) y vuelve a correr. Usa `Loopline.Server --list` para verlos.");
}
if (devices.LoopbackRender == null)
{
    Warn("No pude leer el dispositivo de salida por defecto (no podré enviar el audio\n" +
         "      de la PC al iPhone).");
}

Info($"Mute de la PC: {(mutePc ? "ON (--mute-pc)" : "OFF")}   ·   Ganancia: x{gain:0.0#} (--gain)");
if (mutePc)
    Warn("OJO: en algunas tarjetas el loopback SIGUE el volumen/mute, así que mutear\n" +
         "      deja el audio en silencio. Si no oyes nada con --mute-pc, quítalo y baja\n" +
         "      el volumen de la PC; sube la app con --gain (p.ej. --gain 4) si suena bajo.");
else
    Info("Tip: si quieres las bocinas de la PC bajas pero el iPhone fuerte, baja el\n" +
         "      volumen de Windows y compensa con --gain (p.ej. --gain 4).");

// Make the iPhone mic the default recording device so every app picks it up.
// The speaker path uses loopback + mute instead of switching playback.
var switcher = new DefaultDeviceSwitcher();
string prevRecording = null;
bool switched = false;

if (!noSwitch && devices.DefaultRecording != null)
{
    prevRecording = switcher.GetDefault(DataFlow.Capture);
    switcher.SetDefault(devices.DefaultRecording.ID);
    switched = true;
    Ok($"Micrófono por defecto → {Short(devices.DefaultRecording.FriendlyName)}");
}

var cts = new CancellationTokenSource();
bool restored = false;

void Restore()
{
    if (restored) return;
    restored = true;
    if (switched)
    {
        try { switcher.SetDefault(prevRecording); } catch { }
        Console.WriteLine();
        Ok("Micrófono por defecto restaurado.");
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
        using (var router = new AudioRouter(devices.MicRender, devices.LoopbackRender, mutePc: mutePc, gain: gain))
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

static float ReadFloatArg(string[] args, string name, float fallback)
{
    int i = Array.IndexOf(args, name);
    if (i >= 0 && i + 1 < args.Length &&
        float.TryParse(args[i + 1], System.Globalization.NumberStyles.Float,
                       System.Globalization.CultureInfo.InvariantCulture, out var v))
        return v;
    return fallback;
}

static void ReportDevices(RoutedDevices d)
{
    Console.WriteLine("Ruteo de audio:");
    Line("  mic del iPhone   → ", d.MicRender);
    Line("  audio de la PC   ← loopback de ", d.LoopbackRender);
    Console.WriteLine();

    static void Line(string label, MMDevice dev) =>
        Console.WriteLine(label + (dev != null ? Short(dev.FriendlyName) : "(no encontrado)"));
}

static string Short(string name) => name.Length > 42 ? name[..42] + "…" : name;

static void Banner()
{
    string title = "  Loopline · iPhone como mic y altavoz (USB)  ";
    string bar = new string('─', title.Length);
    Console.OutputEncoding = System.Text.Encoding.UTF8;
    Console.WriteLine("┌" + bar + "┐");
    Console.WriteLine("│" + title + "│");
    Console.WriteLine("└" + bar + "┘");
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
