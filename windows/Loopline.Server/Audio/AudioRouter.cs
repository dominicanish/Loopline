using Loopline.Server.Protocol;
using NAudio.CoreAudioApi;
using NAudio.Wave;
using NAudio.Wave.SampleProviders;

namespace Loopline.Server.Audio;

/// <summary>
/// Bridges Windows audio and the phone link:
///  - captures PC output (a virtual-cable record endpoint) → emits 48 kHz mono
///    int16 packets for the phone's speaker;
///  - renders phone-mic packets to a virtual-cable playback endpoint so apps see
///    them as a microphone.
/// </summary>
public sealed class AudioRouter : IDisposable
{
    private static readonly WaveFormat Wire = new WaveFormat(AudioSpec.SampleRate, 16, AudioSpec.Channels);

    private readonly MMDevice _micRender;
    private readonly MMDevice _speakerCapture;

    private WasapiCapture _capture;
    private WasapiOut _output;
    private BufferedWaveProvider _captureBuffer;
    private BufferedWaveProvider _micBuffer;
    private Thread _pump;
    private volatile bool _running;

    /// <summary>Raised with a 48 kHz mono int16 packet to forward to the phone speaker.</summary>
    public Action<byte[]> OnSpeakerPacket;
    public volatile float MicLevel;
    public volatile float SpeakerLevel;

    public AudioRouter(MMDevice micRender, MMDevice speakerCapture)
    {
        _micRender = micRender;
        _speakerCapture = speakerCapture;
    }

    public void Start()
    {
        if (_running) return;
        _running = true;

        // --- Capture path: PC output -> phone ---
        if (_speakerCapture != null)
        {
            _capture = new WasapiCapture(_speakerCapture);
            _captureBuffer = new BufferedWaveProvider(_capture.WaveFormat)
            {
                DiscardOnBufferOverflow = true,
                BufferDuration = TimeSpan.FromSeconds(2),
            };
            _capture.DataAvailable += (_, e) => _captureBuffer.AddSamples(e.Buffer, 0, e.BytesRecorded);
            _capture.StartRecording();

            _pump = new Thread(PumpCapture) { IsBackground = true, Name = "Loopline-capture" };
            _pump.Start();
        }

        // --- Render path: phone mic -> CABLE input ---
        if (_micRender != null)
        {
            _micBuffer = new BufferedWaveProvider(Wire)
            {
                DiscardOnBufferOverflow = true,
                BufferDuration = TimeSpan.FromSeconds(2),
            };
            var mix = _micRender.AudioClient.MixFormat;
            ISampleProvider sp = _micBuffer.ToSampleProvider();
            if (sp.WaveFormat.SampleRate != mix.SampleRate)
                sp = new WdlResamplingSampleProvider(sp, mix.SampleRate);
            sp = ExpandChannels(sp, mix.Channels);

            _output = new WasapiOut(_micRender, AudioClientShareMode.Shared, true, 100);
            _output.Init(sp.ToWaveProvider());
            _output.Play();
        }
    }

    /// <summary>Feed a 48 kHz mono int16 packet received from the phone's mic.</summary>
    public void EnqueueMic(byte[] data)
    {
        if (_micBuffer == null) return;
        _micBuffer.AddSamples(data, 0, data.Length);
        MicLevel = Rms16(data);
    }

    private void PumpCapture()
    {
        ISampleProvider sp = _captureBuffer.ToSampleProvider();
        sp = ToMono(sp);
        if (sp.WaveFormat.SampleRate != AudioSpec.SampleRate)
            sp = new WdlResamplingSampleProvider(sp, AudioSpec.SampleRate);

        var floats = new float[AudioSpec.FrameSamples];
        var pcm = new byte[AudioSpec.FrameSamples * 2];

        while (_running)
        {
            int read = sp.Read(floats, 0, floats.Length);
            if (read <= 0) { Thread.Sleep(2); continue; }

            for (int i = 0; i < read; i++)
            {
                int s = (int)(Math.Clamp(floats[i], -1f, 1f) * 32767f);
                pcm[i * 2] = (byte)(s & 0xFF);
                pcm[i * 2 + 1] = (byte)((s >> 8) & 0xFF);
            }
            SpeakerLevel = RmsFloat(floats, read);

            if (read == floats.Length) OnSpeakerPacket?.Invoke(pcm);
            else OnSpeakerPacket?.Invoke(pcm[..(read * 2)]);
        }
    }

    private static ISampleProvider ToMono(ISampleProvider sp)
    {
        if (sp.WaveFormat.Channels == 1) return sp;
        if (sp.WaveFormat.Channels == 2) return new StereoToMonoSampleProvider(sp) { LeftVolume = 0.5f, RightVolume = 0.5f };
        var mux = new MultiplexingSampleProvider(new[] { sp }, 1);
        mux.ConnectInputToOutput(0, 0);
        return mux;
    }

    private static ISampleProvider ExpandChannels(ISampleProvider sp, int channels)
    {
        if (channels <= 1) return sp;
        if (channels == 2) return new MonoToStereoSampleProvider(sp);
        var mux = new MultiplexingSampleProvider(new[] { sp }, channels);
        for (int c = 0; c < channels; c++) mux.ConnectInputToOutput(0, c);
        return mux;
    }

    private static float Rms16(byte[] pcm)
    {
        int samples = pcm.Length / 2;
        if (samples == 0) return 0;
        double sum = 0;
        for (int i = 0; i < samples; i++)
        {
            short s = (short)(pcm[i * 2] | (pcm[i * 2 + 1] << 8));
            float f = s / 32768f;
            sum += f * f;
        }
        return (float)Math.Min(1.0, Math.Sqrt(sum / samples) * 4);
    }

    private static float RmsFloat(float[] buf, int count)
    {
        if (count == 0) return 0;
        double sum = 0;
        for (int i = 0; i < count; i++) sum += buf[i] * buf[i];
        return (float)Math.Min(1.0, Math.Sqrt(sum / count) * 4);
    }

    public void Dispose()
    {
        _running = false;
        try { _pump?.Join(500); } catch { }
        try { _capture?.StopRecording(); } catch { }
        _capture?.Dispose();
        try { _output?.Stop(); } catch { }
        _output?.Dispose();
    }
}
