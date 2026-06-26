using NAudio.CoreAudioApi;

namespace Loopline.Server.Audio;

/// <summary>The four endpoints Loopline needs for full-duplex routing.</summary>
public sealed class RoutedDevices
{
    /// <summary>Where we render the iPhone mic (apps read it from its capture side). e.g. CABLE-A Input.</summary>
    public MMDevice MicRender;
    /// <summary>Where we capture app output to send to the iPhone. e.g. CABLE-B Output.</summary>
    public MMDevice SpeakerCapture;
    /// <summary>Endpoint to set as Windows default playback. e.g. CABLE-B Input.</summary>
    public MMDevice DefaultPlayback;
    /// <summary>Endpoint to set as Windows default recording. e.g. CABLE-A Output.</summary>
    public MMDevice DefaultRecording;

    public bool IsComplete => MicRender != null && SpeakerCapture != null;
}

public sealed class DevicePicker
{
    private readonly MMDeviceEnumerator _en = new();

    /// <summary>
    /// Resolves routing endpoints. Prefers a two-cable layout (VB-Cable A+B or
    /// VoiceMeeter); falls back to a single VB-Cable (half-duplex) if that's all
    /// that's present.
    /// </summary>
    public RoutedDevices Resolve()
    {
        var renders = _en.EnumerateAudioEndPoints(DataFlow.Render, DeviceState.Active).ToList();
        var captures = _en.EnumerateAudioEndPoints(DataFlow.Capture, DeviceState.Active).ToList();

        var r = new RoutedDevices
        {
            // Two-cable layout (recommended).
            MicRender         = FindRender(renders, "CABLE-A Input", "CABLE-A", "VoiceMeeter Input", "VoiceMeeter Aux Input"),
            SpeakerCapture    = FindCapture(captures, "CABLE-B Output", "CABLE-B", "VoiceMeeter Output", "VoiceMeeter Aux Output"),
            DefaultPlayback   = FindRender(renders, "CABLE-B Input", "CABLE-B", "VoiceMeeter Input", "VoiceMeeter Aux Input"),
            DefaultRecording  = FindCapture(captures, "CABLE-A Output", "CABLE-A", "VoiceMeeter Output", "VoiceMeeter Aux Output"),
        };

        // Single-cable fallback (half-duplex): everything rides one VB-Cable.
        if (r.MicRender == null) r.MicRender = FindRender(renders, "CABLE Input", "CABLE");
        if (r.SpeakerCapture == null) r.SpeakerCapture = FindCapture(captures, "CABLE Output", "CABLE");
        if (r.DefaultPlayback == null) r.DefaultPlayback = FindRender(renders, "CABLE Input", "CABLE");
        if (r.DefaultRecording == null) r.DefaultRecording = FindCapture(captures, "CABLE Output", "CABLE");

        return r;
    }

    public (List<string> renders, List<string> captures) ListNames()
    {
        var renders = _en.EnumerateAudioEndPoints(DataFlow.Render, DeviceState.Active)
                         .Select(d => d.FriendlyName).ToList();
        var captures = _en.EnumerateAudioEndPoints(DataFlow.Capture, DeviceState.Active)
                          .Select(d => d.FriendlyName).ToList();
        return (renders, captures);
    }

    private static MMDevice FindRender(List<MMDevice> list, params string[] needles) => Find(list, needles);
    private static MMDevice FindCapture(List<MMDevice> list, params string[] needles) => Find(list, needles);

    private static MMDevice Find(List<MMDevice> list, string[] needles)
    {
        foreach (var needle in needles)
        {
            var hit = list.FirstOrDefault(d =>
                d.FriendlyName.Contains(needle, StringComparison.OrdinalIgnoreCase));
            if (hit != null) return hit;
        }
        return null;
    }
}
