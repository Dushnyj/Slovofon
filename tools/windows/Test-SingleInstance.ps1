<#
.SYNOPSIS
Tests repeated shortcuts against an already running NEW Slovofon runner.
.DESCRIPTION
Requires its published single-instance marker before launching any process, so
an old build cannot accidentally create a second engine/database. Uses the exact
running executable, launches only brief secondary processes, and restores the
original HWND placement/visibility in finally. Does not kill the app, clear data,
send book links, change settings or start audio. ProcessId must be explicit.
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [ValidateRange(1, 2147483647)]
  [int]$ProcessId,
  [string]$OutputPath
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if (-not ('SlovofonSingleInstanceQa.Native' -as [type])) {
  Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
namespace SlovofonSingleInstanceQa {
  [StructLayout(LayoutKind.Sequential)] public struct Point { public int X, Y; }
  [StructLayout(LayoutKind.Sequential)] public struct Rect { public int L, T, R, B; }
  [StructLayout(LayoutKind.Sequential)] public struct Placement {
    public uint Length, Flags, ShowCmd;
    public Point Min, Max;
    public Rect Normal;
  }
  public static class Native {
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern IntPtr GetProp(IntPtr window, string key);
    [DllImport("user32.dll")] public static extern bool IsWindow(IntPtr window);
    [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr window);
    [DllImport("user32.dll")] public static extern bool IsIconic(IntPtr window);
    [DllImport("user32.dll")] public static extern bool IsZoomed(IntPtr window);
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr window, int command);
    [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr window);
    [DllImport("user32.dll")] public static extern bool AllowSetForegroundWindow(uint process);
    [DllImport("user32.dll")] public static extern bool GetWindowPlacement(IntPtr window, ref Placement placement);
    [DllImport("user32.dll")] public static extern bool SetWindowPlacement(IntPtr window, ref Placement placement);
  }
}
'@
}

$process = Get-Process -Id $ProcessId
$exe = $process.Path
$window = $process.MainWindowHandle
if ([IO.Path]::GetFileName($exe) -cne 'Slovofon.exe') { throw 'Not a Slovofon executable.' }
if (-not [SlovofonSingleInstanceQa.Native]::IsWindow($window)) { throw 'No live main HWND.' }
$sid = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
$marker = [SlovofonSingleInstanceQa.Native]::GetProp($window, "Slovofon.App.InstanceWindow.$sid")
if ($marker -eq [IntPtr]::Zero) { throw 'Runner does not advertise single-instance support; no process launched.' }

$placement = [SlovofonSingleInstanceQa.Placement]::new()
$placement.Length = [Runtime.InteropServices.Marshal]::SizeOf($placement)
if (-not [SlovofonSingleInstanceQa.Native]::GetWindowPlacement($window, [ref]$placement)) { throw 'Cannot snapshot placement.' }
$wasVisible = [SlovofonSingleInstanceQa.Native]::IsWindowVisible($window)
$foreground = [SlovofonSingleInstanceQa.Native]::GetForegroundWindow()
$observations = @()
try {
  foreach ($state in @('visible', 'minimized', 'hidden', 'maximized')) {
    $command = switch ($state) { 'visible' { 9 } 'minimized' { 6 } 'hidden' { 0 } 'maximized' { 3 } }
    [void][SlovofonSingleInstanceQa.Native]::ShowWindow($window, $command)
    Start-Sleep -Milliseconds 200
    # The helper is never displayed; only the existing workspace should show.
    $secondary = Start-Process -FilePath $exe -WorkingDirectory ([IO.Path]::GetDirectoryName($exe)) -WindowStyle Hidden -PassThru
    [void][SlovofonSingleInstanceQa.Native]::AllowSetForegroundWindow([uint32]$secondary.Id)
    if (-not $secondary.WaitForExit(12000)) { throw "Secondary process did not exit: $($secondary.Id). No process was killed." }
    if ($secondary.ExitCode -ne 0) { throw "Secondary launch failed with code $($secondary.ExitCode)." }
    Start-Sleep -Milliseconds 200
    if (-not [SlovofonSingleInstanceQa.Native]::IsWindow($window)) { throw 'Original main HWND changed.' }
    if (-not [SlovofonSingleInstanceQa.Native]::IsWindowVisible($window)) { throw "${state}: original window remains hidden." }
    if ([SlovofonSingleInstanceQa.Native]::IsIconic($window)) { throw "${state}: original window remains minimized." }
    if ($state -eq 'maximized' -and -not [SlovofonSingleInstanceQa.Native]::IsZoomed($window)) { throw 'Maximized state was lost.' }
    $observations += [ordered]@{
      InitialState = $state
      SecondaryExited = $true
      SameWindow = $true
      Visible = $true
      Minimized = $false
      Foreground = [SlovofonSingleInstanceQa.Native]::GetForegroundWindow() -eq $window
    }
  }
} finally {
  if ([SlovofonSingleInstanceQa.Native]::IsWindow($window)) {
    [void][SlovofonSingleInstanceQa.Native]::SetWindowPlacement($window, [ref]$placement)
    if (-not $wasVisible) { [void][SlovofonSingleInstanceQa.Native]::ShowWindow($window, 0) }
  }
  if ([SlovofonSingleInstanceQa.Native]::IsWindow($foreground)) {
    [void][SlovofonSingleInstanceQa.Native]::SetForegroundWindow($foreground)
  }
}

$result = [ordered]@{ ProcessId = $ProcessId; Cases = $observations; UserDataReset = $false }
$json = $result | ConvertTo-Json -Depth 5
if ($OutputPath) {
  $parent = Split-Path -Parent ([IO.Path]::GetFullPath($OutputPath))
  [void](New-Item -ItemType Directory -Path $parent -Force)
  $json | Set-Content -LiteralPath $OutputPath -Encoding utf8
}
$json
