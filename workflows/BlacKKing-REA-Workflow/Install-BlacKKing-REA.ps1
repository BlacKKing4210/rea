#requires -Version 5.1
[CmdletBinding()]
param([switch]$Apply, [switch]$RegisterMcp, [string]$CodexHome)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Verify-BlacKKing-REA.ps1')

function Get-BlacKKingSkillState {
    param([string]$Source, [string]$Destination)
    Assert-BlacKKingPlainPath $Destination
    if (-not (Test-Path -LiteralPath $Destination)) { return 'create' }
    if (-not (Test-Path -LiteralPath $Destination -PathType Container)) { throw "Skill destination is not a directory: $Destination" }
    $sourceFiles = @(Get-BlacKKingTreeFiles $Source)
    $destinationFiles = @(Get-BlacKKingTreeFiles $Destination)
    if ($sourceFiles.Count -ne $destinationFiles.Count) { throw "Existing different skill preserved: $Destination" }
    foreach ($file in $sourceFiles) {
        $relative = $file.FullName.Substring($Source.Length + 1)
        $target = Join-Path $Destination $relative
        if (-not (Test-Path -LiteralPath $target -PathType Leaf) -or
            (Get-Item -LiteralPath $target).Length -ne $file.Length -or
            (Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash -cne (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash) {
            throw "Existing different skill preserved: $Destination"
        }
    }
    return 'unchanged'
}

function Get-BlacKKingSetupPlan {
    param($Bundle, [string]$HomePath)
    $text = Invoke-BlacKKingRea $Bundle @('setup', '--client', 'codex', '--skill=false', '--dry-run', '--json') $HomePath
    Write-Host $text
    $plan = $text | ConvertFrom-Json
    if ($plan.status -ne 'planned' -or @($plan.appliedActions).Count -ne 0) {
        throw 'REA did not return a read-only setup plan. No registration or skill was changed.'
    }
    foreach ($action in @($plan.plannedActions)) {
        if ($action.id -ne 'configure_client:codex' -or $action.kind -ne 'configure_client' -or
            $action.external -ne $false -or
            -not [string]::Equals([IO.Path]::GetFullPath($action.target), (Join-Path $HomePath 'config.toml'), [StringComparison]::OrdinalIgnoreCase)) {
            throw 'Unexpected setup action. This installer permits only the selected Codex registration.'
        }
    }
    return $plan
}

try {
    $bundle = Test-BlacKKingBundle $PSScriptRoot
    [void](Test-BlacKKingCli $bundle)
    if ([string]::IsNullOrWhiteSpace($CodexHome)) {
        $CodexHome = $env:CODEX_HOME
        if ([string]::IsNullOrWhiteSpace($CodexHome)) {
            $CodexHome = Join-Path ([Environment]::GetFolderPath('UserProfile')) '.codex'
        }
    }
    $CodexHome = [IO.Path]::GetFullPath($CodexHome).TrimEnd('\', '/')
    if ($CodexHome -match '^[A-Za-z]:$') { throw 'CodexHome must be a dedicated directory, not a drive root.' }
    Assert-BlacKKingPlainPath $CodexHome
    $source = Join-Path $bundle.Root 'skills\blackking-rea-workflow'
    $destination = Join-Path $CodexHome 'skills\blackking-rea-workflow'
    if ($CodexHome.StartsWith($bundle.Root + '\', [StringComparison]::OrdinalIgnoreCase) -or $CodexHome -ieq $bundle.Root) {
        throw 'CodexHome must be outside the verified bundle.'
    }
    $skillState = Get-BlacKKingSkillState $source $destination
    Write-Host "Mode: $(if ($Apply) { 'Apply' } else { 'Plan (read-only)' })"
    Write-Host "Skill: $skillState -> $destination"
    Write-Host 'Analysis engines: bring your own. No provider, software, account, or network changes are made.'
    $setupPlan = $null
    if ($RegisterMcp) { $setupPlan = Get-BlacKKingSetupPlan $bundle $CodexHome }
    else { Write-Host 'MCP registration: not selected. Add -RegisterMcp to preview it; add -Apply to authorize it.' }
    if (-not $Apply) {
        [pscustomobject]@{ status = 'planned'; codex_home = $CodexHome; skill = $skillState; mcp_selected = [bool]$RegisterMcp; changed = $false }
        return
    }

    # All conflict checks and the official ownership check precede mutation.
    # The official setup transaction owns TOML parsing, backup/write/readback.
    $backupPath = $null
    if ($RegisterMcp) {
        $configPath = Join-Path $CodexHome 'config.toml'
        Assert-BlacKKingPlainPath $configPath
        if (@($setupPlan.plannedActions).Count -gt 0 -and (Test-Path -LiteralPath $configPath)) {
            if (-not (Test-Path -LiteralPath $configPath -PathType Leaf)) { throw 'Codex config.toml must be a regular file.' }
            $backupPath = $configPath + '.BlacKKing-REA-backup-' + [guid]::NewGuid().ToString('N')
            [IO.File]::Copy($configPath, $backupPath, $false)
            if ((Get-FileHash -LiteralPath $configPath -Algorithm SHA256).Hash -cne
                (Get-FileHash -LiteralPath $backupPath -Algorithm SHA256).Hash) { throw "Backup verification failed; preserved $backupPath" }
        }
        $text = Invoke-BlacKKingRea $bundle @('setup', '--client', 'codex', '--skill=false', '--yes', '--json') $CodexHome
        Write-Host $text
        $result = $text | ConvertFrom-Json
        if ($result.status -ne 'ready') { throw "Official setup did not complete. Preserve any reported backup. $backupPath" }
        # A second official plan independently checks registration idempotence.
        $after = Get-BlacKKingSetupPlan $bundle $CodexHome
        if (@($after.plannedActions).Count -ne 0) { throw 'Registration was written but is not aligned; skill was not installed.' }
    }
    $skillState = Get-BlacKKingSkillState $source $destination
    if ($skillState -eq 'create') {
        $parentPath = Split-Path -Parent $destination
        Assert-BlacKKingPlainPath $parentPath
        [void][IO.Directory]::CreateDirectory($parentPath)
        # An exclusive new directory avoids partial overwrite of another skill.
        $stage = Join-Path $parentPath ('.blackking-rea-stage-' + [guid]::NewGuid().ToString('N'))
        [void][IO.Directory]::CreateDirectory($stage)
        foreach ($file in Get-BlacKKingTreeFiles $source) {
            $relative = $file.FullName.Substring($source.Length + 1)
            $target = Join-Path $stage $relative
            [void][IO.Directory]::CreateDirectory((Split-Path -Parent $target))
            [IO.File]::Copy($file.FullName, $target, $false)
        }
        [void](Get-BlacKKingSkillState $source $stage)
        Assert-BlacKKingPlainPath $destination
        [IO.Directory]::Move($stage, $destination)
        $skillState = 'installed'
    }
    [pscustomobject]@{ status = 'complete'; codex_home = $CodexHome; skill = $skillState; mcp_selected = [bool]$RegisterMcp
        config_backup = $backupPath; manifest_sha256 = $bundle.ManifestSha256 }
} catch { Write-Error $_; exit 1 }
