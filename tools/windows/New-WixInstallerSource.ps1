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
    [string]$UpgradeCode = '9C9D9F71-5A2B-4F6D-8C58-9D4C8D2F8B8C'
)

$ErrorActionPreference = 'Stop'

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
& (Join-Path $PSScriptRoot 'Assert-WindowsRuntime.ps1') -BundleDir $resolvedSource.Path
$sourceInfo = Get-Item -LiteralPath $resolvedSource.Path
if (-not $sourceInfo.PSIsContainer) {
    throw "SourceDir is not a directory: $SourceDir"
}

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

$script:Lines.Add('<?xml version="1.0" encoding="UTF-8"?>') | Out-Null
$script:Lines.Add('<Wix xmlns="http://wixtoolset.org/schemas/v4/wxs">') | Out-Null
$script:Lines.Add("  <Package Name=`"$escapedProductName`" Manufacturer=`"$escapedManufacturer`" Version=`"$ProductVersion`" UpgradeCode=`"$UpgradeCode`" Scope=`"perMachine`">") | Out-Null
$script:Lines.Add('    <MajorUpgrade DowngradeErrorMessage="A newer version of Slovofon is already installed." />') | Out-Null
$script:Lines.Add('    <MediaTemplate EmbedCab="yes" />') | Out-Null
$script:Lines.Add("    <Icon Id=`"AppIcon.ico`" SourceFile=`"$escapedIconPath`" />") | Out-Null
$script:Lines.Add('    <Property Id="ARPPRODUCTICON" Value="AppIcon.ico" />') | Out-Null
$script:Lines.Add('    <StandardDirectory Id="ProgramFiles64Folder">') | Out-Null
$script:Lines.Add('      <Directory Id="INSTALLFOLDER" Name="Slovofon">') | Out-Null
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
$script:Lines.Add('          <Shortcut Id="ApplicationStartMenuShortcut" Name="Slovofon" Description="Slovofon" Target="[INSTALLFOLDER]Slovofon.exe" WorkingDirectory="INSTALLFOLDER" />') | Out-Null
$script:Lines.Add('          <RemoveFolder Id="ApplicationProgramsFolder" On="uninstall" />') | Out-Null
$script:Lines.Add('          <RegistryValue Root="HKLM" Key="Software\Slovofon\Slovofon" Name="StartMenuShortcut" Type="integer" Value="1" KeyPath="yes" />') | Out-Null
$script:Lines.Add('        </Component>') | Out-Null
$script:Lines.Add('      </Directory>') | Out-Null
$script:Lines.Add('    </StandardDirectory>') | Out-Null
$script:Lines.Add('    <Feature Id="MainFeature" Title="Slovofon" Level="1">') | Out-Null
foreach ($componentId in $componentRefs) {
    $script:Lines.Add("      <ComponentRef Id=`"$componentId`" />") | Out-Null
}
$script:Lines.Add('      <ComponentRef Id="cmp_StartMenuShortcut" />') | Out-Null
$script:Lines.Add('    </Feature>') | Out-Null
$script:Lines.Add('  </Package>') | Out-Null
$script:Lines.Add('</Wix>') | Out-Null

$outputDirectory = Split-Path -Parent $OutputPath
if (-not [string]::IsNullOrWhiteSpace($outputDirectory)) {
    New-Item -ItemType Directory -Force $outputDirectory | Out-Null
}
$script:Lines | Set-Content -LiteralPath $OutputPath -Encoding utf8
Write-Host "WiX source written to $OutputPath"
