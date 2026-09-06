[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$MsiPath,
    [switch]$Preview
)

# Read-only contract validation of an already compiled MSI. This opens only its
# database, never an Installer session, action, install, repair or uninstall.
# Usage: ./tools/windows/Test-MsiInstaller.ps1 -MsiPath package.msi [-Preview]
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
if (-not $IsWindows) { throw 'MSI database validation requires Windows and PowerShell 7.' }
$resolved = (Resolve-Path -LiteralPath $MsiPath).Path
if (-not (Test-Path -LiteralPath $resolved -PathType Leaf)) { throw 'MsiPath must be a file.' }
$checks = [Collections.Generic.List[string]]::new()
$installer = $null
$database = $null
$summary = $null

function Get-ComProperty {
    param($Object, [string]$Name, [object[]]$Arguments = @())
    return $Object.GetType().InvokeMember($Name, [Reflection.BindingFlags]::GetProperty, $null, $Object, $Arguments)
}

function Invoke-ComMethod {
    param($Object, [string]$Name, [object[]]$Arguments = @())
    return $Object.GetType().InvokeMember($Name, [Reflection.BindingFlags]::InvokeMethod, $null, $Object, $Arguments)
}

function Close-ComObject {
    param($Object)
    if ($null -ne $Object -and [Runtime.InteropServices.Marshal]::IsComObject($Object)) {
        [void][Runtime.InteropServices.Marshal]::FinalReleaseComObject($Object)
    }
}

function Read-MsiRows {
    param([string]$Table, [string[]]$Columns)
    if (-not $script:tableNames.Contains($Table)) { return }
    $columnSql = ($Columns | ForEach-Object { '`' + $_ + '`' }) -join ', '
    $view = $null
    try {
        $view = Invoke-ComMethod $database 'OpenView' @("SELECT $columnSql FROM ``$Table``")
        [void](Invoke-ComMethod $view 'Execute')
        while ($null -ne ($record = Invoke-ComMethod $view 'Fetch')) {
            try {
                $row = @{}
                $count = [int](Get-ComProperty $record 'FieldCount')
                for ($index = 1; $index -le $count; $index++) {
                    $row[$Columns[$index - 1]] = [string](Get-ComProperty $record 'StringData' @($index))
                }
                $row
            } finally { Close-ComObject $record }
        }
    } finally {
        if ($null -ne $view) { [void](Invoke-ComMethod $view 'Close') }
        Close-ComObject $view
    }
}

function Require {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw "MSI contract failed: $Message" }
    $checks.Add($Message)
}

function Get-SingleRow {
    param([object[]]$Rows, [string]$Column, [string]$Value)
    $matches = @($Rows | Where-Object { $_[$Column] -eq $Value })
    if ($matches.Count -ne 1) { throw "Expected one $Column=$Value row, found $($matches.Count)." }
    return $matches[0]
}

