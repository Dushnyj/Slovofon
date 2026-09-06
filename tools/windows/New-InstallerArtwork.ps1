[CmdletBinding()]
param([string]$OutputDir = (Join-Path $PSScriptRoot '../../installer/windows/assets'))

# Repository-authored geometry. The approved launcher icon is reused unchanged.
# No downloads, font installation, or image-generation service is required.
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$iconPath = Join-Path $PSScriptRoot '../../android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png'
$icon = [Drawing.Image]::FromFile((Resolve-Path -LiteralPath $iconPath).Path)
New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null

function Write-Artwork([string]$Name, [int]$Width, [int]$Height, [string]$Kind) {
    $bitmap = [Drawing.Bitmap]::new($Width, $Height, [Drawing.Imaging.PixelFormat]::Format24bppRgb)
    $graphics = [Drawing.Graphics]::FromImage($bitmap)
    $graphics.SmoothingMode = [Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $graphics.InterpolationMode = [Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $graphics.TextRenderingHint = [Drawing.Text.TextRenderingHint]::AntiAliasGridFit
    $navy = [Drawing.ColorTranslator]::FromHtml('#151C28')
    $accent = [Drawing.ColorTranslator]::FromHtml('#CB8CE1')
    $muted = [Drawing.ColorTranslator]::FromHtml('#344357')
    $brush = [Drawing.SolidBrush]::new($navy)
    $pen = [Drawing.Pen]::new($accent, 3)
    $subtle = [Drawing.Pen]::new($muted, 1)
    $font = [Drawing.Font]::new('Georgia', 26, [Drawing.FontStyle]::Bold, [Drawing.GraphicsUnit]::Pixel)
    $format = [Drawing.StringFormat]::new()
    $format.Alignment = [Drawing.StringAlignment]::Center
    try {
        $graphics.Clear([Drawing.Color]::White)
        if ($Kind -eq 'header') {
            $size = [Math]::Min($Width, $Height) - 8
            $graphics.DrawImage($icon, $Width - $size - 4, 4, $size, $size)
        } else {
            $panel = if ($Kind -eq 'wix') { 164 } else { $Width }
            $graphics.FillRectangle($brush, 0, 0, $panel, $Height)
            $scale = $panel / 328.0
            $graphics.TranslateTransform(0, 0)
            $graphics.ScaleTransform([single]$scale, [single]$scale)
            $canvasHeight = $Height / $scale
            # The sound-wave detail echoes the application's navigation mark.
            for ($i = 0; $i -lt 23; $i++) {
                $x = 32 + $i * 12
                $bar = 12 + 60 * [Math]::Pow([Math]::Sin($i * 0.55), 2)
                $y = $canvasHeight - 110
                $graphics.DrawLine($subtle, [single]$x, [single]($y - $bar), [single]$x, [single]($y + $bar))
            }
            $graphics.DrawImage($icon, 92, 76, 144, 144)
            $graphics.DrawString('Slovofon', $font, [Drawing.Brushes]::White,
                [Drawing.RectangleF]::new(12, 246, 304, 42), $format)
            $graphics.DrawLine($pen, 132, 310, 196, 310)
        }
        $imageFormat = if ($Name.EndsWith('.png')) { [Drawing.Imaging.ImageFormat]::Png } else { [Drawing.Imaging.ImageFormat]::Bmp }
        $bitmap.Save((Join-Path $OutputDir $Name), $imageFormat)
    } finally {
        $format.Dispose(); $font.Dispose(); $subtle.Dispose(); $pen.Dispose()
        $brush.Dispose(); $graphics.Dispose(); $bitmap.Dispose()
    }
}

try {
    Write-Artwork 'inno-sidebar.png' 656 1256 'sidebar'
    Copy-Item -LiteralPath $iconPath -Destination (Join-Path $OutputDir 'app-icon.png') -Force
    Write-Artwork 'wix-dialog.bmp' 493 312 'wix'
    Write-Artwork 'wix-banner.bmp' 493 58 'header'
} finally { $icon.Dispose() }
Write-Host "Installer artwork written to $OutputDir"
