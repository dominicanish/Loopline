using System.Runtime.InteropServices;
using NAudio.CoreAudioApi;

namespace Loopline.Server.Audio;

/// <summary>
/// Sets/restores the Windows default playback and recording endpoints using the
/// undocumented IPolicyConfig COM interface (the same mechanism nircmd uses).
/// </summary>
public sealed class DefaultDeviceSwitcher
{
    private enum ERole { eConsole = 0, eMultimedia = 1, eCommunications = 2 }

    [ComImport, Guid("870af99c-171d-4f9e-af0d-e63df40c2bc9")]
    private class CPolicyConfigClient { }

    [ComImport, Guid("f8679f50-850a-41cf-9c72-430f290290c8"),
     InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    private interface IPolicyConfig
    {
        [PreserveSig] int GetMixFormat(string deviceId, IntPtr ppFormat);
        [PreserveSig] int GetDeviceFormat(string deviceId, bool bDefault, IntPtr ppFormat);
        [PreserveSig] int ResetDeviceFormat(string deviceId);
        [PreserveSig] int SetDeviceFormat(string deviceId, IntPtr endpointFormat, IntPtr mixFormat);
        [PreserveSig] int GetProcessingPeriod(string deviceId, bool bDefault, IntPtr defaultPeriod, IntPtr minimumPeriod);
        [PreserveSig] int SetProcessingPeriod(string deviceId, IntPtr period);
        [PreserveSig] int GetShareMode(string deviceId, IntPtr mode);
        [PreserveSig] int SetShareMode(string deviceId, IntPtr mode);
        [PreserveSig] int GetPropertyValue(string deviceId, bool store, IntPtr key, IntPtr value);
        [PreserveSig] int SetPropertyValue(string deviceId, bool store, IntPtr key, IntPtr value);
        [PreserveSig] int SetDefaultEndpoint(string deviceId, ERole role);
        [PreserveSig] int SetEndpointVisibility(string deviceId, bool visible);
    }

    private readonly MMDeviceEnumerator _enumerator = new();

    /// <summary>Returns the current default endpoint id for a flow, or null.</summary>
    public string GetDefault(DataFlow flow)
    {
        try
        {
            using var dev = _enumerator.GetDefaultAudioEndpoint(flow, Role.Multimedia);
            return dev.ID;
        }
        catch
        {
            return null;
        }
    }

    /// <summary>Sets a device as default for all three roles.</summary>
    public void SetDefault(string deviceId)
    {
        if (string.IsNullOrEmpty(deviceId)) return;
        var cfg = (IPolicyConfig)new CPolicyConfigClient();
        try
        {
            cfg.SetDefaultEndpoint(deviceId, ERole.eConsole);
            cfg.SetDefaultEndpoint(deviceId, ERole.eMultimedia);
            cfg.SetDefaultEndpoint(deviceId, ERole.eCommunications);
        }
        finally
        {
            Marshal.ReleaseComObject(cfg);
        }
    }
}
