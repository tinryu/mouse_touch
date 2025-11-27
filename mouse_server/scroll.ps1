param([int]$delta)

Add-Type @"
using System;
using System.Runtime.InteropServices;

public class MouseScroll {
    [DllImport("user32.dll")]
    public static extern void mouse_event(uint dwFlags, uint dx, uint dy, uint dwData, int dwExtraInfo);
    
    public const uint MOUSEEVENTF_WHEEL = 0x0800;
    public const uint MOUSEEVENTF_HWHEEL = 0x01000;
    
    public static void Scroll(int delta) {
        mouse_event(MOUSEEVENTF_WHEEL, 0, 0, (uint)delta, 0);
    }
    
    public static void ScrollHorizontal(int delta) {
        mouse_event(MOUSEEVENTF_HWHEEL, 0, 0, (uint)delta, 0);
    }
}
"@

[MouseScroll]::Scroll($delta)
