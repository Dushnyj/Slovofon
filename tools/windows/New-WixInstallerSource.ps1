param(
    [Parameter(Mandatory = $true)]
    [string]$SourceDir,

    [Parameter(Mandatory = $true)]
    [string]$OutputPath,

    [Parameter(Mandatory = $true)]
    [string]$ProductVersion,

    [string]$ProductName = 'Slovofon',
    [string]$Manufacturer = 'Slovofon Team',
    [string]$IconPath = '',
    [ValidateSet('ru-RU', 'en-US')]
    [string]$Culture = 'ru-RU',
    [string]$UpgradeCode = '9C9D9F71-5A2B-4F6D-8C58-9D4C8D2F8B8C'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

# Windows Installer compares three numeric fields only. Reject truncation and XML
# injection rather than silently publishing a package with another identity.
if ($ProductVersion -notmatch '^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$') {
    throw 'ProductVersion must be a three-part numeric MSI version.'
}
$versionParts = $ProductVersion.Split('.')
if ([long]$versionParts[0] -gt 255 -or [long]$versionParts[1] -gt 255 -or [long]$versionParts[2] -gt 65535) {
    throw 'ProductVersion exceeds MSI limits: 255.255.65535.'
}
$UpgradeCode = ([Guid]::Parse($UpgradeCode)).ToString().ToUpperInvariant()

function Assert-NoReparsePoints {
    param([System.IO.FileSystemInfo]$Entry)
    if (($Entry.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
        throw "Reparse points are not allowed in the installer bundle: $($Entry.FullName)"
    }
    if ($Entry -is [IO.DirectoryInfo]) {
        foreach ($child in Get-ChildItem -LiteralPath $Entry.FullName -Force) {
            Assert-NoReparsePoints -Entry $child
        }
    }
}

function ConvertTo-WixId {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Prefix,

        [Parameter(Mandatory = $true)]
        [string]$Value
    )

    $hash = [System.Security.Cryptography.SHA1]::HashData(
        [System.Text.Encoding]::UTF8.GetBytes($Value)
    )
    $hashText = -join ($hash | ForEach-Object { $_.ToString('x2') })
    $safe = ($Value -replace '[^A-Za-z0-9_]', '_').Trim('_')
    if ([string]::IsNullOrWhiteSpace($safe)) {
        $safe = $hashText.Substring(0, 12)
    }
    if ($safe.Length -gt 44) {
        $safe = $safe.Substring(0, 44)
    }
    return "${Prefix}_${safe}_$($hashText.Substring(0, 12))"
}

function New-StableGuid {
    param([Parameter(Mandatory = $true)][string]$Value)

    $bytes = [System.Security.Cryptography.MD5]::HashData(
        [System.Text.Encoding]::UTF8.GetBytes("Slovofon-WiX:$Value")
    )
    $bytes[6] = ($bytes[6] -band 0x0f) -bor 0x30
    $bytes[8] = ($bytes[8] -band 0x3f) -bor 0x80
    return ([Guid]::new($bytes)).ToString().ToUpperInvariant()
}

function Escape-Xml {
    param([string]$Value)
    return [System.Security.SecurityElement]::Escape($Value)
}

function Get-RelativePath {
    param(
        [Parameter(Mandatory = $true)][string]$BasePath,
        [Parameter(Mandatory = $true)][string]$Path
    )
    return [System.IO.Path]::GetRelativePath($BasePath, $Path).Replace('\', '/')
}

function Write-DirectoryElement {
    param(
        [Parameter(Mandatory = $true)][System.IO.DirectoryInfo]$Directory,
        [Parameter(Mandatory = $true)][string]$DirectoryId,
        [Parameter(Mandatory = $true)][string]$BasePath,
        [Parameter(Mandatory = $true)][int]$Indent,
        [System.Collections.Generic.List[string]]$ComponentRefs
    )

    $pad = ' ' * $Indent
    $childPad = ' ' * ($Indent + 2)

    foreach ($file in Get-ChildItem -LiteralPath $Directory.FullName -File | Sort-Object Name) {
        if ($file.Extension -eq '.pdb') {
            continue
        }
        $relative = Get-RelativePath -BasePath $BasePath -Path $file.FullName
        $componentId = ConvertTo-WixId -Prefix 'cmp' -Value $relative
        $fileId = ConvertTo-WixId -Prefix 'fil' -Value $relative
        $guid = New-StableGuid -Value $relative
        $ComponentRefs.Add($componentId) | Out-Null
        $source = Escape-Xml -Value $file.FullName
        $script:Lines.Add("$childPad<Component Id=`"$componentId`" Guid=`"$guid`">") | Out-Null
        $script:Lines.Add("$childPad  <File Id=`"$fileId`" Source=`"$source`" KeyPath=`"yes`" />") | Out-Null
        $script:Lines.Add("$childPad</Component>") | Out-Null
    }

    foreach ($child in Get-ChildItem -LiteralPath $Directory.FullName -Directory | Sort-Object Name) {
        $relative = Get-RelativePath -BasePath $BasePath -Path $child.FullName
        $childId = ConvertTo-WixId -Prefix 'dir' -Value $relative
        $childName = Escape-Xml -Value $child.Name
        $script:Lines.Add("$childPad<Directory Id=`"$childId`" Name=`"$childName`">") | Out-Null
        Write-DirectoryElement `
            -Directory $child `
            -DirectoryId $childId `
            -BasePath $BasePath `
            -Indent ($Indent + 2) `
            -ComponentRefs $ComponentRefs
        $script:Lines.Add("$childPad</Directory>") | Out-Null
    }
}

$resolvedSource = Resolve-Path -LiteralPath $SourceDir
$sourceInfo = Get-Item -LiteralPath $resolvedSource.Path
if (-not $sourceInfo.PSIsContainer) {
    throw "SourceDir is not a directory: $SourceDir"
}
Assert-NoReparsePoints -Entry $sourceInfo
$OutputPath = [IO.Path]::GetFullPath($OutputPath)
if ($OutputPath.StartsWith($sourceInfo.FullName.TrimEnd('\') + '\', [StringComparison]::OrdinalIgnoreCase)) {
    throw 'OutputPath must be outside SourceDir to avoid harvesting generated installer files.'
}
& (Join-Path $PSScriptRoot 'Assert-WindowsRuntime.ps1') -BundleDir $resolvedSource.Path

$exePath = Join-Path $sourceInfo.FullName 'Slovofon.exe'
if (-not (Test-Path -LiteralPath $exePath)) {
    throw "Slovofon.exe was not found in $($sourceInfo.FullName)"
}

if ([string]::IsNullOrWhiteSpace($IconPath)) {
    $IconPath = $exePath
}
$resolvedIcon = Resolve-Path -LiteralPath $IconPath

$componentRefs = [System.Collections.Generic.List[string]]::new()
$script:Lines = [System.Collections.Generic.List[string]]::new()
$escapedProductName = Escape-Xml -Value $ProductName
$escapedManufacturer = Escape-Xml -Value $Manufacturer
$escapedIconPath = Escape-Xml -Value $resolvedIcon.Path
$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$uiDirectory = Join-Path $repoRoot 'installer/windows/wix'
$outputDirectory = Split-Path -Parent $OutputPath
New-Item -ItemType Directory -Force $outputDirectory | Out-Null
# Generate an RTF from our checked-in license, not WiX's sample license.
$licenseText = Get-Content -LiteralPath (Join-Path $repoRoot 'LICENSE') -Raw
$rtfText = $licenseText.Replace('\', '\\').Replace('{', '\{').Replace('}', '\}').Replace("`r", '').Replace("`n", '\par ')
$licensePath = Join-Path $outputDirectory 'Slovofon-license.rtf'
('{\rtf1\ansi\deff0{\fonttbl{\f0 Segoe UI;}}\f0\fs18 ' + $rtfText + '}') | Set-Content -LiteralPath $licensePath -Encoding ascii
$productCode = New-StableGuid -Value "Product:$UpgradeCode`:$ProductVersion"

$script:Lines.Add('<?xml version="1.0" encoding="UTF-8"?>') | Out-Null
$script:Lines.Add('<Wix xmlns="http://wixtoolset.org/schemas/v4/wxs" xmlns:ui="http://wixtoolset.org/schemas/v4/wxs/ui">') | Out-Null
$script:Lines.Add("  <Package Name=`"$escapedProductName`" Manufacturer=`"$escapedManufacturer`" Version=`"$ProductVersion`" ProductCode=`"$productCode`" UpgradeCode=`"$UpgradeCode`" Language=`"!(loc.ProductLanguage)`" Codepage=`"!(loc.Codepage)`" Scope=`"perMachine`" InstallerVersion=`"500`">") | Out-Null
$script:Lines.Add('    <MajorUpgrade Schedule="afterInstallInitialize" IgnoreLanguage="yes" DowngradeErrorMessage="!(loc.NewerVersionInstalled)" />') | Out-Null
# VersionNT is deliberately 603 even on Windows 10/11; use the OS build instead.
$script:Lines.Add('    <Property Id="WINDOWSBUILDNUMBER" Secure="yes"><RegistrySearch Id="WindowsBuild" Root="HKLM" Key="Software\Microsoft\Windows NT\CurrentVersion" Name="CurrentBuildNumber" Type="raw" Bitness="always64" /></Property>') | Out-Null
$script:Lines.Add('    <Launch Condition="Installed OR (VersionNT64 AND WINDOWSBUILDNUMBER &gt;= 10240)" Message="!(loc.WindowsRequired)" />') | Out-Null
$script:Lines.Add('    <Launch Condition="Installed OR (NOT INNO_USER_INSTALL AND NOT INNO_MACHINE_INSTALL)" Message="!(loc.ExeAlreadyInstalled)" />') | Out-Null
foreach ($scope in @(@('USER', 'HKCU'), @('MACHINE', 'HKLM'))) {
    $script:Lines.Add("    <Property Id=`"INNO_$($scope[0])_INSTALL`" Secure=`"yes`"><RegistrySearch Id=`"FindInno$($scope[0])`" Root=`"$($scope[1])`" Key=`"Software\Microsoft\Windows\CurrentVersion\Uninstall\{C8CE9579-9F96-40B5-A58C-9726E9F76F89}_is1`" Name=`"UninstallString`" Type=`"raw`" Bitness=`"always64`" /></Property>") | Out-Null
}
$script:Lines.Add('    <Property Id="INSTALLFOLDER" Secure="yes" />') | Out-Null
$script:Lines.Add('    <Property Id="PREVIOUSMSILOCATION" Secure="yes"><RegistrySearch Id="PreviousMsiLocation" Root="HKLM" Key="Software\Slovofon\Installer" Name="InstallLocation" Type="raw" Bitness="always64" /></Property>') | Out-Null
# Older MSI packages predate the marker but already have a stable EXE component.
$legacyExeComponent = New-StableGuid -Value 'Slovofon.exe'
$script:Lines.Add("    <Property Id=`"PREVIOUSMSIFOLDER`" Secure=`"yes`"><ComponentSearch Id=`"PreviousMsiExe`" Guid=`"$legacyExeComponent`" Type=`"file`" /></Property>") | Out-Null
$script:Lines.Add('    <SetProperty Id="INSTALLFOLDER" Action="RestoreMsiInstallLocation" Value="[PREVIOUSMSILOCATION]" Before="CostInitialize" Sequence="both" Condition="PREVIOUSMSILOCATION AND NOT INSTALLFOLDER" />') | Out-Null
$script:Lines.Add('    <SetProperty Id="INSTALLFOLDER" Action="RestoreLegacyMsiInstallLocation" Value="[PREVIOUSMSIFOLDER]" Before="CostInitialize" Sequence="both" Condition="PREVIOUSMSIFOLDER AND NOT PREVIOUSMSILOCATION AND NOT INSTALLFOLDER" />') | Out-Null
$script:Lines.Add('    <Property Id="DESKTOPSHORTCUT" Secure="yes" />') | Out-Null
$script:Lines.Add('    <Property Id="PREVIOUSDESKTOPSHORTCUT" Secure="yes"><RegistrySearch Id="PreviousDesktopShortcut" Root="HKLM" Key="Software\Slovofon\Installer" Name="DesktopShortcut" Type="raw" Bitness="always64" /></Property>') | Out-Null
$script:Lines.Add('    <SetProperty Id="DESKTOPSHORTCUT" Value="[PREVIOUSDESKTOPSHORTCUT]" Before="CostInitialize" Sequence="first" Condition="PREVIOUSDESKTOPSHORTCUT AND NOT DESKTOPSHORTCUT" />') | Out-Null
$script:Lines.Add('    <MediaTemplate EmbedCab="yes" />') | Out-Null
$script:Lines.Add("    <Icon Id=`"AppIcon.ico`" SourceFile=`"$escapedIconPath`" />") | Out-Null
$script:Lines.Add('    <Property Id="ARPPRODUCTICON" Value="AppIcon.ico" />') | Out-Null
$script:Lines.Add('    <Property Id="ARPHELPLINK" Value="https://github.com/Dushnyj/Slovofon/issues" />') | Out-Null
$script:Lines.Add('    <Property Id="ARPURLINFOABOUT" Value="https://github.com/Dushnyj/Slovofon" />') | Out-Null
$script:Lines.Add('    <Property Id="ARPURLUPDATEINFO" Value="https://github.com/Dushnyj/Slovofon/releases" />') | Out-Null
$script:Lines.Add('    <SetProperty Id="ARPINSTALLLOCATION" Value="[INSTALLFOLDER]" After="CostFinalize" Sequence="execute" />') | Out-Null
$script:Lines.Add('    <Property Id="ARPNOMODIFY" Value="1" />') | Out-Null
$script:Lines.Add('    <Property Id="REBOOT" Value="ReallySuppress" />') | Out-Null
$script:Lines.Add('    <Property Id="WIXUI_EXITDIALOGOPTIONALCHECKBOXTEXT" Value="!(loc.LaunchApplication)" />') | Out-Null
$script:Lines.Add('    <Property Id="WIXUI_EXITDIALOGOPTIONALTEXT" Value="!(loc.FinishDetails)" />') | Out-Null
# Resolve the final, user-selected folder on Finish, not in the Property table
# or before the destination dialog. Type 51 formats this value at action time.
$script:Lines.Add('    <CustomAction Id="SetSlovofonLaunchTarget" Property="WixUnelevatedShellExecTarget" Value="[INSTALLFOLDER]Slovofon.exe" />') | Out-Null
$script:Lines.Add('    <CustomAction Id="LaunchSlovofon" BinaryRef="Wix4UtilCA_X64" DllEntry="WixUnelevatedShellExec" Execute="immediate" Impersonate="yes" Return="ignore" />') | Out-Null
$script:Lines.Add("    <WixVariable Id=`"WixUILicenseRtf`" Value=`"$(Escape-Xml $licensePath)`" />") | Out-Null
foreach ($asset in @(@('WixUIBannerBmp', 'wix-banner.bmp'), @('WixUIDialogBmp', 'wix-dialog.bmp'))) {
    $assetPath = Escape-Xml (Join-Path $repoRoot "installer/windows/assets/$($asset[1])")
    $script:Lines.Add("    <WixVariable Id=`"$($asset[0])`" Value=`"$assetPath`" />") | Out-Null
}
$script:Lines.Add('    <ui:WixUI Id="WixUI_Common" />') | Out-Null
$script:Lines.Add('    <UIRef Id="WixUI_ErrorProgressText" />') | Out-Null
$script:Lines.Add("    <?include `"$(Join-Path $uiDirectory 'SlovofonUI.wxi')`" ?>") | Out-Null
$script:Lines.Add('    <StandardDirectory Id="ProgramFiles64Folder">') | Out-Null
$script:Lines.Add('      <Directory Id="INSTALLFOLDER" Name="Slovofon">') | Out-Null
$script:Lines.Add('        <Component Id="cmp_InstallerMetadata" Guid="8E0B39D1-0802-46B2-85F7-5337734C25F9" Bitness="always64">') | Out-Null
$script:Lines.Add('          <RegistryKey Root="HKLM" Key="Software\Slovofon\Installer">') | Out-Null
$script:Lines.Add('            <RegistryValue Name="Type" Type="string" Value="msi" KeyPath="yes" />') | Out-Null
$script:Lines.Add('            <RegistryValue Name="InstallLocation" Type="string" Value="[INSTALLFOLDER]" />') | Out-Null
$script:Lines.Add('            <RegistryValue Name="Version" Type="string" Value="[ProductVersion]" />') | Out-Null
$script:Lines.Add('            <RegistryValue Name="ProductCode" Type="string" Value="[ProductCode]" />') | Out-Null
$script:Lines.Add('          </RegistryKey>') | Out-Null
$script:Lines.Add('        </Component>') | Out-Null
Write-DirectoryElement `
    -Directory $sourceInfo `
    -DirectoryId 'INSTALLFOLDER' `
    -BasePath $sourceInfo.FullName `
    -Indent 6 `
    -ComponentRefs $componentRefs
$script:Lines.Add('      </Directory>') | Out-Null
$script:Lines.Add('    </StandardDirectory>') | Out-Null
$script:Lines.Add('    <StandardDirectory Id="ProgramMenuFolder">') | Out-Null
$script:Lines.Add('      <Directory Id="ApplicationProgramsFolder" Name="Slovofon">') | Out-Null
$script:Lines.Add('        <Component Id="cmp_StartMenuShortcut" Guid="78F289D7-49C7-4B3B-9D4D-22A89B7B23C2">') | Out-Null
$script:Lines.Add('          <Shortcut Id="ApplicationStartMenuShortcut" Name="Slovofon" Description="Slovofon" Target="[INSTALLFOLDER]Slovofon.exe" WorkingDirectory="INSTALLFOLDER" Icon="AppIcon.ico"><ShortcutProperty Key="System.AppUserModel.ID" Value="Slovofon.App" /></Shortcut>') | Out-Null
$script:Lines.Add('          <RemoveFolder Id="ApplicationProgramsFolder" On="uninstall" />') | Out-Null
$script:Lines.Add('          <RegistryValue Root="HKLM" Key="Software\Slovofon\Slovofon" Name="StartMenuShortcut" Type="integer" Value="1" KeyPath="yes" />') | Out-Null
$script:Lines.Add('        </Component>') | Out-Null
$script:Lines.Add('      </Directory>') | Out-Null
$script:Lines.Add('    </StandardDirectory>') | Out-Null
$script:Lines.Add('    <StandardDirectory Id="DesktopFolder">') | Out-Null
$script:Lines.Add('      <Component Id="cmp_DesktopShortcut" Guid="46EC7AF7-335D-41DA-9B7F-5BD3C1D6F973" Bitness="always64">') | Out-Null
$script:Lines.Add('        <Shortcut Id="DesktopShortcut" Name="Slovofon" Target="[INSTALLFOLDER]Slovofon.exe" WorkingDirectory="INSTALLFOLDER" Icon="AppIcon.ico"><ShortcutProperty Key="System.AppUserModel.ID" Value="Slovofon.App" /></Shortcut>') | Out-Null
$script:Lines.Add('        <RegistryValue Root="HKLM" Key="Software\Slovofon\Installer" Name="DesktopShortcut" Type="string" Value="1" KeyPath="yes" />') | Out-Null
$script:Lines.Add('      </Component>') | Out-Null
$script:Lines.Add('    </StandardDirectory>') | Out-Null
$script:Lines.Add('    <Feature Id="MainFeature" Title="Slovofon" Level="1">') | Out-Null
foreach ($componentId in $componentRefs) {
    $script:Lines.Add("      <ComponentRef Id=`"$componentId`" />") | Out-Null
}
$script:Lines.Add('      <ComponentRef Id="cmp_StartMenuShortcut" />') | Out-Null
$script:Lines.Add('      <ComponentRef Id="cmp_InstallerMetadata" />') | Out-Null
$script:Lines.Add('    </Feature>') | Out-Null
$script:Lines.Add('    <Feature Id="DesktopFeature" Title="!(loc.DesktopShortcut)" Level="200" Display="hidden" AllowAdvertise="no">') | Out-Null
$script:Lines.Add('      <Level Value="1" Condition="DESKTOPSHORTCUT = &quot;1&quot;" />') | Out-Null
$script:Lines.Add('      <ComponentRef Id="cmp_DesktopShortcut" />') | Out-Null
$script:Lines.Add('    </Feature>') | Out-Null
$script:Lines.Add('  </Package>') | Out-Null
$script:Lines.Add('</Wix>') | Out-Null

$outputDirectory = Split-Path -Parent $OutputPath
if (-not [string]::IsNullOrWhiteSpace($outputDirectory)) {
    New-Item -ItemType Directory -Force $outputDirectory | Out-Null
}
$script:Lines | Set-Content -LiteralPath $OutputPath -Encoding utf8
Write-Host "WiX source written to $OutputPath"
Write-Host "Build with WiX 6.0.2, -ext WixToolset.UI.wixext -ext WixToolset.Util.wixext -culture $Culture -loc `"$(Join-Path $uiDirectory "Slovofon.$Culture.wxl")`" -arch x64"
