#requires -Version 5.1
[CmdletBinding()]
param([Parameter(Mandatory = $true)][string]$NodePath,
    [Parameter(Mandatory = $true)][string]$EvidenceRoot)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'
$sourceRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path $sourceRoot 'Verify-BlacKKing-REA.ps1')
$utf8 = New-Object Text.UTF8Encoding($false)
$EvidenceRoot = [IO.Path]::GetFullPath($EvidenceRoot)
Assert-BlacKKingPlainPath $EvidenceRoot
[void][IO.Directory]::CreateDirectory($EvidenceRoot)
$workspace = Join-Path $EvidenceRoot ('installer-fixture-' + [guid]::NewGuid().ToString('N'))
if (Test-Path -LiteralPath $workspace) { throw 'Fixture workspace already exists.' }
[void][IO.Directory]::CreateDirectory($workspace)
$bundleRoot = Join-Path $workspace 'Bundle with spaces'
[void][IO.Directory]::CreateDirectory($bundleRoot)
$results = New-Object 'System.Collections.Generic.List[object]'
$complete = $false

function Write-FixtureFile {
    param([string]$Name, [string]$Text)
    $path = Join-Path $bundleRoot $Name
    [void][IO.Directory]::CreateDirectory((Split-Path -Parent $path))
    [IO.File]::WriteAllText($path, $Text, $utf8)
}
function Seal-Fixture {
    $files = @(Get-BlacKKingTreeFiles $bundleRoot | Where-Object { $_.FullName -ine (Join-Path $bundleRoot 'package-manifest.json') } |
        ForEach-Object { [ordered]@{ path = $_.FullName.Substring($bundleRoot.Length + 1).Replace('\', '/')
            bytes = $_.Length; sha256 = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant() } })
    [IO.File]::WriteAllText((Join-Path $bundleRoot 'package-manifest.json'), (@{ files = $files } | ConvertTo-Json -Depth 8), $utf8)
}
function Check {
    param([bool]$Condition, [string]$Name)
    $results.Add([pscustomobject]@{ name = $Name; pass = $Condition })
    if (-not $Condition) { throw "FAILED: $Name" }
}
function Run-Fixture {
    param([string]$Script, [string[]]$Options = @(), [switch]$PoisonEnvironment)
    $command = New-Object Diagnostics.ProcessStartInfo
    $command.FileName = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
    $native = @('-NoProfile', '-ExecutionPolicy', 'RemoteSigned', '-File', (Join-Path $bundleRoot $Script)) + $Options
    $command.Arguments = (($native | ForEach-Object { ConvertTo-BlacKKingNativeArgument $_ }) -join ' ')
    $command.UseShellExecute = $false
    $command.CreateNoWindow = $true
    $command.RedirectStandardOutput = $true
    $command.RedirectStandardError = $true
    $command.WorkingDirectory = $workspace
    if ($PoisonEnvironment) {
        $command.EnvironmentVariables['NODE_OPTIONS'] = '--require=blackking-fixture-preload-must-not-run.cjs'
        $command.EnvironmentVariables['NODE_PATH'] = 'fixture-injected-module-path'
        $command.EnvironmentVariables['REA_ANALYSIS_PROVIDER'] = 'fixture-invalid-provider'
        $command.EnvironmentVariables['GHIDRA_INSTALL_DIR'] = 'fixture-machine-only-provider-path'
    }
    $process = New-Object Diagnostics.Process
    $process.StartInfo = $command
    try {
        [void]$process.Start()
        $stdout = $process.StandardOutput.ReadToEndAsync()
        $stderr = $process.StandardError.ReadToEndAsync()
        $process.WaitForExit()
        [pscustomobject]@{ Code = $process.ExitCode; Out = $stdout.GetAwaiter().GetResult(); Err = $stderr.GetAwaiter().GetResult() }
    } finally { $process.Dispose() }
}
function Expect-ManifestReject {
    param([string]$Name, [scriptblock]$Mutate)
    $manifestPath = Join-Path $bundleRoot 'package-manifest.json'
    $saved = [IO.File]::ReadAllBytes($manifestPath)
    try {
        & $Mutate
        $rejected = $false
        try { [void](Test-BlacKKingBundle $bundleRoot) } catch { $rejected = $true }
        Check $rejected $Name
    } finally { [IO.File]::WriteAllBytes($manifestPath, $saved) }
}

try {
    foreach ($name in @('Verify-BlacKKing-REA.ps1', 'Install-BlacKKing-REA.ps1', 'Install-BlacKKing-REA.cmd', 'BlacKKing-REA.cmd')) {
        [IO.File]::Copy((Join-Path $sourceRoot $name), (Join-Path $bundleRoot $name), $false)
    }
    Write-FixtureFile 'runtime\rea\package.json' '{"type":"module"}'
    Write-FixtureFile 'skills\blackking-rea-workflow\SKILL.md' "---`nname: blackking-rea-workflow`ndescription: fixture`n---`nFixture skill.`n"
    Write-FixtureFile 'skills\blackking-rea-workflow\references\details.txt' 'fixture reference'
    Write-FixtureFile 'config\machine-profile.example.json' '{"provider_policy":"bring-your-own"}'
    Write-FixtureFile 'source\rea-source.zip' 'fixture only, not a real source archive'
    Write-FixtureFile 'README.md' 'Fixture only. Real production CLI tested separately.'
    Write-FixtureFile 'runtime\rea\scripts\rea.mjs' @'
import {existsSync, readFileSync, mkdirSync, writeFileSync} from 'node:fs';
import {join} from 'node:path';
const args = process.argv.slice(2);
if (args[0] === '--help') { console.log('REA deterministic installer fixture'); process.exit(0); }
const exact = ['setup','--client','codex','--skill=false'];
if (exact.some((a,i)=>args[i]!==a) || args.length !== 6 || args[5] !== '--json' ||
    !['--dry-run','--yes'].includes(args[4])) throw Error('Unexpected arguments: '+JSON.stringify(args));
if (process.env.NODE_OPTIONS || process.env.NODE_PATH || process.env.REA_ANALYSIS_PROVIDER || process.env.GHIDRA_INSTALL_DIR)
  throw Error('Ambient injection/provider setting leaked');
const home = process.env.CODEX_HOME;
const target = join(home,'config.toml');
const text = existsSync(target) ? readFileSync(target,'utf8') : '';
if (text.includes('foreign-fixture')) { console.log(JSON.stringify({status:'failed',remediation:'foreign ownership'})); process.exit(1); }
const plannedActions = text.includes('OWNED-FIXTURE') ? [] : [{id:'configure_client:codex',kind:'configure_client',external:false,operation:'create',target}];
if (args[4] === '--dry-run') console.log(JSON.stringify({status:'planned',plannedActions,appliedActions:[]}));
else {
  if (plannedActions.length) { mkdirSync(home,{recursive:true}); writeFileSync(target,text+'\n# OWNED-FIXTURE\n'); }
  console.log(JSON.stringify({status:'ready',plannedActions,appliedActions:plannedActions.length?['configured_codex']:[]}));
}
'@
    [void][IO.Directory]::CreateDirectory((Join-Path $bundleRoot 'runtime\node'))
    [IO.File]::Copy([IO.Path]::GetFullPath($NodePath), (Join-Path $bundleRoot 'runtime\node\node.exe'), $false)
    Seal-Fixture
    $verified = Test-BlacKKingBundle $bundleRoot
    Check ($verified.Files -eq 12) 'exact fixture membership and hashes'
    $response = Run-Fixture 'Verify-BlacKKing-REA.ps1'
    Check ($response.Code -eq 0) ('bundled Node and CLI help run: ' + $response.Err)
    $fixtureHome = Join-Path $workspace 'codex home with spaces'
    $response = Run-Fixture 'Install-BlacKKing-REA.ps1' @('-CodexHome', $fixtureHome)
    Check ($response.Code -eq 0 -and -not (Test-Path -LiteralPath $fixtureHome)) ('default Plan writes nothing: ' + $response.Err)
    $response = Run-Fixture 'Install-BlacKKing-REA.ps1' @('-CodexHome', $fixtureHome, '-RegisterMcp')
    Check ($response.Code -eq 0 -and -not (Test-Path -LiteralPath $fixtureHome)) ('MCP dry-run writes nothing: ' + $response.Err)
    $response = Run-Fixture 'Install-BlacKKing-REA.ps1' @('-CodexHome', $fixtureHome, '-RegisterMcp') -PoisonEnvironment
    Check ($response.Code -eq 0 -and -not (Test-Path -LiteralPath $fixtureHome)) ('Node preload and ambient provider overrides are child-local cleared: ' + $response.Err)
    Push-Location -LiteralPath $workspace
    try {
        $cmdHelp = & (Join-Path $bundleRoot 'BlacKKing-REA.cmd') --help
        Check ($LASTEXITCODE -eq 0 -and ($cmdHelp -join "`n") -match 'REA deterministic') 'CMD launcher works from unrelated cwd with spaces'
        $cmdPlan = & (Join-Path $bundleRoot 'Install-BlacKKing-REA.cmd') -CodexHome $fixtureHome
        Check ($LASTEXITCODE -eq 0 -and -not (Test-Path -LiteralPath $fixtureHome)) 'CMD installer remains read-only by default'
    } finally { Pop-Location }
    $response = Run-Fixture 'Install-BlacKKing-REA.ps1' @('-CodexHome', $fixtureHome, '-Apply')
    Check ($response.Code -eq 0 -and (Test-Path -LiteralPath (Join-Path $fixtureHome 'skills\blackking-rea-workflow\SKILL.md')) -and
        -not (Test-Path -LiteralPath (Join-Path $fixtureHome 'config.toml'))) ('Apply skill only: ' + $response.Err)
    $skillFile = Join-Path $fixtureHome 'skills\blackking-rea-workflow\SKILL.md'
    $beforeTime = (Get-Item -LiteralPath $skillFile).LastWriteTimeUtc.Ticks
    $response = Run-Fixture 'Install-BlacKKing-REA.ps1' @('-CodexHome', $fixtureHome, '-Apply')
    Check ($response.Code -eq 0 -and (Get-Item -LiteralPath $skillFile).LastWriteTimeUtc.Ticks -eq $beforeTime) 'identical skill is idempotent without rewrite'
    [IO.File]::AppendAllText($skillFile, 'user modification', $utf8)
    $changedHash = (Get-FileHash -LiteralPath $skillFile -Algorithm SHA256).Hash
    $response = Run-Fixture 'Install-BlacKKing-REA.ps1' @('-CodexHome', $fixtureHome, '-Apply', '-RegisterMcp')
    Check ($response.Code -ne 0 -and (Get-FileHash -LiteralPath $skillFile -Algorithm SHA256).Hash -eq $changedHash -and
        -not (Test-Path -LiteralPath (Join-Path $fixtureHome 'config.toml'))) 'different existing skill preserved before MCP mutation'

    $foreignHome = Join-Path $workspace 'foreign codex'
    [void][IO.Directory]::CreateDirectory($foreignHome)
    [IO.File]::WriteAllText((Join-Path $foreignHome 'config.toml'), '# foreign-fixture', $utf8)
    $response = Run-Fixture 'Install-BlacKKing-REA.ps1' @('-CodexHome', $foreignHome, '-Apply', '-RegisterMcp')
    Check ($response.Code -ne 0 -and [IO.File]::ReadAllText((Join-Path $foreignHome 'config.toml')) -eq '# foreign-fixture' -and
        @(Get-ChildItem -LiteralPath $foreignHome -Force).Count -eq 1) 'foreign REA owner preserves config and has no side effects'
    $registeredHome = Join-Path $workspace 'registered codex'
    [void][IO.Directory]::CreateDirectory($registeredHome)
    [IO.File]::WriteAllText((Join-Path $registeredHome 'config.toml'), '# preserve user settings', $utf8)
    $response = Run-Fixture 'Install-BlacKKing-REA.ps1' @('-CodexHome', $registeredHome, '-Apply', '-RegisterMcp')
    $backups = @(Get-ChildItem -LiteralPath $registeredHome -Filter '*.BlacKKing-REA-backup-*')
    Check ($response.Code -eq 0 -and $backups.Count -eq 1 -and [IO.File]::ReadAllText($backups[0].FullName) -eq '# preserve user settings') ('explicit MCP apply keeps exact config backup: ' + $response.Err)
    $configTime = (Get-Item -LiteralPath (Join-Path $registeredHome 'config.toml')).LastWriteTimeUtc.Ticks
    $response = Run-Fixture 'Install-BlacKKing-REA.ps1' @('-CodexHome', $registeredHome, '-Apply', '-RegisterMcp')
    Check ($response.Code -eq 0 -and (Get-Item -LiteralPath (Join-Path $registeredHome 'config.toml')).LastWriteTimeUtc.Ticks -eq $configTime -and
        @(Get-ChildItem -LiteralPath $registeredHome -Filter '*.BlacKKing-REA-backup-*').Count -eq 1) 'repeated MCP apply does not rewrite config or create extra backup'

    foreach ($variant in @('empty', 'duplicate', 'traversal', 'ads', 'fractional_bytes', 'required_missing', 'bad_hash')) {
        Expect-ManifestReject "manifest rejects $variant" {
            $path = Join-Path $bundleRoot 'package-manifest.json'
            $manifest = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
            switch ($variant) {
                'empty' { $manifest.files = @() }
                'duplicate' { $manifest.files += $manifest.files[0] }
                'traversal' { $manifest.files[0].path = '../outside' }
                'ads' { $manifest.files[0].path = 'README.md:stream' }
                'fractional_bytes' { $manifest.files[0].bytes = 0.5 }
                'required_missing' { $manifest.files = @($manifest.files | Where-Object { $_.path -ne 'runtime/node/node.exe' }) }
                'bad_hash' { $manifest.files[0].sha256 = '0' * 64 }
            }
            [IO.File]::WriteAllText($path, ($manifest | ConvertTo-Json -Depth 8), $utf8)
        }
    }
    $readmePath = Join-Path $bundleRoot 'README.md'
    $savedReadme = [IO.File]::ReadAllBytes($readmePath)
    try {
        [IO.File]::WriteAllText($readmePath, 'altered fixture', $utf8)
        $rejected = $false; try { [void](Test-BlacKKingBundle $bundleRoot) } catch { $rejected = $true }
        Check $rejected 'modified member rejects'
    } finally { [IO.File]::WriteAllBytes($readmePath, $savedReadme) }
    $extra = Join-Path $bundleRoot 'unlisted.txt'
    [IO.File]::WriteAllText($extra, 'extra', $utf8)
    try {
        $rejected = $false; try { [void](Test-BlacKKingBundle $bundleRoot) } catch { $rejected = $true }
        Check $rejected 'unlisted file rejects'
    } finally { [IO.File]::Delete($extra) }
    $junction = Join-Path $bundleRoot 'junction'
    New-Item -ItemType Junction -Path $junction -Target (Join-Path $bundleRoot 'skills') | Out-Null
    try {
        $rejected = $false; try { [void](Test-BlacKKingBundle $bundleRoot) } catch { $rejected = $true }
        Check $rejected 'directory reparse rejects before traversal'
    } finally { [IO.Directory]::Delete($junction) }
    [void](Test-BlacKKingBundle $bundleRoot)
    $complete = $true
} finally {
    $receipt = [ordered]@{ schema = 'blackking-rea-installer-fixture/v1'; generated_utc = [DateTime]::UtcNow.ToString('o')
        complete = $complete; tests = @($results.ToArray()); count = $results.Count
        node_path = [IO.Path]::GetFullPath($NodePath); fixture_workspace = $workspace; real_setup_tested = $false
        scope = 'Synthetic CLI contract and installer controls; real production setup must be tested separately.' }
    [IO.File]::WriteAllText((Join-Path $EvidenceRoot 'installer-fixture-tests.json'), ($receipt | ConvertTo-Json -Depth 9), $utf8)
    if ($complete) {
        # Verify the resolved target, ancestry and entire no-reparse tree before
        # removing only this run's new bounded fixture, never caller data.
        $resolved = (Get-Item -LiteralPath $workspace -Force).FullName
        if ($resolved -cne $workspace -or -not $resolved.StartsWith($EvidenceRoot + '\', [StringComparison]::OrdinalIgnoreCase) -or
            (Split-Path -Leaf $resolved) -notmatch '^installer-fixture-[a-f0-9]{32}$') { throw 'Fixture cleanup path changed.' }
        [void]@(Get-BlacKKingTreeFiles $resolved)
        Remove-Item -LiteralPath $resolved -Recurse -Force
    }
}
Write-Host "PASS: $($results.Count) installer fixture controls. Evidence: $(Join-Path $EvidenceRoot 'installer-fixture-tests.json')"
