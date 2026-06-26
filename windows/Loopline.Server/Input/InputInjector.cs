using System.Buffers.Binary;
using System.Runtime.InteropServices;
using System.Text;
using Loopline.Server.Protocol;

namespace Loopline.Server.Input;

/// <summary>
/// Injects mouse and keyboard input into Windows via SendInput. Driven by the
/// Screen trackpad on the phone (phone → PC remote-control messages).
/// </summary>
public sealed class InputInjector
{
    public void Handle(WireType type, byte[] payload)
    {
        try
        {
            switch (type)
            {
                case WireType.MouseMove when payload.Length >= 4:
                    MouseMove(BinaryPrimitives.ReadInt16LittleEndian(payload),
                              BinaryPrimitives.ReadInt16LittleEndian(payload.AsSpan(2)));
                    break;
                case WireType.MouseButton when payload.Length >= 2:
                    MouseButton(payload[0], payload[1] != 0);
                    break;
                case WireType.MouseScroll when payload.Length >= 2:
                    Scroll(BinaryPrimitives.ReadInt16LittleEndian(payload));
                    break;
                case WireType.KeyText:
                    TypeText(Encoding.UTF8.GetString(payload));
                    break;
                case WireType.KeyCode when payload.Length >= 1:
                    SpecialKey(payload[0]);
                    break;
            }
        }
        catch { /* never let a bad input packet take down the bridge */ }
    }

    private static void MouseMove(int dx, int dy)
    {
        var i = NewMouse((uint)MF.Move);
        i.U.mi.dx = dx; i.U.mi.dy = dy;
        Send(i);
    }

    private static void MouseButton(byte button, bool down)
    {
        uint flag = button switch
        {
            1 => down ? (uint)MF.RightDown : (uint)MF.RightUp,
            2 => down ? (uint)MF.MiddleDown : (uint)MF.MiddleUp,
            _ => down ? (uint)MF.LeftDown : (uint)MF.LeftUp,
        };
        Send(NewMouse(flag));
    }

    private static void Scroll(int delta)
    {
        var i = NewMouse((uint)MF.Wheel);
        i.U.mi.mouseData = unchecked((uint)(delta * 40)); // amplify to wheel notches
        Send(i);
    }

    private static void TypeText(string text)
    {
        foreach (var ch in text)
        {
            if (ch == '\n' || ch == '\r') { SpecialKey(2); continue; }
            var down = NewKey(); down.U.ki.wScan = ch; down.U.ki.dwFlags = (uint)KF.Unicode;
            var up = NewKey();   up.U.ki.wScan = ch;   up.U.ki.dwFlags = (uint)(KF.Unicode | KF.KeyUp);
            Send(down, up);
        }
    }

    private static void SpecialKey(byte code)
    {
        ushort vk = code switch
        {
            1 => 0x08,  // backspace
            2 => 0x0D,  // enter
            3 => 0x09,  // tab
            4 => 0x1B,  // escape
            5 => 0x25,  // left
            6 => 0x27,  // right
            7 => 0x26,  // up
            8 => 0x28,  // down
            9 => 0x2E,  // delete
            _ => 0,
        };
        if (vk == 0) return;
        var down = NewKey(); down.U.ki.wVk = vk;
        var up = NewKey();   up.U.ki.wVk = vk; up.U.ki.dwFlags = (uint)KF.KeyUp;
        Send(down, up);
    }

    // --- interop ---

    private static INPUT NewMouse(uint flags)
    {
        var i = new INPUT { type = 0 };
        i.U.mi = new MOUSEINPUT { dwFlags = flags };
        return i;
    }

    private static INPUT NewKey()
    {
        var i = new INPUT { type = 1 };
        i.U.ki = new KEYBDINPUT();
        return i;
    }

    private static void Send(params INPUT[] inputs) =>
        SendInput((uint)inputs.Length, inputs, Marshal.SizeOf<INPUT>());

    [Flags]
    private enum MF : uint
    {
        Move = 0x0001, LeftDown = 0x0002, LeftUp = 0x0004,
        RightDown = 0x0008, RightUp = 0x0010, MiddleDown = 0x0020, MiddleUp = 0x0040,
        Wheel = 0x0800,
    }

    [Flags]
    private enum KF : uint { KeyUp = 0x0002, Unicode = 0x0004 }

    [StructLayout(LayoutKind.Sequential)]
    private struct INPUT { public uint type; public InputUnion U; }

    [StructLayout(LayoutKind.Explicit)]
    private struct InputUnion
    {
        [FieldOffset(0)] public MOUSEINPUT mi;
        [FieldOffset(0)] public KEYBDINPUT ki;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct MOUSEINPUT
    {
        public int dx; public int dy; public uint mouseData;
        public uint dwFlags; public uint time; public IntPtr dwExtraInfo;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct KEYBDINPUT
    {
        public ushort wVk; public ushort wScan; public uint dwFlags;
        public uint time; public IntPtr dwExtraInfo;
    }

    [DllImport("user32.dll", SetLastError = true)]
    private static extern uint SendInput(uint nInputs, INPUT[] pInputs, int cbSize);
}
