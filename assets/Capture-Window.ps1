# Capture the running app window to a PNG, forcing it to the foreground first.
Add-Type -AssemblyName System.Drawing
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class Win32Cap {
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
    [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr hWnd, IntPtr lpdwProcessId);
    [DllImport("kernel32.dll")] public static extern uint GetCurrentThreadId();
    [DllImport("user32.dll")] public static extern bool AttachThreadInput(uint idAttach, uint idAttachTo, bool fAttach);
    [DllImport("user32.dll")] public static extern bool BringWindowToTop(IntPtr hWnd);
    [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
}
"@

$proc = Get-Process ObsidianGamesAdminTool -ErrorAction SilentlyContinue
if (-not $proc) { "app not running"; exit 1 }
$h = $proc.MainWindowHandle
if ($h -eq [IntPtr]::Zero) { "no main window handle"; exit 1 }

[Win32Cap]::ShowWindow($h, 9) | Out-Null     # SW_RESTORE
[Win32Cap]::BringWindowToTop($h) | Out-Null

# Attach our input thread to the foreground thread so SetForegroundWindow sticks.
$fg = [Win32Cap]::GetForegroundWindow()
if ($fg -ne $h) {
    $fgThread = [Win32Cap]::GetWindowThreadProcessId($fg, [IntPtr]::Zero)
    $ourThread = [Win32Cap]::GetCurrentThreadId()
    [Win32Cap]::AttachThreadInput($ourThread, $fgThread, $true) | Out-Null
    [Win32Cap]::SetForegroundWindow($h) | Out-Null
    [Win32Cap]::AttachThreadInput($ourThread, $fgThread, $false) | Out-Null
}
Start-Sleep -Milliseconds 1000

$stillFg = ([Win32Cap]::GetForegroundWindow() -eq $h)
$r = New-Object Win32Cap+RECT
[Win32Cap]::GetWindowRect($h, [ref]$r) | Out-Null
$w = $r.Right - $r.Left
$ht = $r.Bottom - $r.Top
if ($w -le 0 -or $ht -le 0) { "bad rect ${w}x${ht}"; exit 1 }

$bmp = [System.Drawing.Bitmap]::new($w, $ht)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.CopyFromScreen($r.Left, $r.Top, 0, 0, [System.Drawing.Size]::new($w, $ht))
$out = Join-Path $env:TEMP 'og-app-window.png'
$bmp.Save($out, [System.Drawing.Imaging.ImageFormat]::Png)
$g.Dispose(); $bmp.Dispose()
"captured ${w}x${ht} foreground=$stillFg -> $out"
