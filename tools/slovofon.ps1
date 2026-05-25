[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [ValidateSet('bootstrap', 'check', 'doctor', 'get', 'format', 'analyze', 'test', 'build', 'version', 'release', 'clean')]
    [string]$Command = 'check',

    [ValidateSet('android', 'windows', 'all')]
    [string]$Target = 'all',

    [ValidateSet('debug', 'profile', 'release')]
    [string]$Configuration = 'debug',

    [string]$Set,
    [string]$Version,
    [int]$BuildNumber = 0
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$Script:Root = Resolve-Path (Join-Path $PSScriptRoot '..')
$Script:Failures = New-Object System.Collections.Generic.List[string]

function Write-Info {
    param([string]$Message)
    Write-Host "[slovofon] $Message"
}

function Write-Check {
    param(
        [string]$Name,
        [bool]$Ok,
        [string]$Detail,
        [switch]$Optional
    )

    $status = if ($Ok) { 'OK' } elseif ($Optional) { 'WARN' } else { 'FAIL' }
    Write-Host ("[{0}] {1} - {2}" -f $status, $Name, $Detail)

    if (-not $Ok -and -not $Optional) {
        $Script:Failures.Add($Name) | Out-Null
    }
}

function Get-Tool {
    param([string]$Name)
    Get-Command $Name -ErrorAction SilentlyContinue
}

function Test-Tool {
    param(
        [string]$Name,
        [switch]$Optional
    )

    $tool = Get-Tool $Name
    Write-Check -Name $Name -Ok ($null -ne $tool) -Detail $(if ($tool) { $tool.Source } else { 'not found in PATH' }) -Optional:$Optional
    return $tool
}

function Require-Tool {
    param([string]$Name)

    $tool = Get-Tool $Name
    if ($null -eq $tool) {
        throw "$Name is not available in PATH. Install it or add it to PATH, then rerun this command."
    }

    return $tool.Source
}

function Invoke-Tool {
    param(
        [string]$Executable,
        [string[]]$Arguments
    )

    Write-Info ("running: {0} {1}" -f $Executable, ($Arguments -join ' '))
    & $Executable @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "Command failed with exit code $($LASTEXITCODE): $Executable $($Arguments -join ' ')"
    }
}

function Get-PublicVersion {
    $versionPath = Join-Path $Script:Root 'VERSION'
    if (-not (Test-Path $versionPath)) {
        throw 'VERSION file is missing.'
    }

    return (Get-Content -Raw $versionPath).Trim()
}

function Get-PubspecVersion {
    $pubspecPath = Join-Path $Script:Root 'pubspec.yaml'
    if (-not (Test-Path $pubspecPath)) {
        return $null
    }

    $match = Select-String -Path $pubspecPath -Pattern '^version:\s*(.+)$' | Select-Object -First 1
    if ($null -eq $match) {
        return $null
    }

    return $match.Matches[0].Groups[1].Value.Trim()
}

function Show-Version {
    $publicVersion = Get-PublicVersion
    $pubspecVersion = Get-PubspecVersion

    Write-Host "VERSION: $publicVersion"
    if ($pubspecVersion) {
        Write-Host "pubspec.yaml: $pubspecVersion"
    } else {
        Write-Host 'pubspec.yaml: missing or no version field'
    }
}

function Set-Version {
    param(
        [string]$NewVersion,
        [int]$NewBuildNumber
    )

    if ($NewVersion -notmatch '^\d+\.\d+\.\d+$') {
        throw "Version must be SemVer MAJOR.MINOR.PATCH, got '$NewVersion'."
    }

    if ($NewVersion -match '^1\.') {
        throw 'Bumping to 1.x.x requires explicit owner confirmation outside this script.'
    }

    if ($NewBuildNumber -le 0) {
        $currentPubspecVersion = Get-PubspecVersion
        if ($currentPubspecVersion -and $currentPubspecVersion -match '\+(\d+)$') {
            $NewBuildNumber = [int]$Matches[1]
        } else {
            $NewBuildNumber = 1
        }
    }

    Set-Content -Path (Join-Path $Script:Root 'VERSION') -Value $NewVersion -NoNewline

    $pubspecPath = Join-Path $Script:Root 'pubspec.yaml'
    if (Test-Path $pubspecPath) {
        $content = Get-Content -Raw $pubspecPath
        $content = $content -replace '(?m)^version:\s*.+$', "version: $NewVersion+$NewBuildNumber"
        Set-Content -Path $pubspecPath -Value $content -NoNewline
    }

    Write-Info "version set to $NewVersion+$NewBuildNumber"
}

function Test-RequiredFiles {
    $required = @(
        'AGENTS.md',
        'README.md',
        'CHANGELOG.md',
        'VERSION',
        'THIRD_PARTY_NOTICES.md',
        'pubspec.yaml',
        'analysis_options.yaml',
        '.gitignore',
        'tools/slovofon.ps1',
        'docs/SLOVOFON_TECHNICAL_SPEC_RU.md',
        'docs/ARCHITECTURE.md',
        'docs/BUILD_RELEASE.md',
        'docs/SECURITY.md',
        'docs/THEMING.md',
        'docs/SOURCES.md'
    )

    foreach ($file in $required) {
        $path = Join-Path $Script:Root $file
        Write-Check -Name $file -Ok (Test-Path $path) -Detail $(if (Test-Path $path) { 'present' } else { 'missing' })
    }
}

