[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$BundleDir,
    [string]$OutputDir = '',
    [ValidateSet('All', 'Setup', 'Msi')][string]$Format = 'All',
    [ValidateSet('ru-RU', 'en-US')][string]$Culture = 'ru-RU',
    [string]$InnoCompiler = '',
    [string]$WixCompiler = ''
)

# Packaging only: does not build Flutter, install tools, sign, install/uninstall,
# change VERSION, create tags, push, publish, or overwrite existing release files.
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$version = (Get-Content -LiteralPath (Join-Path $root 'VERSION') -Raw).Trim()
if ($version -notmatch '^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$') { throw 'VERSION must contain MAJOR.MINOR.PATCH.' }
$bundle = (Resolve-Path -LiteralPath $BundleDir).Path
foreach ($entry in @((Get-Item -LiteralPath $bundle)) + @(Get-ChildItem -LiteralPath $bundle -Recurse -Force)) {
    if ($entry.Attributes -band [IO.FileAttributes]::ReparsePoint) {
        throw 'The installer bundle must not contain junctions or symbolic links.'
    }
}
& (Join-Path $PSScriptRoot 'Assert-WindowsRuntime.ps1') -BundleDir $bundle
$exe = Get-Item -LiteralPath (Join-Path $bundle 'Slovofon.exe')
$fileVersion = $exe.VersionInfo
if ($fileVersion.IsDebug) { throw 'A Debug executable is not a release installer payload.' }
if ("$($fileVersion.FileMajorPart).$($fileVersion.FileMinorPart).$($fileVersion.FileBuildPart)" -ne $version) {
    throw 'The Windows bundle version does not match VERSION. Build the current source before packaging.'
}
if (-not $OutputDir) { $OutputDir = Join-Path $root "artifacts/v$version" }
$OutputDir = [IO.Path]::GetFullPath($OutputDir)
if ($OutputDir.Equals($bundle, [StringComparison]::OrdinalIgnoreCase) -or
    $OutputDir.StartsWith($bundle.TrimEnd('\') + '\', [StringComparison]::OrdinalIgnoreCase)) {
    throw 'OutputDir must be outside the application bundle.'
}
$setup = Join-Path $OutputDir "Slovofon-v$version-windows-x64-setup.exe"
$msi = Join-Path $OutputDir "Slovofon-v$version-windows-x64-msi.msi"
$requested = @()
if ($Format -in @('All', 'Setup')) { $requested += $setup }
if ($Format -in @('All', 'Msi')) { $requested += $msi }
foreach ($path in $requested) {
    if (Test-Path -LiteralPath $path) { throw "Refusing to overwrite an existing installer: $path" }
}
function Find-Compiler([string]$ExplicitPath, [string]$Command, [string]$Fallback) {
    if ($ExplicitPath) { return (Resolve-Path -LiteralPath $ExplicitPath).Path }
    $found = Get-Command $Command -ErrorAction SilentlyContinue
    if ($found) { return $found.Source }
    if ($Fallback -and (Test-Path -LiteralPath $Fallback)) { return $Fallback }
    throw "$Command is missing. See docs/BUILD_RELEASE.md; no system tools were installed."
}
if ($Format -in @('All', 'Setup')) {
    $InnoCompiler = Find-Compiler $InnoCompiler 'ISCC.exe' "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe"
}
if ($Format -in @('All', 'Msi')) {
    $WixCompiler = Find-Compiler $WixCompiler 'wix' ''
}
New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null
$iconPath = Join-Path $root 'windows/runner/resources/app_icon.ico'
if ($Format -in @('All', 'Setup')) {
    $variables = @{
        SLOVOFON_APP_VERSION = $version
        SLOVOFON_SOURCE_DIR = $bundle
        SLOVOFON_OUTPUT_DIR = $OutputDir
        SLOVOFON_OUTPUT_BASE = [IO.Path]::GetFileNameWithoutExtension($setup)
        SLOVOFON_ICON_PATH = $iconPath
    }
    $previous = @{}
    try {
        foreach ($key in $variables.Keys) {
            $previous[$key] = [Environment]::GetEnvironmentVariable($key, 'Process')
            [Environment]::SetEnvironmentVariable($key, $variables[$key], 'Process')
        }
        & $InnoCompiler (Join-Path $root 'installer/windows/inno/Slovofon.iss')
        if ($LASTEXITCODE -ne 0) { throw "Inno Setup compilation failed ($LASTEXITCODE)." }
    } finally {
        foreach ($key in $previous.Keys) { [Environment]::SetEnvironmentVariable($key, $previous[$key], 'Process') }
    }
}
if ($Format -in @('All', 'Msi')) {
    $sourcePath = Join-Path $root "build/windows/installer-source/v$version/Slovofon.wxs"
    & (Join-Path $PSScriptRoot 'New-WixInstallerSource.ps1') -SourceDir $bundle `
        -OutputPath $sourcePath -ProductVersion $version -IconPath $iconPath -Culture $Culture
    & $WixCompiler build $sourcePath -arch x64 -ext WixToolset.UI.wixext/6.0.2 `
        -ext WixToolset.Util.wixext/6.0.2 -culture $Culture `
        -loc (Join-Path $root "installer/windows/wix/Slovofon.$Culture.wxl") -out $msi
    if ($LASTEXITCODE -ne 0) { throw "WiX compilation failed ($LASTEXITCODE)." }
    $symbols = [IO.Path]::ChangeExtension($msi, '.wixpdb')
    if (Test-Path -LiteralPath $symbols) { Remove-Item -LiteralPath $symbols }
}
Write-Host "Installers packaged in $OutputDir. Signing, checksums and publication are separate release steps."
