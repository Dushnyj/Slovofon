<#
.SYNOPSIS
Checks only an already running Slovofon main HWND and restores its placement.
.DESCRIPTION
Temporarily resizes, minimizes, restores and maximizes that window without UI
clicks. Does not launch the application, read its database, inspect other HWNDs,
capture the screen, or change monitor/system DPI. Run after a debug build.
The DPI message test uses the window's ACTUAL current DPI; cross-monitor DPI
changes still require hardware/interactive coverage. Pure geometry at multiple
DPIs is covered by windows/runner/tests/window_size_policy_test.cpp.
.EXAMPLE
./tools/windows/Test-WindowSizing.ps1 -ProcessId 1234 -ExpectInitialClientSize -OutputPath ./artifacts/window-sizing.json
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [ValidateRange(1, 2147483647)]
  [int]$ProcessId,
  [switch]$ReadOnly,
  [switch]$ExpectInitialClientSize,
  [string]$OutputPath
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

if (-not ('SlovofonWindowSizing.Native' -as [type])) {
  Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
using System.Text;
namespace SlovofonWindowSizing {
  [StructLayout(LayoutKind.Sequential)] public struct Point { public int X, Y; }
  [StructLayout(LayoutKind.Sequential)] public struct Rect {
    public int Left, Top, Right, Bottom;
    public int Width { get { return Right - Left; } }
    public int Height { get { return Bottom - Top; } }
  }
  [StructLayout(LayoutKind.Sequential)] public struct Placement {
    public uint Length, Flags, ShowCmd;
    public Point MinPosition, MaxPosition;
    public Rect NormalPosition;
  }
  [StructLayout(LayoutKind.Sequential)] public struct MinMax {
    public Point Reserved, MaxSize, MaxPosition, MinTrackSize, MaxTrackSize;
  }
  [StructLayout(LayoutKind.Sequential)] public struct MonitorInfo {
    public uint Size;
    public Rect Monitor, Work;
    public uint Flags;
  }
  public static class Native {
    [DllImport("user32.dll")] public static extern bool IsWindow(IntPtr hwnd);
    [DllImport("user32.dll")] public static extern bool IsIconic(IntPtr hwnd);
    [DllImport("user32.dll")] public static extern bool IsZoomed(IntPtr hwnd);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetClassName(IntPtr hwnd, StringBuilder name, int max);
    [DllImport("user32.dll", SetLastError=true)] public static extern bool GetWindowRect(IntPtr hwnd, out Rect rect);
    [DllImport("user32.dll", SetLastError=true)] public static extern bool GetClientRect(IntPtr hwnd, out Rect rect);
    [DllImport("user32.dll", SetLastError=true)] public static extern bool GetWindowPlacement(IntPtr hwnd, ref Placement placement);
    [DllImport("user32.dll", SetLastError=true)] public static extern bool SetWindowPlacement(IntPtr hwnd, ref Placement placement);
    [DllImport("user32.dll", SetLastError=true)] public static extern bool SetWindowPos(IntPtr hwnd, IntPtr after, int x, int y, int width, int height, uint flags);
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hwnd, int command);
    [DllImport("user32.dll")] public static extern uint GetDpiForWindow(IntPtr hwnd);
    [DllImport("user32.dll", SetLastError=true)] public static extern IntPtr SetThreadDpiAwarenessContext(IntPtr context);
    [DllImport("user32.dll")] public static extern int GetSystemMetricsForDpi(int index, uint dpi);
    [DllImport("user32.dll")] public static extern IntPtr MonitorFromWindow(IntPtr hwnd, uint flags);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern bool GetMonitorInfo(IntPtr monitor, ref MonitorInfo info);
    [DllImport("user32.dll", EntryPoint="GetWindowLongPtrW")] public static extern IntPtr GetWindowLongPtr(IntPtr hwnd, int index);
    [DllImport("user32.dll")] public static extern IntPtr GetMenu(IntPtr hwnd);
    [DllImport("user32.dll")] public static extern bool AdjustWindowRectExForDpi(ref Rect rect, uint style, bool menu, uint exStyle, uint dpi);
    [DllImport("user32.dll", SetLastError=true)] public static extern IntPtr SendMessageTimeout(IntPtr hwnd, uint message, UIntPtr wparam, IntPtr lparam, uint flags, uint timeout, out UIntPtr result);
    [DllImport("dwmapi.dll")] public static extern int DwmGetWindowAttribute(IntPtr hwnd, uint attribute, out Rect rect, uint size);

    public static void Check(bool success, string operation) {
      if (!success) throw new InvalidOperationException(operation + " failed: " + Marshal.GetLastWin32Error());
    }
    public static Placement ReadPlacement(IntPtr hwnd) {
      var value = new Placement();
      value.Length = (uint)Marshal.SizeOf(typeof(Placement));
      Check(GetWindowPlacement(hwnd, ref value), "GetWindowPlacement");
      return value;
    }
    public static Rect WindowRect(IntPtr hwnd) { Rect r; Check(GetWindowRect(hwnd, out r), "GetWindowRect"); return r; }
    public static Rect ClientRect(IntPtr hwnd) { Rect r; Check(GetClientRect(hwnd, out r), "GetClientRect"); return r; }
    public static Rect VisibleRect(IntPtr hwnd) {
      Rect r;
      int result = DwmGetWindowAttribute(hwnd, 9, out r, (uint)Marshal.SizeOf(typeof(Rect))); // DWMWA_EXTENDED_FRAME_BOUNDS
      if (result != 0) throw new InvalidOperationException("DwmGetWindowAttribute failed: " + result);
      return r;
    }
    public static Rect WorkArea(IntPtr hwnd) {
      var info = new MonitorInfo(); info.Size = (uint)Marshal.SizeOf(typeof(MonitorInfo));
      Check(GetMonitorInfo(MonitorFromWindow(hwnd, 2), ref info), "GetMonitorInfo");
      return info.Work;
    }
    public static Rect MonitorArea(IntPtr hwnd) {
      var info = new MonitorInfo(); info.Size = (uint)Marshal.SizeOf(typeof(MonitorInfo));
      Check(GetMonitorInfo(MonitorFromWindow(hwnd, 2), ref info), "GetMonitorInfo");
      return info.Monitor;
    }
    public static Rect Frame(IntPtr hwnd) {
      var frame = new Rect();
      uint style = (uint)GetWindowLongPtr(hwnd, -16).ToInt64() & ~(0x01000000u | 0x20000000u);
      uint exStyle = (uint)GetWindowLongPtr(hwnd, -20).ToInt64();
      Check(AdjustWindowRectExForDpi(ref frame, style, GetMenu(hwnd) != IntPtr.Zero, exStyle, GetDpiForWindow(hwnd)), "AdjustWindowRectExForDpi");
      return frame;
    }
    public static MinMax TrackingLimits(IntPtr hwnd) {
      var value = new MinMax();
      // Windows pre-populates MINMAXINFO before normal dispatch. A synthetic
      // query supplies the equivalent DPI-aware defaults before the app override.
      uint dpi = GetDpiForWindow(hwnd);
      value.MinTrackSize.X = GetSystemMetricsForDpi(34, dpi); // SM_CXMINTRACK
      value.MinTrackSize.Y = GetSystemMetricsForDpi(35, dpi); // SM_CYMINTRACK
      IntPtr pointer = Marshal.AllocHGlobal(Marshal.SizeOf(typeof(MinMax)));
      try {
        Marshal.StructureToPtr(value, pointer, false);
        Message(hwnd, 0x0024, UIntPtr.Zero, pointer);
        return (MinMax)Marshal.PtrToStructure(pointer, typeof(MinMax));
      } finally { Marshal.FreeHGlobal(pointer); }
    }
    public static void Message(IntPtr hwnd, uint message, UIntPtr wparam, IntPtr lparam) {
      UIntPtr result;
      Check(SendMessageTimeout(hwnd, message, wparam, lparam, 2, 2000, out result) != IntPtr.Zero, "SendMessageTimeout");
    }
    public static void SameDpiSuggestedRect(IntPtr hwnd, Rect rect) {
      uint dpi = GetDpiForWindow(hwnd);
      IntPtr pointer = Marshal.AllocHGlobal(Marshal.SizeOf(typeof(Rect)));
      try {
        Marshal.StructureToPtr(rect, pointer, false);
        Message(hwnd, 0x02E0, new UIntPtr(dpi | (dpi << 16)), pointer);
      } finally { Marshal.FreeHGlobal(pointer); }
    }
  }
}
'@
}

