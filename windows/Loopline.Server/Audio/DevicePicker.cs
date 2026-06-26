using NAudio.CoreAudioApi;

namespace Loopline.Server.Audio;

/// <summary>The endpoints Loopline needs for the single-cable + loopback model.</summary>
public sealed class RoutedDevices
{
    /// <summary>Where we render the iPhone mic; apps read it from its capture side. e.g. CABLE Input.</summary>
    public MMDevice MicRender;
    /// <summary>Capture endpoint to set as Windows default recording. e.g. CABLE Output.</summary>
    public MMDevice DefaultRecording;
    /// <summary>The PC's real speakers — we loopback-capture and mute these while connected.</summary>
    public MMDevice LoopbackRender;

    public bool IsComplete => MicRender != null && LoopbackRender != null;
}

public sealed class DevicePicker
{
    private readonly MMDeviceEnumerator _en = new();

    /// <summary>
    /// Resolves routing. The mic path rides a single virtual cable; the speaker
    /// path is a WASAPI loopback of the PC's real default playback device (no
    /// second cable needed).
    /// </summary>
    public RoutedDevices Resolve()
    {
        var renders = _en.EnumerateAudioEndPoints(DataFlow.Render, DeviceState.Active).ToList();
        var captures = _en.EnumerateAudioEndPoints(DataFlow.Capture, DeviceState.Active).ToList();

        return new RoutedDevices
        {
            MicRender = Find(renders, "CABLE Input", "CABLE-A Input", "CABLE", "VoiceMeeter Input", "VoiceMeeter Aux Input"),
            DefaultRecording = Find(captures, "CABLE Output", "CABLE-A Output", "CABLE", "VoiceMeeter Output", "VoiceMeeter Aux Output"),
            LoopbackRender = DefaultRender(),
        };
    }

    /// <summary>The current default playback device (the real speakers/headphones).</summary>
    public MMDevice DefaultRender()
    {
        try { return _en.GetDefaultAudioEndpoint(DataFlow.Render, Role.Multimedia); }
        catch { return null; }
    }

    public (List<string> renders, List<string> captures) ListNames()
    {
        var renders = _en.EnumerateAudioEndPoints(DataFlow.Render, DeviceState.Active)
                         .Select(d => d.FriendlyName).ToList();
        var captures = _en.EnumerateAudioEndPoints(DataFlow.Capture, DeviceState.Active)
                          .Select(d => d.FriendlyName).ToList();
        return (renders, captures);
    }

    private static MMDevice Find(List<MMDevice> list, params string[] needles)
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