function Test-Environment {
    $Script:Failures.Clear()

    Test-RequiredFiles
    Test-Tool git | Out-Null
    Test-Tool gh -Optional | Out-Null
    Test-Tool flutter | Out-Null
    Test-Tool dart | Out-Null
    Test-Tool java -Optional | Out-Null
    Test-Tool adb -Optional | Out-Null
    Test-Tool sdkmanager -Optional | Out-Null
    Test-Tool iscc -Optional | Out-Null

    $androidSdk = $env:ANDROID_HOME
    if ([string]::IsNullOrWhiteSpace($androidSdk)) {
        $androidSdk = $env:ANDROID_SDK_ROOT
    }
    Write-Check -Name 'Android SDK' -Ok (-not [string]::IsNullOrWhiteSpace($androidSdk) -and (Test-Path $androidSdk)) -Detail $(if ($androidSdk) { $androidSdk } else { 'ANDROID_HOME/ANDROID_SDK_ROOT not set' }) -Optional

    $vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio/Installer/vswhere.exe'
    Write-Check -Name 'Visual Studio Build Tools' -Ok (Test-Path $vswhere) -Detail $(if (Test-Path $vswhere) { $vswhere } else { 'vswhere not found' }) -Optional

    $packageConfig = Join-Path $Script:Root '.dart_tool/package_config.json'
    Write-Check -Name 'pub packages' -Ok (Test-Path $packageConfig) -Detail $(if (Test-Path $packageConfig) { 'resolved' } else { 'run ./tools/slovofon.ps1 get after Flutter is installed' }) -Optional

    $bookZip = Join-Path $Script:Root 'Book.zip'
    Write-Check -Name 'Book.zip reference' -Ok (Test-Path $bookZip) -Detail $(if (Test-Path $bookZip) { 'present' } else { 'missing' })

    Show-Version
}

function Invoke-Bootstrap {
    Test-Environment

    $flutter = Get-Tool flutter
    if ($null -eq $flutter) {
        Write-Info 'Flutter is not installed or not in PATH. System components are not installed automatically.'
        Write-Info 'Install Flutter, Android SDK, and Windows build tools manually, then rerun bootstrap.'
        return
    }

    Invoke-Tool -Executable $flutter.Source -Arguments @('pub', 'get')
}

function Invoke-Doctor {
    Test-Environment

    $flutter = Get-Tool flutter
    if ($flutter) {
        Invoke-Tool -Executable $flutter.Source -Arguments @('doctor', '-v')
    }

    $gh = Get-Tool gh
    if ($gh) {
        & $gh.Source auth status
    }
}

function Invoke-Build {
    $flutter = Require-Tool flutter
    $buildMode = switch ($Configuration) {
        'debug' { '--debug' }
        'profile' { '--profile' }
        'release' { '--release' }
    }

    if ($Target -eq 'android' -or $Target -eq 'all') {
        Invoke-Tool -Executable $flutter -Arguments @('build', 'apk', $buildMode)
    }

    if ($Target -eq 'windows' -or $Target -eq 'all') {
        Invoke-Tool -Executable $flutter -Arguments @('build', 'windows', $buildMode)
    }
}

function Invoke-Clean {
    $targets = @(
        (Join-Path $Script:Root 'build'),
        (Join-Path $Script:Root '.dart_tool')
    )

    Write-Host 'This will remove local build/cache directories only:'
    foreach ($target in $targets) {
        Write-Host "  $target"
    }

    $answer = Read-Host 'Continue? [Y/N]'
    if ($answer -notin @('Y', 'y')) {
        Write-Info 'clean cancelled'
        return
    }

    foreach ($target in $targets) {
        if (-not (Test-Path $target)) {
            continue
        }

        $resolved = Resolve-Path $target
        if (-not $resolved.Path.StartsWith($Script:Root.Path, [System.StringComparison]::OrdinalIgnoreCase)) {
            throw "Refusing to remove path outside workspace: $($resolved.Path)"
        }

        Remove-Item -LiteralPath $resolved.Path -Recurse -Force
    }
}

Push-Location $Script:Root
try {
    switch ($Command) {
        'bootstrap' { Invoke-Bootstrap }
        'check' { Test-Environment }
        'doctor' { Invoke-Doctor }
        'get' {
            $flutter = Require-Tool flutter
            Invoke-Tool -Executable $flutter -Arguments @('pub', 'get')
        }
        'format' {
            $dart = Require-Tool dart
            Invoke-Tool -Executable $dart -Arguments @('format', '.')
        }
        'analyze' {
            $flutter = Require-Tool flutter
            Invoke-Tool -Executable $flutter -Arguments @('analyze')
        }
        'test' {
            $flutter = Require-Tool flutter
            Invoke-Tool -Executable $flutter -Arguments @('test')
        }
        'build' { Invoke-Build }
        'version' {
            $newVersion = if ($Set) { $Set } else { $Version }
            if ($newVersion) {
                Set-Version -NewVersion $newVersion -NewBuildNumber $BuildNumber
            }
            Show-Version
        }
        'release' {
            Write-Info 'Release packaging is intentionally not automated in the initial scaffold.'
            Write-Info 'No tag, push, GitHub Release, signing, or artifact deletion was performed.'
            throw 'Create platform projects and installer configuration before enabling release.'
        }
        'clean' { Invoke-Clean }
    }

    if ($Script:Failures.Count -gt 0) {
        exit 1
    }
} finally {
    Pop-Location
}