try {
    $installer = New-Object -ComObject WindowsInstaller.Installer
    # msiOpenDatabaseModeReadOnly = 0; no transactions or database writes.
    $database = Invoke-ComMethod $installer 'OpenDatabase' @($resolved, 0)
    $script:tableNames = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    [void]$script:tableNames.Add('_Tables')
    foreach ($row in Read-MsiRows '_Tables' @('Name')) { [void]$script:tableNames.Add($row.Name) }
    $properties = @{}
    foreach ($row in Read-MsiRows 'Property' @('Property', 'Value')) { $properties[$row.Property] = $row.Value }
    Require ($properties['ProductName'] -eq 'Slovofon') 'Product name remains Slovofon'
    Require ($properties['Manufacturer'] -eq 'Slovofon Team') 'Manufacturer remains Slovofon Team'
    Require ($properties['ProductVersion'] -match '^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$') 'Public MSI version has three numeric fields'
    $version = [version]$properties['ProductVersion']
    Require ($version.Major -le 255 -and $version.Minor -le 255 -and $version.Build -le 65535) 'Version fits Windows Installer limits'
    Require ($properties['ProductLanguage'] -in @('1033', '1049')) 'MSI language is English or Russian'
    Require ($properties['ALLUSERS'] -eq '1') 'MSI is an all-users installation'
    $summary = Get-ComProperty $database 'SummaryInformation' @(0)
    $template = [string](Get-ComProperty $summary 'Property' @(7))
    Require ($template -match '^x64;(1033|1049)$') 'Summary template targets Windows x64 with supported language'
    Require ($template.Split(';')[1] -eq $properties['ProductLanguage']) 'Summary and product languages agree'

    foreach ($property in @('ARPSYSTEMCOMPONENT', 'ARPNOREMOVE')) {
        Require (-not $properties.ContainsKey($property) -or $properties[$property] -eq '0') "$property does not hide or disable Windows uninstall"
    }
    $icons = @(Read-MsiRows 'Icon' @('Name'))
    Require (@($icons | Where-Object { $_.Name -eq $properties['ARPPRODUCTICON'] }).Count -eq 1) 'ARP icon is present in the compiled Icon table'
    foreach ($pair in @(
        @('ARPHELPLINK', 'https://github.com/Dushnyj/Slovofon/issues'),
        @('ARPURLINFOABOUT', 'https://github.com/Dushnyj/Slovofon'),
        @('ARPURLUPDATEINFO', 'https://github.com/Dushnyj/Slovofon/releases')
    )) { Require ($properties[$pair[0]] -eq $pair[1]) "$($pair[0]) points to the official GitHub repository" }
    $actions = @(Read-MsiRows 'CustomAction' @('Action', 'Type', 'Source', 'Target'))
    $arpLocation = Get-SingleRow $actions 'Action' 'SetARPINSTALLLOCATION'
    Require ($arpLocation.Type -eq '51' -and $arpLocation.Source -eq 'ARPINSTALLLOCATION' -and $arpLocation.Target -eq '[INSTALLFOLDER]') 'ARP install path is formatted at runtime'

    $ui = @(Read-MsiRows 'InstallUISequence' @('Action', 'Condition', 'Sequence'))
    $execute = @(Read-MsiRows 'InstallExecuteSequence' @('Action', 'Condition', 'Sequence'))
    $welcome = Get-SingleRow $ui 'Action' 'WelcomeDlg'
    $maintenance = Get-SingleRow $ui 'Action' 'MaintenanceWelcomeDlg'
    $exit = Get-SingleRow $ui 'Action' 'ExitDialog'
    $progress = Get-SingleRow $ui 'Action' 'ProgressDlg'
    Require ($welcome.Condition -eq 'NOT Installed OR PATCH' -and [int]$welcome.Sequence -gt 1000 -and [int]$welcome.Sequence -lt [int]$progress.Sequence) 'Welcome runs after costing and before progress'
    Require ($maintenance.Condition -eq 'Installed AND NOT RESUME AND NOT Preselected AND NOT PATCH' -and [int]$maintenance.Sequence -lt [int]$progress.Sequence) 'Maintenance dialog is scheduled only for maintenance'
    Require ($exit.Sequence -eq '-1' -and $exit.Condition -in @('', '1')) 'Finish dialog is unconditional on successful UI exit'
    foreach ($action in @('RegisterProduct', 'PublishProduct', 'RemoveFiles', 'RemoveShortcuts')) {
        Require (@($execute | Where-Object { $_.Action -eq $action }).Count -eq 1) "$action is present in the execute sequence"
    }
    $initialize = Get-SingleRow $execute 'Action' 'InstallInitialize'
    $removeOld = Get-SingleRow $execute 'Action' 'RemoveExistingProducts'
    $processComponents = Get-SingleRow $execute 'Action' 'ProcessComponents'
    Require ([int]$removeOld.Sequence -gt [int]$initialize.Sequence -and [int]$removeOld.Sequence -lt [int]$processComponents.Sequence) 'Major upgrade removal remains inside rollback before component processing'
    $upgrades = @(Read-MsiRows 'Upgrade' @('UpgradeCode', 'VersionMin', 'VersionMax', 'Attributes', 'ActionProperty'))
    $downgrade = Get-SingleRow $upgrades 'ActionProperty' 'WIX_DOWNGRADE_DETECTED'
    $upgrade = Get-SingleRow $upgrades 'ActionProperty' 'WIX_UPGRADE_DETECTED'
    Require ($downgrade.UpgradeCode -eq $properties['UpgradeCode'] -and $upgrade.UpgradeCode -eq $properties['UpgradeCode']) 'Upgrade detection uses the product UpgradeCode'
    Require (([int]$downgrade.Attributes -band 2) -ne 0 -and $downgrade.VersionMin -eq $properties['ProductVersion']) 'Newer installed versions are detected without being removed'
    $launchConditions = @(Read-MsiRows 'LaunchCondition' @('Condition', 'Description'))
    Require (@($launchConditions | Where-Object { $_.Condition -eq 'NOT WIX_DOWNGRADE_DETECTED' }).Count -eq 1) 'Launch condition blocks downgrade'

    $events = @(Read-MsiRows 'ControlEvent' @('Dialog_', 'Control_', 'Event', 'Argument', 'Condition', 'Ordering'))
    $finish = @($events | Where-Object { $_.Dialog_ -eq 'ExitDialog' -and $_.Control_ -eq 'Finish' } | Sort-Object { [int]$_.Ordering })
    Require ($finish.Count -eq 3) 'Finish has exactly the three expected events'
    Require ($finish[0].Event -eq 'DoAction' -and $finish[0].Argument -eq 'SetSlovofonLaunchTarget' -and $finish[0].Ordering -eq '1') 'Finish formats its launch target first'
    Require ($finish[1].Event -eq 'DoAction' -and $finish[1].Argument -eq 'LaunchSlovofon' -and $finish[1].Ordering -eq '2') 'Finish invokes the launch action second'
    Require ($finish[1].Condition -eq 'WIXUI_EXITDIALOGOPTIONALCHECKBOX = "1" AND NOT Installed AND REMOVE <> "ALL" AND NOT ReplacedInUseFiles AND NOT MsiSystemRebootPending') 'Launch requires consent and excludes maintenance, uninstall and restart'
    Require ($finish[2].Event -eq 'EndDialog' -and $finish[2].Argument -eq 'Return' -and $finish[2].Ordering -eq '3' -and $finish[2].Condition -in @('', '1')) 'Finish always closes after optional launch'
    $setTarget = Get-SingleRow $actions 'Action' 'SetSlovofonLaunchTarget'
    $launch = Get-SingleRow $actions 'Action' 'LaunchSlovofon'
    Require ($setTarget.Type -eq '51' -and $setTarget.Source -eq 'WixUnelevatedShellExecTarget' -and $setTarget.Target -eq '[INSTALLFOLDER]Slovofon.exe') 'Compiled type-51 target action is correct'
    Require ($launch.Type -eq '65' -and $launch.Source -eq 'Wix4UtilCA_X64' -and $launch.Target -eq 'WixUnelevatedShellExec') 'Compiled native launch is immediate, unelevated and ignores failure'
    $binaries = @(Read-MsiRows 'Binary' @('Name'))
    Require (@($binaries | Where-Object { $_.Name -eq $launch.Source }).Count -eq 1) 'Native util action binary is embedded'
    Require (-not $properties.ContainsKey('WIXUI_EXITDIALOGOPTIONALCHECKBOX')) 'Launch checkbox is off by default'
    foreach ($table in @('InstallExecuteSequence', 'AdminExecuteSequence', 'AdvtExecuteSequence')) {
        $sequence = @(Read-MsiRows $table @('Action', 'Condition', 'Sequence'))
        Require (@($sequence | Where-Object { $_.Action -in @('SetSlovofonLaunchTarget', 'LaunchSlovofon') }).Count -eq 0) "$table never launches the application"
        $guards = @($sequence | Where-Object { $_.Action -eq 'BlockPreviewExecution' })
        if ($Preview) {
            Require ($guards.Count -eq 1) "$table contains the preview execution guard"
            $cost = Get-SingleRow $sequence 'Action' 'CostInitialize'
            Require ($guards[0].Condition -eq '1' -and [int]$guards[0].Sequence -gt 0 -and [int]$guards[0].Sequence -lt [int]$cost.Sequence) "$table is unconditionally blocked before costing"
        } else { Require ($guards.Count -eq 0) "$table contains no preview guard in a production package" }
    }
    $guardActions = @($actions | Where-Object { $_.Action -eq 'BlockPreviewExecution' })
    if ($Preview) {
        Require ($guardActions.Count -eq 1 -and $guardActions[0].Type -eq '19' -and $guardActions[0].Target -like '*Installation is disabled*') 'Preview guard is an unconditional type-19 error, not executable code'
        Require ($properties['UpgradeCode'] -ne '{9C9D9F71-5A2B-4F6D-8C58-9D4C8D2F8B8C}') 'Preview uses an isolated UpgradeCode'
    } else {
        Require ($guardActions.Count -eq 0) 'Production package does not contain the preview-only error action'
        Require ($properties['UpgradeCode'] -eq '{9C9D9F71-5A2B-4F6D-8C58-9D4C8D2F8B8C}') 'Production UpgradeCode preserves the approved identity'
    }

    $secure = $properties['SecureCustomProperties'] -split ';'
    Require ('INSTALLFOLDER' -in $secure -and 'DESKTOPSHORTCUT' -in $secure) 'Folder and desktop selection cross the elevation boundary'
    $features = @(Read-MsiRows 'Feature' @('Feature', 'Level', 'Attributes'))
    $desktop = Get-SingleRow $features 'Feature' 'DesktopFeature'
    Require ([int]$desktop.Level -gt 1 -and -not $properties.ContainsKey('DESKTOPSHORTCUT')) 'Desktop shortcut is not selected on a fresh install'
    $conditions = @(Read-MsiRows 'Condition' @('Feature_', 'Level', 'Condition'))
    Require (@($conditions | Where-Object { $_.Feature_ -eq 'DesktopFeature' -and $_.Level -eq '1' -and $_.Condition -eq 'DESKTOPSHORTCUT = "1"' }).Count -eq 1) 'Desktop selection has a costing condition for non-full UI'
    $controls = @(Read-MsiRows 'Control' @('Dialog_', 'Control', 'Type', 'Property'))
    Require (@($controls | Where-Object { $_.Dialog_ -eq 'SlovofonDestinationDlg' -and $_.Type -eq 'CheckBox' -and $_.Property -eq 'DESKTOPSHORTCUT' }).Count -eq 1) 'Destination exposes the desktop checkbox'
    $checkboxes = @(Read-MsiRows 'CheckBox' @('Property', 'Value'))
    Require (@($checkboxes | Where-Object { $_.Property -eq 'DESKTOPSHORTCUT' -and $_.Value -eq '1' }).Count -eq 1) 'Desktop checkbox uses the expected value'
    foreach ($event in @('AddLocal', 'Remove')) {
        Require (@($events | Where-Object { $_.Dialog_ -eq 'SlovofonDestinationDlg' -and $_.Control_ -eq 'Next' -and $_.Event -eq $event -and $_.Argument -eq 'DesktopFeature' }).Count -eq 1) "Desktop $event selection is applied after UI costing"
    }

    $removals = @(Read-MsiRows 'RemoveFile' @('FileKey', 'FileName', 'DirProperty', 'InstallMode'))
    Require (@($removals | Where-Object { $_.FileName -ne '' -or $_.DirProperty -ne 'ApplicationProgramsFolder' -or $_.InstallMode -ne '2' }).Count -eq 0) 'Explicit deletion is restricted to the empty Start menu folder at uninstall'
    $directories = @(Read-MsiRows 'Directory' @('Directory', 'Directory_Parent', 'DefaultDir'))
    Require (@($directories | Where-Object { $_.Directory -in @('AppDataFolder', 'LocalAppDataFolder', 'PersonalFolder', 'CommonAppDataFolder') }).Count -eq 0) 'MSI does not own user-data directories'
    $registry = @(Read-MsiRows 'Registry' @('Root', 'Key', 'Name', 'Value'))
    $markerKey = if ($Preview) { 'Software\SlovofonInstallerPreview\Installer' } else { 'Software\Slovofon\Installer' }
    Require (@($registry | Where-Object { $_.Root -eq '2' -and $_.Key -eq $markerKey -and $_.Name -eq 'Type' -and $_.Value -eq 'msi' }).Count -eq 1) 'Installer marker identifies the correct product scope'
    Require (@($registry | Where-Object { $_.Root -eq '2' -and $_.Key -eq $markerKey -and $_.Name -eq 'InstallLocation' -and $_.Value -eq '[INSTALLFOLDER]' }).Count -eq 1) 'Installer marker records the selected installation folder'
    $installFolder = Get-SingleRow $directories 'Directory' 'INSTALLFOLDER'
    Require ($installFolder.Directory_Parent -eq 'ProgramFiles64Folder') 'Default installation folder is under Program Files x64'
    $folderName = ($installFolder.DefaultDir -split '\|')[-1]
    $expectedFolder = if ($Preview) { 'SlovofonInstallerPreview' } else { 'Slovofon' }
    Require ($folderName -eq $expectedFolder) 'Installation folder has the expected production or preview identity'

    [pscustomobject]@{
        Result = 'PASS'
        Checks = $checks.Count
        MsiPath = $resolved
        ProductVersion = $properties['ProductVersion']
        ProductLanguage = $properties['ProductLanguage']
        Template = $template
        Preview = [bool]$Preview
        Sha256 = (Get-FileHash -LiteralPath $resolved -Algorithm SHA256).Hash.ToLowerInvariant()
        Validation = 'Read-only compiled database contracts; no installation or native UI test performed.'
    }
} finally {
    Close-ComObject $summary
    Close-ComObject $database
    Close-ComObject $installer
}
