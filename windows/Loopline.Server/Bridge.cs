using Loopline.Server.Audio;
using Loopline.Server.Input;
using Loopline.Server.Usbmux;
using NAudio.CoreAudioApi;

namespace Loopline.Server;

/// <summary>
/// Runs the USB connect + audio-routing loop on a background thread and exposes
/// live state and live-adjustable settings, so the console can be a simple menu.
/// </summary>
public sealed class Bridge : IDisposable
{
    private readonly DevicePicker _picker = new();
    private readonly DefaultDeviceSwitcher _switcher = new();
    private readonly UsbmuxClient _usb = new();
    private readonly InputInjector _injector = new();

    private Thread _thread;
    private CancellationTokenSource _cts;
    private volatile AudioRouter _router;
    private string _prevRecording;
    private bool _switched;

    // Settings — read at (re)start; Mute and Gain also apply live.
    public bool MutePc;
    public float Gain = 1f;
    public bool SwitchDefaults = true;
    public string LoopbackOverrideId;   // null = system default playback device
    public int Port = 7001;

    // Live state for the UI.
    public volatile bool Connected;
    public string PeerName = "";
    public volatile int LatencyMs;
    public volatile float MicLevel;
    public volatile float SpeakerLevel;
    public string StatusText = "Starting…";
    public RoutedDevices Devices { get; private set; } = new();

    public DevicePicker Picker => _picker;

    public void Start()
    {
        _cts = new CancellationTokenSource();
        _thread = new Thread(Loop) { IsBackground = true, Name = "Loopline-bridge" };
        _thread.Start();
    }

    public void Stop()
    {
        _cts?.Cancel();
        _thread?.Join(1500);
        RestoreDefaults();
    }

    public void Restart() { Stop(); Start(); }

    public void SetMute(bool on) { MutePc = on; _router?.SetMute(on); }

    public void SetGain(float g)
    {
        Gain = Math.Clamp(g, 0.25f, 12f);
        var r = _router;
        if (r != null) r.Gain = Gain;
    }

    private void Loop()
    {
        var ct = _cts.Token;
        Devices = _picker.Resolve();
        if (!string.IsNullOrEmpty(LoopbackOverrideId))
        {
            var dev = _picker.RenderById(LoopbackOverrideId);
            if (dev != null) Devices.LoopbackRender = dev;
        }
        ApplyDefaultSwitch();

        while (!ct.IsCancellationRequested)
        {
            try
            {
                var list = SafeList();
                var dev = list.FirstOrDefault(d => d.ConnectionType == "USB") ?? list.FirstOrDefault();
                if (dev == null) { StatusText = "Waiting for iPhone over USB…"; Wait(ct, 800); continue; }

                var stream = _usb.Connect(dev.DeviceId, Port, out var owned);
                if (stream == null) { StatusText = "iPhone detected — open the Loopline app on your phone…"; Wait(ct, 800); continue; }

                using (owned)
                using (var session = new PhoneSession(stream))
                using (var router = new AudioRouter(Devices.MicRender, Devices.LoopbackRender, MutePc, Gain))
                using (var screen = new ScreenStreamer())
                {
                    _router = router;
                    session.OnMic = router.EnqueueMic;
                    router.OnSpeakerPacket = session.SendSpeaker;
                    session.OnPeerName = name => { PeerName = name; Connected = true; };
                    session.OnInput = (t, p) => _injector.Handle(t, p);
                    screen.OnFrame = session.SendScreenFrame;
                    session.OnScreenControl = on => screen.SetEnabled(on);

                    router.Start();
                    session.SendHello(Environment.MachineName);
                    StatusText = "Linked — confirming handshake…";

                    using var ping = new Timer(_ => session.SendPing(), null, 1000, 1000);
                    using var meter = new Timer(_ =>
                    {
                        MicLevel = router.MicLevel;
                        SpeakerLevel = router.SpeakerLevel;
                        LatencyMs = session.LatencyMs;
                    }, null, 120, 120);

                    session.Run(ct);
                }

                _router = null;
                Connected = false; PeerName = ""; MicLevel = 0; SpeakerLevel = 0;
                StatusText = "iPhone disconnected. Reconnecting…";
            }
            catch (Exception ex)
            {
                _router = null;
                Connected = false;
                StatusText = "Retrying… (" + ex.Message + ")";
                Wait(ct, 800);
            }
        }
    }

    private void ApplyDefaultSwitch()
    {
        if (_switched || !SwitchDefaults || Devices.DefaultRecording == null) return;
        try
        {
            _prevRecording = _switcher.GetDefault(DataFlow.Capture);
            _switcher.SetDefault(Devices.DefaultRecording.ID);
            _switched = true;
        }
        catch { }
    }

    private void RestoreDefaults()
    {
        if (!_switched) return;
        try { _switcher.SetDefault(_prevRecording); } catch { }
        _switched = false;
    }

    private List<UsbDevice> SafeList()
    {
        try { return _usb.ListDevices(); }
        catch { return new List<UsbDevice>(); }
    }

    private static void Wait(CancellationToken ct, int ms) => ct.WaitHandle.WaitOne(ms);

    public void Dispose() => Stop();
}