$process = Get-Process -Id $ProcessId
if ($process.ProcessName -ine 'Slovofon' -or [IO.Path]::GetFileName($process.Path) -ine 'Slovofon.exe') {
  throw 'The supplied process is not Slovofon.exe.'
}
$hwnd = $process.MainWindowHandle
if ($hwnd -eq [IntPtr]::Zero -or -not [SlovofonWindowSizing.Native]::IsWindow($hwnd)) {
  throw 'Slovofon does not have a main window.'
}
$className = [Text.StringBuilder]::new(256)
[void][SlovofonWindowSizing.Native]::GetClassName($hwnd, $className, 256)
if ($className.ToString() -ne 'FLUTTER_RUNNER_WIN32_WINDOW') {
  throw 'The supplied HWND is not the Slovofon Flutter runner window.'
}

# Geometry APIs must use physical pixels even when PowerShell itself is DPI
# unaware or system-aware. This affects only this helper thread, not the target
# application, monitor scaling, or any system setting. Restore even on ReadOnly
# early return or a failed assertion.
$previousDpiContext = [SlovofonWindowSizing.Native]::SetThreadDpiAwarenessContext([IntPtr]::new(-4)) # PER_MONITOR_AWARE_V2
[SlovofonWindowSizing.Native]::Check($previousDpiContext -ne [IntPtr]::Zero, 'set helper thread DPI context')
try {
$original = [SlovofonWindowSizing.Native]::ReadPlacement($hwnd)
$checks = [Collections.Generic.List[object]]::new()

function Write-Report($Value) {
  $json = $Value | ConvertTo-Json -Depth 8
  if ($OutputPath) {
    $parent = Split-Path -Parent ([IO.Path]::GetFullPath($OutputPath))
    [void][IO.Directory]::CreateDirectory($parent)
    [IO.File]::WriteAllText([IO.Path]::GetFullPath($OutputPath), $json, [Text.UTF8Encoding]::new($false))
  }
  $json
}

if ($ReadOnly) {
  $client = [SlovofonWindowSizing.Native]::ClientRect($hwnd)
  $outer = [SlovofonWindowSizing.Native]::WindowRect($hwnd)
  $tracking = [SlovofonWindowSizing.Native]::TrackingLimits($hwnd)
  $dpi = [SlovofonWindowSizing.Native]::GetDpiForWindow($hwnd)
  Write-Report ([pscustomobject]@{
    Mode = 'ReadOnly'; ProcessId = $ProcessId; Executable = $process.Path
    WindowHandle = $hwnd.ToInt64(); Dpi = $dpi
    CoordinateSpace = 'Physical pixels (PER_MONITOR_AWARE_V2 helper thread)'
    ClientWidth = $client.Width; ClientHeight = $client.Height
    OuterBounds = $outer; MinimumTrackWidth = $tracking.MinTrackSize.X
    VisibleBounds = [SlovofonWindowSizing.Native]::VisibleRect($hwnd)
    MinimumTrackHeight = $tracking.MinTrackSize.Y
    WorkArea = [SlovofonWindowSizing.Native]::WorkArea($hwnd)
    NonClientFrame = [SlovofonWindowSizing.Native]::Frame($hwnd)
    Minimized = [SlovofonWindowSizing.Native]::IsIconic($hwnd)
    Maximized = [SlovofonWindowSizing.Native]::IsZoomed($hwnd)
    Mutation = 'None: only geometry/placement and WM_GETMINMAXINFO query with SendMessageTimeout.'
  })
  return
}

function Assert-True([bool]$Condition, [string]$Message) {
  if (-not $Condition) { throw $Message }
}

function Wait-WindowState([bool]$Minimized, [bool]$Maximized) {
  for ($attempt = 0; $attempt -lt 30; $attempt++) {
    if ([SlovofonWindowSizing.Native]::IsIconic($hwnd) -eq $Minimized -and
        [SlovofonWindowSizing.Native]::IsZoomed($hwnd) -eq $Maximized) { return }
    Start-Sleep -Milliseconds 50
  }
  throw "Window state did not settle: minimized=$Minimized maximized=$Maximized"
}

function Read-ExpectedBounds {
  $dpi = [SlovofonWindowSizing.Native]::GetDpiForWindow($hwnd)
  $frame = [SlovofonWindowSizing.Native]::Frame($hwnd)
  $work = [SlovofonWindowSizing.Native]::WorkArea($hwnd)
  [pscustomobject]@{
    Dpi = $dpi; Frame = $frame; Work = $work
    MinimumWidth = [Math]::Min([Math]::Ceiling(900 * $dpi / 96.0) + $frame.Width, $work.Width)
    MinimumHeight = [Math]::Min([Math]::Ceiling(600 * $dpi / 96.0) + $frame.Height, $work.Height)
  }
}

function Assert-NormalBounds([string]$Stage, [bool]$CheckInsideWorkArea = $true) {
  Wait-WindowState $false $false
  Start-Sleep -Milliseconds 100 # Let DWM publish the current visible frame.
  $expected = Read-ExpectedBounds
  $outer = [SlovofonWindowSizing.Native]::WindowRect($hwnd)
  $client = [SlovofonWindowSizing.Native]::ClientRect($hwnd)
  $visible = [SlovofonWindowSizing.Native]::VisibleRect($hwnd)
  Assert-True ($outer.Width -ge $expected.MinimumWidth) "$Stage outer width below client-DIP minimum"
  Assert-True ($outer.Height -ge $expected.MinimumHeight) "$Stage outer height below client-DIP minimum"
  Assert-True ($client.Width -ge $expected.MinimumWidth - $expected.Frame.Width) "$Stage client width too small"
  Assert-True ($client.Height -ge $expected.MinimumHeight - $expected.Frame.Height) "$Stage client height too small"
  if ($CheckInsideWorkArea) {
    Assert-True ($visible.Left -ge $expected.Work.Left -and $visible.Top -ge $expected.Work.Top -and
                 $visible.Right -le $expected.Work.Right -and $visible.Bottom -le $expected.Work.Bottom) "$Stage visible window escaped the work area"
  }
  $checks.Add([pscustomobject]@{
    Stage = $Stage; Dpi = $expected.Dpi
    ClientWidth = $client.Width; ClientHeight = $client.Height
    OuterWidth = $outer.Width; OuterHeight = $outer.Height
    VisibleBounds = $visible
  })
}

try {
  if ($ExpectInitialClientSize) {
    Assert-NormalBounds 'initial-client-size'
    $expected = Read-ExpectedBounds
    $client = [SlovofonWindowSizing.Native]::ClientRect($hwnd)
    $width = [Math]::Min([Math]::Ceiling(1280 * $expected.Dpi / 96.0) + $expected.Frame.Width, $expected.Work.Width) - $expected.Frame.Width
    $height = [Math]::Min([Math]::Ceiling(720 * $expected.Dpi / 96.0) + $expected.Frame.Height, $expected.Work.Height) - $expected.Frame.Height
    Assert-True ($client.Width -eq $width -and $client.Height -eq $height) 'Startup size is not 1280x720 client DIPs, clamped to the work area.'
  }

  $normal = $original
  $normal.ShowCmd = 4 # SW_SHOWNOACTIVATE: normal, without stealing focus.
  $normal.Flags = 0
  [SlovofonWindowSizing.Native]::Check([SlovofonWindowSizing.Native]::SetWindowPlacement($hwnd, [ref]$normal), 'restore normal')
  Wait-WindowState $false $false
  $expected = Read-ExpectedBounds
  $tracking = [SlovofonWindowSizing.Native]::TrackingLimits($hwnd)
  Assert-True ($tracking.MinTrackSize.X -eq $expected.MinimumWidth -and
               $tracking.MinTrackSize.Y -eq $expected.MinimumHeight) 'WM_GETMINMAXINFO returned the wrong physical minimum.'
  $checks.Add([pscustomobject]@{ Stage = 'minimum-tracking'; Width = $tracking.MinTrackSize.X; Height = $tracking.MinTrackSize.Y; Dpi = $expected.Dpi })

  # Submit normal snap-like rectangles, not shell keystrokes. Their invisible
  # resize borders intentionally exceed rcWork; the native policy must preserve
  # the exact rectangle when its client minimum is satisfied.
  Assert-NormalBounds 'normal-before-snap-like'
  $expected = Read-ExpectedBounds
  $outer = [SlovofonWindowSizing.Native]::WindowRect($hwnd)
  $visible = [SlovofonWindowSizing.Native]::VisibleRect($hwnd)
  $invisibleLeft = $visible.Left - $outer.Left
  $invisibleTop = $visible.Top - $outer.Top
  $invisibleRight = $outer.Right - $visible.Right
  $invisibleBottom = $outer.Bottom - $visible.Bottom
  $half = [int][Math]::Floor($expected.Work.Width / 2.0)
  $halfOuterWidth = $half + $invisibleLeft + $invisibleRight
  $snapSides = if ($halfOuterWidth -ge $expected.MinimumWidth) { @('left', 'right') } else { @('full-width') }
  foreach ($side in $snapSides) {
    $snap = $expected.Work
    if ($side -eq 'left') { $snap.Right = $expected.Work.Left + $half }
    if ($side -eq 'right') { $snap.Left = $expected.Work.Left + $half }
    $snap.Left -= $invisibleLeft
    $snap.Top -= $invisibleTop
    $snap.Right += $invisibleRight
    $snap.Bottom += $invisibleBottom
    [SlovofonWindowSizing.Native]::Check([SlovofonWindowSizing.Native]::SetWindowPos($hwnd, [IntPtr]::Zero, $snap.Left, $snap.Top, $snap.Width, $snap.Height, 0x0014), 'snap-like bounds')
    Assert-NormalBounds "snap-like-$side"
    $actualSnap = [SlovofonWindowSizing.Native]::WindowRect($hwnd)
    Assert-True ($actualSnap.Left -eq $snap.Left -and $actualSnap.Top -eq $snap.Top -and
                 $actualSnap.Right -eq $snap.Right -and $actualSnap.Bottom -eq $snap.Bottom) "Snap-like $side rectangle was shifted or shrunk."
    $checks.Add([pscustomobject]@{ Stage = "snap-like-$side-preserved"; Requested = $snap; Actual = $actualSnap })
  }

  # Includes programmatic shrink and a caller deliberately omitting CHANGING.
  foreach ($flags in @(0x0016, 0x0416)) { # NOMOVE | NOZORDER | NOACTIVATE [+ NOSENDCHANGING]
    [SlovofonWindowSizing.Native]::Check([SlovofonWindowSizing.Native]::SetWindowPos($hwnd, [IntPtr]::Zero, 0, 0, 212, 200, $flags), 'programmatic shrink')
    Assert-NormalBounds "programmatic-shrink-$flags"
  }

  # Keep the real system DPI; only exercise how our HWND handles a bad suggestion.
  $expected = Read-ExpectedBounds
  $suggested = $expected.Work
  $suggested.Left = $suggested.Right - 212
  $suggested.Top = $suggested.Bottom - 200
  [SlovofonWindowSizing.Native]::SameDpiSuggestedRect($hwnd, $suggested)
  Assert-NormalBounds 'dpi-suggested-small-rect'

  [void][SlovofonWindowSizing.Native]::ShowWindow($hwnd, 6) # SW_MINIMIZE
  Wait-WindowState $true $false
  [SlovofonWindowSizing.Native]::Message($hwnd, 0x001A, [UIntPtr]::new(0x002F), [IntPtr]::Zero) # SPI_SETWORKAREA
  Assert-True ([SlovofonWindowSizing.Native]::IsIconic($hwnd)) 'Work-area notification unexpectedly restored the minimized window.'
  $checks.Add([pscustomobject]@{ Stage = 'minimized-work-area'; Preserved = $true })

  $tiny = $normal
  $tinyRect = $tiny.NormalPosition
  $tinyRect.Right = $tinyRect.Left + 212
  $tinyRect.Bottom = $tinyRect.Top + 200
  $tiny.NormalPosition = $tinyRect
  [SlovofonWindowSizing.Native]::Check([SlovofonWindowSizing.Native]::SetWindowPlacement($hwnd, [ref]$tiny), 'restore tiny placement')
  Assert-NormalBounds 'restore-tiny-placement'

  [void][SlovofonWindowSizing.Native]::ShowWindow($hwnd, 3) # SW_SHOWMAXIMIZED
  Wait-WindowState $false $true
  [SlovofonWindowSizing.Native]::Message($hwnd, 0x001A, [UIntPtr]::new(0x002F), [IntPtr]::Zero)
  Assert-True ([SlovofonWindowSizing.Native]::IsZoomed($hwnd)) 'Work-area notification unexpectedly unmaximized the window.'
  $checks.Add([pscustomobject]@{ Stage = 'maximize-work-area'; Preserved = $true })
  [SlovofonWindowSizing.Native]::Check([SlovofonWindowSizing.Native]::SetWindowPlacement($hwnd, [ref]$tiny), 'restore after maximize')
  Assert-NormalBounds 'restore-after-maximize'

  $monitorArea = [SlovofonWindowSizing.Native]::MonitorArea($hwnd)
  $resolution = ($monitorArea.Width -band 0xffff) -bor (($monitorArea.Height -band 0xffff) -shl 16)
  [SlovofonWindowSizing.Native]::Message($hwnd, 0x007E, [UIntPtr]::new(32), [IntPtr]::new($resolution)) # Same-resolution WM_DISPLAYCHANGE notification, no system mutation.
  Assert-NormalBounds 'display-change-normal'
} finally {
  if ([SlovofonWindowSizing.Native]::IsWindow($hwnd)) {
    [SlovofonWindowSizing.Native]::Check([SlovofonWindowSizing.Native]::SetWindowPlacement($hwnd, [ref]$original), 'restore original placement')
  }
}

$report = [pscustomobject]@{
  ProcessId = $ProcessId
  WindowHandle = $hwnd.ToInt64()
  CoordinateSpace = 'Physical pixels (PER_MONITOR_AWARE_V2 helper thread)'
  Result = 'PASS'
  Checks = $checks.ToArray()
  CoverageNote = 'Actual monitor DPI; synthetic same-DPI/same-resolution messages and normal snap-like rectangles, no system display changes or shell Snap keystrokes. Real shell Snap and cross-monitor transitions remain separate coverage; multi-DPI math has a native test.'
  OriginalPlacementRestored = $true
}
Write-Report $report
} finally {
  $restoredDpiContext = [SlovofonWindowSizing.Native]::SetThreadDpiAwarenessContext($previousDpiContext)
  [SlovofonWindowSizing.Native]::Check($restoredDpiContext -ne [IntPtr]::Zero, 'restore helper thread DPI context')
}
