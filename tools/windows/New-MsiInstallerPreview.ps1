[CmdletBinding()]
param(
    [ValidateSet('ru-RU', 'en-US')][string]$Culture = 'ru-RU',
    [string]$WixCompiler = '',
    # Optional project-local .wix/extensions cache. No global installation needed.
    [string]$ExtensionCacheDirectory = '',
    [switch]$GenerateOnly
)

# NON-INSTALLABLE UI fixture, never a release artifact. No app code is executed.
# An unconditional type-19 error stops all execute sequences before costing.
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
if (-not $GenerateOnly) {
    if (-not $WixCompiler) {
        $compiler = Get-Command wix.exe -ErrorAction SilentlyContinue
        if ($compiler) { $WixCompiler = $compiler.Source }
    }
    if (-not $WixCompiler -or -not (Test-Path -LiteralPath $WixCompiler -PathType Leaf)) {
        throw 'WiX 6.0.2 is required. No tools were downloaded or installed.'
    }
    $WixCompiler = (Resolve-Path -LiteralPath $WixCompiler).Path
}
$extensions = @('WixToolset.UI.wixext', 'WixToolset.Util.wixext') | ForEach-Object {
    if ($ExtensionCacheDirectory) {
        (Resolve-Path -LiteralPath (Join-Path $ExtensionCacheDirectory "$_/6.0.2/wixext6/$_.dll")).Path
    } else { "$_/6.0.2" }
}
$version = (Get-Content -LiteralPath (Join-Path $root 'VERSION') -Raw).Trim()
$directory = Join-Path $root ('artifacts/installer-preview/' + [Guid]::NewGuid().ToString('N'))
$fixture = Join-Path $directory 'fixture'
New-Item -ItemType Directory -Path $fixture -Force | Out-Null
# Sufficient headers for the PE import validator, but no sections or executable code.
$bytes = [byte[]]::new(1024)
[BitConverter]::GetBytes([uint16]0x5a4d).CopyTo($bytes, 0)
[BitConverter]::GetBytes([uint32]0x80).CopyTo($bytes, 0x3c)
[BitConverter]::GetBytes([uint32]0x4550).CopyTo($bytes, 0x80)
[BitConverter]::GetBytes([uint16]0x8664).CopyTo($bytes, 0x84)
[BitConverter]::GetBytes([uint16]0xf0).CopyTo($bytes, 0x94)
[BitConverter]::GetBytes([uint16]0x20b).CopyTo($bytes, 0x98)
foreach ($name in @('Slovofon.exe', 'msvcp140.dll', 'vcruntime140.dll', 'vcruntime140_1.dll')) {
    [IO.File]::WriteAllBytes((Join-Path $fixture $name), $bytes)
}
$sourcePath = Join-Path $directory 'Slovofon-preview.wxs'
& (Join-Path $PSScriptRoot 'New-WixInstallerSource.ps1') -SourceDir $fixture `
    -OutputPath $sourcePath -ProductVersion $version -Culture $Culture `
    -UpgradeCode ([Guid]::NewGuid().ToString()) -IconPath (Join-Path $root 'windows/runner/resources/app_icon.ico')

[xml]$document = Get-Content -LiteralPath $sourcePath -Raw
$ns = $document.DocumentElement.NamespaceURI
$package = $document.DocumentElement.SelectSingleNode("*[local-name()='Package']")
# Isolate every identity/search from an existing Slovofon installation.
foreach ($component in $package.SelectNodes(".//*[local-name()='Component']")) {
    $component.SetAttribute('Guid', [Guid]::NewGuid().ToString())
}
foreach ($search in $package.SelectNodes(".//*[local-name()='ComponentSearch']")) {
    $search.SetAttribute('Guid', [Guid]::NewGuid().ToString())
}
foreach ($registry in $package.SelectNodes('.//*[@Key]')) {
    $registry.SetAttribute('Key', $registry.GetAttribute('Key').Replace('Software\Slovofon\', 'Software\SlovofonInstallerPreview\').Replace('{C8CE9579-9F96-40B5-A58C-9726E9F76F89}', '{20E99330-EF3A-46D3-BD7C-D4DE682B52C0}'))
}
$package.SelectSingleNode(".//*[@Id='INSTALLFOLDER' and local-name()='Directory']").SetAttribute('Name', 'SlovofonInstallerPreview')
$guard = $document.CreateElement('CustomAction', $ns)
$guard.SetAttribute('Id', 'BlockPreviewExecution')
$guard.SetAttribute('Error', 'UI preview only. Installation is disabled; no application files or user data were changed.')
[void]$package.AppendChild($guard)
foreach ($sequenceName in @('InstallExecuteSequence', 'AdminExecuteSequence', 'AdvertiseExecuteSequence')) {
    $sequence = $document.CreateElement($sequenceName, $ns)
    $action = $document.CreateElement('Custom', $ns)
    $action.SetAttribute('Action', 'BlockPreviewExecution')
    $action.SetAttribute('Before', 'CostInitialize')
    $action.SetAttribute('Condition', '1')
    [void]$sequence.AppendChild($action)
    [void]$package.AppendChild($sequence)
}
$document.Save($sourcePath)
$msiPath = Join-Path $directory "Slovofon-v$version-windows-x64-msi-preview.msi"
if (-not $GenerateOnly) {
    & $WixCompiler build $sourcePath -arch x64 -ext $extensions[0] -ext $extensions[1] `
        -culture $Culture -loc (Join-Path $root "installer/windows/wix/Slovofon.$Culture.wxl") -out $msiPath
    if ($LASTEXITCODE -ne 0) { throw "MSI preview compilation failed ($LASTEXITCODE)." }
    & (Join-Path $PSScriptRoot 'Test-MsiInstaller.ps1') -MsiPath $msiPath -Preview | Out-Host
}
Write-Host 'Preview only. Installation is disabled. No application was installed or launched.'
[pscustomobject]@{ Directory = $directory; Source = $sourcePath; Msi = $msiPath; Culture = $Culture }
