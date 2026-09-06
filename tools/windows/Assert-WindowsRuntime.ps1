[CmdletBinding()]
param([Parameter(Mandatory)][string]$BundleDir)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-PeImportedLibraries {
    param([Parameter(Mandatory)][string]$Path)
    $bytes = [IO.File]::ReadAllBytes($Path)
    function Read-U16([int]$Offset) {
        if ($Offset -lt 0 -or $Offset + 2 -gt $bytes.Length) { throw "Invalid PE bounds: $Path" }
        return [BitConverter]::ToUInt16($bytes, $Offset)
    }
    function Read-U32([int]$Offset) {
        if ($Offset -lt 0 -or $Offset + 4 -gt $bytes.Length) { throw "Invalid PE bounds: $Path" }
        return [BitConverter]::ToUInt32($bytes, $Offset)
    }
    if ((Read-U16 0) -ne 0x5a4d) { throw "Not a PE binary: $Path" }
    $pe = [int](Read-U32 0x3c)
    if ((Read-U32 $pe) -ne 0x4550) { throw "Invalid PE signature: $Path" }
    $sections = Read-U16 ($pe + 6)
    $optionalSize = Read-U16 ($pe + 20)
    $optional = $pe + 24
    $magic = Read-U16 $optional
    $directory = switch ($magic) {
        0x20b { $optional + 112 }
        0x10b { $optional + 96 }
        default { throw "Unsupported PE optional header: $Path" }
    }
    if ($directory + 16 -gt $optional + $optionalSize) { throw "Missing PE import directory: $Path" }
    $importRva = Read-U32 ($directory + 8)
    if ($importRva -eq 0) { return }
    $sectionOffset = $optional + $optionalSize
    function Convert-Rva([uint32]$Rva) {
        for ($index = 0; $index -lt $sections; $index++) {
            $section = $sectionOffset + 40 * $index
            $address = Read-U32 ($section + 12)
            $rawSize = Read-U32 ($section + 16)
            $rawOffset = Read-U32 ($section + 20)
            if ($Rva -ge $address -and ([long]$Rva - $address) -lt $rawSize) {
                $offset = [long]$rawOffset + $Rva - $address
                if ($offset -ge $bytes.Length) { throw "Invalid PE RVA: $Path" }
                return [int]$offset
            }
        }
        throw "Unmapped PE RVA: $Path"
    }
    $descriptor = Convert-Rva $importRva
    while ($true) {
        $nameRva = Read-U32 ($descriptor + 12)
        if ($nameRva -eq 0) { break }
        $start = Convert-Rva $nameRva
        $end = $start
        while ($end -lt $bytes.Length -and $bytes[$end] -ne 0 -and $end - $start -lt 260) { $end++ }
        if ($end -ge $bytes.Length -or $bytes[$end] -ne 0) { throw "Invalid PE import name: $Path" }
        [Text.Encoding]::ASCII.GetString($bytes, $start, $end - $start)
        $descriptor += 20
    }
}

$bundle = (Resolve-Path -LiteralPath $BundleDir).Path
if (-not (Test-Path -LiteralPath (Join-Path $bundle 'Slovofon.exe') -PathType Leaf)) {
    throw 'Windows bundle does not contain Slovofon.exe.'
}
$missing = [Collections.Generic.List[string]]::new()
$binaries = @(Get-ChildItem -LiteralPath $bundle -File | Where-Object { $_.Extension -in '.exe', '.dll' })
foreach ($binary in $binaries) {
    foreach ($library in (Get-PeImportedLibraries -Path $binary.FullName)) {
        if ($library -notmatch '^(msvcp[0-9]+.*|vcruntime[0-9]+.*|concrt[0-9]+)\.dll$') { continue }
        $runtime = Join-Path $bundle $library
        if (-not (Test-Path -LiteralPath $runtime -PathType Leaf) -or (Get-Item -LiteralPath $runtime).Length -eq 0) {
            $missing.Add("$($binary.Name) -> $library")
        }
    }
}
if ($missing.Count -gt 0) { throw "Missing app-local MSVC runtime: $($missing -join ', ')" }
Write-Host "Validated app-local MSVC imports in $($binaries.Count) Windows binaries."
