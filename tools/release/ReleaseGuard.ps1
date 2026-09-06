Set-StrictMode -Version Latest

function Assert-ReleaseTagSnapshot {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Tag,
        [Parameter(Mandatory)][string]$ExpectedCommit,
        [AllowEmptyString()][string]$RemoteRefs = '',
        [switch]$RequireTag
    )

    if ($Tag -notmatch '^v[0-9]+\.[0-9]+\.[0-9]+$') {
        throw 'Release tag must have the form vMAJOR.MINOR.PATCH.'
    }
    if ($ExpectedCommit -notmatch '^[0-9a-fA-F]{40}$') {
        throw 'ExpectedCommit must be a full Git commit SHA.'
    }
    $tagObject = $null
    $peeledCommit = $null
    foreach ($line in ($RemoteRefs -split '\r?\n')) {
        if ([string]::IsNullOrWhiteSpace($line)) { continue }
        $fields = $line -split '\s+', 2
        if ($fields.Count -ne 2 -or $fields[0] -notmatch '^[0-9a-fA-F]{40}$') {
            throw 'Malformed remote tag response.'
        }
        if ($fields[1] -ceq "refs/tags/$Tag") {
            if ($null -ne $tagObject) { throw 'Duplicate remote tag response.' }
            $tagObject = $fields[0]
        } elseif ($fields[1] -ceq "refs/tags/$Tag^{}") {
            if ($null -ne $peeledCommit) { throw 'Duplicate peeled tag response.' }
            $peeledCommit = $fields[0]
        } else {
            throw 'Remote response contains an unexpected tag.'
        }
    }
    if ($null -eq $tagObject) {
        if ($null -ne $peeledCommit -or $RequireTag) {
            throw "Release tag $Tag is missing."
        }
        return $false
    }
    $target = if ($null -ne $peeledCommit) { $peeledCommit } else { $tagObject }
    if ($target -ine $ExpectedCommit) {
        throw "Release tag $Tag points to $target, not the built commit $ExpectedCommit."
    }
    return $true
}

function Assert-RemoteReleaseTag {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Tag,
        [Parameter(Mandatory)][string]$ExpectedCommit,
        [string]$Remote = 'origin',
        [switch]$RequireTag
    )
    # Validate input before passing it to any external command.
    Assert-ReleaseTagSnapshot -Tag $Tag -ExpectedCommit $ExpectedCommit | Out-Null
    $refs = & git ls-remote --tags $Remote "refs/tags/$Tag" "refs/tags/$Tag^{}"
    if ($LASTEXITCODE -ne 0) { throw 'Failed to read remote release tag; refusing publication.' }
    return Assert-ReleaseTagSnapshot -Tag $Tag -ExpectedCommit $ExpectedCommit `
        -RemoteRefs ($refs -join "`n") -RequireTag:$RequireTag
}
