# Native banner composition resamples the approved master for TV densities and
# uses outlined localized product names. No alternate concept or font dependency
# at runtime. 160x90 dp is the Android TV 320x180 px xhdpi banner specification.
# https://developer.android.com/training/tv/get-started/create
[CmdletBinding()]
param([switch]$Check)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$root = Split-Path -Parent $PSScriptRoot
$culture = [Globalization.CultureInfo]::InvariantCulture

# Drawing the 1254px master directly into a 64dp launcher layer with Android's
# bilinear filter undersamples thin rings/lines. Prefilter once, offline, at
# each density; runtime only performs a small final scale. Phone assets remain
# byte-identical to their approved master and are not touched here.
$masterPath = Join-Path (Split-Path -Parent $root) 'assets/app/slovofon_icon.png'
$master = [Drawing.Bitmap]::FromFile($masterPath)
try {
    if ($master.Width -ne 1254 -or $master.Height -ne 1254) {
        throw 'TV banner expects the approved 1254x1254 emblem master.'
    }
    foreach ($density in @(
        @{Name='mdpi';Size=64}, @{Name='hdpi';Size=96},
        @{Name='xhdpi';Size=128}, @{Name='xxhdpi';Size=192},
        @{Name='xxxhdpi';Size=256}
    )) {
        $bitmap = [Drawing.Bitmap]::new($density.Size, $density.Size, [Drawing.Imaging.PixelFormat]::Format32bppArgb)
        $graphics = [Drawing.Graphics]::FromImage($bitmap)
        $attributes = [Drawing.Imaging.ImageAttributes]::new()
        $stream = [IO.MemoryStream]::new()
        try {
            $graphics.CompositingMode = [Drawing.Drawing2D.CompositingMode]::SourceCopy
            $graphics.CompositingQuality = [Drawing.Drawing2D.CompositingQuality]::HighQuality
            $graphics.InterpolationMode = [Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
            $graphics.PixelOffsetMode = [Drawing.Drawing2D.PixelOffsetMode]::HighQuality
            $attributes.SetWrapMode([Drawing.Drawing2D.WrapMode]::TileFlipXY)
            $graphics.DrawImage($master, [Drawing.Rectangle]::new(0, 0, $density.Size, $density.Size),
                0, 0, $master.Width, $master.Height, [Drawing.GraphicsUnit]::Pixel, $attributes)
            $bitmap.Save($stream, [Drawing.Imaging.ImageFormat]::Png)
            $bytes = $stream.ToArray()
            $directory = Join-Path $root "app/src/main/res/drawable-$($density.Name)"
            $file = Join-Path $directory 'tv_launcher_emblem.png'
            if ($Check) {
                if (-not (Test-Path -LiteralPath $file) -or
                    [Convert]::ToBase64String([IO.File]::ReadAllBytes($file)) -cne [Convert]::ToBase64String($bytes)) {
                    throw "Stale TV emblem: $($density.Name)"
                }
            } else {
                New-Item -ItemType Directory -Force $directory | Out-Null
                [IO.File]::WriteAllBytes($file, $bytes)
            }
        } finally { $stream.Dispose(); $attributes.Dispose(); $graphics.Dispose(); $bitmap.Dispose() }
    }
} finally { $master.Dispose() }

function Number([single]$value) { $value.ToString('0.###', $culture) }
function Point($point) { (Number $point.X) + ',' + (Number $point.Y) }
function Wordmark([string]$name) {
    $font = [Drawing.FontFamily]::new('Segoe UI')
    $path = [Drawing.Drawing2D.GraphicsPath]::new()
    try {
        $path.AddString($name, $font, [int][Drawing.FontStyle]::Bold, 36, [Drawing.PointF]::new(0,0), [Drawing.StringFormat]::GenericTypographic)
        $bounds = $path.GetBounds()
        if ($bounds.Width -gt 160) {
            $scale = [Drawing.Drawing2D.Matrix]::new()
            try { $scale.Scale(160 / $bounds.Width, 160 / $bounds.Width); $path.Transform($scale) } finally { $scale.Dispose() }
            $bounds = $path.GetBounds()
        }
        $move = [Drawing.Drawing2D.Matrix]::new()
        try { $move.Translate(140 - $bounds.X, 90 - $bounds.Height / 2 - $bounds.Y); $path.Transform($move) } finally { $move.Dispose() }
        $points = $path.PathPoints
        $types = $path.PathTypes
        $result = [Text.StringBuilder]::new()
        for ($i = 0; $i -lt $points.Length; $i++) {
            switch ($types[$i] -band 7) {
                0 { [void]$result.Append('M' + (Point $points[$i])) }
                1 { [void]$result.Append('L' + (Point $points[$i])) }
                3 {
                    [void]$result.Append('C' + (Point $points[$i]) + ' ' + (Point $points[$i+1]) + ' ' + (Point $points[$i+2]))
                    $i += 2
                }
                default { throw 'Unexpected glyph outline segment' }
            }
            if (($types[$i] -band 128) -ne 0) { [void]$result.Append('Z') }
        }
        return $result.ToString()
    } finally { $path.Dispose(); $font.Dispose() }
}
foreach ($variant in @(
    @{Folder='drawable';Name='Slovofon';Fractional=$false},
    @{Folder='drawable-ru';Name='Словофон';Fractional=$false},
    @{Folder='drawable-v26';Name='Slovofon';Fractional=$true},
    @{Folder='drawable-ru-v26';Name='Словофон';Fractional=$true}
)) {
    $wordmark = Wordmark $variant.Name
    # Fractional InsetDrawable values require API 26. Keep a dp-positioned
    # fallback for API 24-25 rather than crashing while inflating the TV banner.
    $emblemLayer = if ($variant.Fractional) {
@'
    <item android:width="160dp" android:height="90dp" android:gravity="fill">
        <!-- Fractional bounds keep the emblem proportional at any launcher size. -->
        <inset android:insetLeft="2.5%" android:insetRight="57.5%"
            android:insetTop="14.444444%" android:insetBottom="14.444444%">
            <bitmap android:src="@drawable/tv_launcher_emblem"
                android:gravity="fill" android:filter="true" />
        </inset>
    </item>
'@
    } else {
@'
    <!-- API 24-25 fallback; no fractional InsetDrawable on these Android versions. -->
    <item android:width="64dp" android:height="64dp"
        android:left="4dp" android:gravity="left|center_vertical">
        <bitmap android:src="@drawable/tv_launcher_emblem"
            android:gravity="fill" android:filter="true" />
    </item>
'@
    }
    $xml = @"
<?xml version="1.0" encoding="utf-8"?>
<!-- Generated by android/tools/Generate-TvBanner.ps1. Product name: $($variant.Name).
     Emblem: TV-only high-quality density resampling of assets/app/slovofon_icon.png.
     Phone master and approved emblem geometry remain unchanged.
     Intrinsic 160x90 dp = 320x180 px at xhdpi, 640x360 px at xxxhdpi.
     Explicit layer dimensions preserve banner aspect independently of bitmap density. -->
<layer-list xmlns:android="http://schemas.android.com/apk/res/android" android:paddingMode="stack">
    <item android:width="160dp" android:height="90dp" android:gravity="fill">
        <vector android:width="160dp" android:height="90dp"
            android:viewportWidth="320" android:viewportHeight="180">
            <path android:fillColor="#071F32" android:pathData="M0,0H320V180H0Z" />
            <path android:fillColor="#F8FAFC" android:pathData="$wordmark" />
        </vector>
    </item>
$emblemLayer
</layer-list>
"@
    $directory = Join-Path $root "app/src/main/res/$($variant.Folder)"
    $file = Join-Path $directory 'tv_banner.xml'
    $xml = $xml.Replace("`r`n", "`n").TrimEnd() + "`n"
    if ($Check) {
        if (-not (Test-Path -LiteralPath $file) -or
            [IO.File]::ReadAllText($file).Replace("`r`n", "`n") -cne $xml) {
            throw "Stale TV banner: $($variant.Folder)"
        }
    } else {
        New-Item -ItemType Directory -Force $directory | Out-Null
        [IO.File]::WriteAllText($file, $xml, [Text.UTF8Encoding]::new($false))
    }
}
