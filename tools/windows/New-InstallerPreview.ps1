[CmdletBinding()]
param([switch]$Light, [string]$InnoCompiler = '')

# A non-installable UI fixture, NOT a release artifact or functional application.
# The compile-time SLOVOFON_QA_PREVIEW guard prevents installation in every mode.
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
if (-not $InnoCompiler) {
    $compiler = Get-Command ISCC.exe -ErrorAction SilentlyContinue
    $InnoCompiler = if ($compiler) { $compiler.Source } else { "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe" }
}
if (-not (Test-Path -LiteralPath $InnoCompiler)) { throw 'Inno Setup 6.6+ is required. No tools were installed.' }
$version = (Get-Content -LiteralPath (Join-Path $root 'VERSION') -Raw).Trim()
$directory = Join-Path $root ("artifacts/installer-preview/" + [Guid]::NewGuid().ToString('N'))
$fixture = Join-Path $directory 'fixture'
New-Item -ItemType Directory -Path $fixture -Force | Out-Null
foreach ($name in @('Slovofon.exe', 'msvcp140.dll', 'vcruntime140.dll', 'vcruntime140_1.dll')) {
    Set-Content -LiteralPath (Join-Path $fixture $name) -Value 'Non-executable UI fixture. Installation is disabled.'
}
$variables = @{
    SLOVOFON_APP_VERSION = $version
    SLOVOFON_SOURCE_DIR = $fixture
    SLOVOFON_OUTPUT_DIR = $directory
    SLOVOFON_OUTPUT_BASE = "Slovofon-v$version-windows-x64-installer-preview"
    SLOVOFON_ICON_PATH = Join-Path $root 'windows/runner/resources/app_icon.ico'
}
$previous = @{}
try {
    foreach ($key in $variables.Keys) {
        $previous[$key] = [Environment]::GetEnvironmentVariable($key, 'Process')
        [Environment]::SetEnvironmentVariable($key, $variables[$key], 'Process')
    }
    $arguments = @('/DSLOVOFON_QA_PREVIEW')
    if ($Light) { $arguments += '/DSLOVOFON_QA_LIGHT' }
    $arguments += Join-Path $root 'installer/windows/inno/Slovofon.iss'
    & $InnoCompiler @arguments
    if ($LASTEXITCODE -ne 0) { throw "Preview compilation failed ($LASTEXITCODE)." }
} finally {
    foreach ($key in $previous.Keys) { [Environment]::SetEnvironmentVariable($key, $previous[$key], 'Process') }
}
Write-Host "Preview only. Installation is disabled. Open manually: $directory/$($variables.SLOVOFON_OUTPUT_BASE).exe"
