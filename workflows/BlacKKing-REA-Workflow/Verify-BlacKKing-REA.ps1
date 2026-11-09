#requires -Version 5.1
[CmdletBinding()]
param()

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

function Assert-BlacKKingPlainPath {
    param([Parameter(Mandatory = $true)][string]$Path)
    $itemPath = [IO.Path]::GetFullPath($Path)
    while ($itemPath) {
        if (Test-Path -LiteralPath $itemPath) {
            $item = Get-Item -LiteralPath $itemPath -Force
            if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
                throw "Reparse points are not accepted: $itemPath"
            }
        }
        $parent = [IO.Path]::GetDirectoryName($itemPath)
        if ($parent -eq $itemPath) { break }
        $itemPath = $parent
    }
}

function Get-BlacKKingTreeFiles {
    param([Parameter(Mandatory = $true)][string]$Root)
    Assert-BlacKKingPlainPath $Root
    $queue = New-Object 'System.Collections.Generic.Queue[string]'
    $queue.Enqueue($Root)
    while ($queue.Count -gt 0) {
        foreach ($item in Get-ChildItem -LiteralPath ($queue.Dequeue()) -Force) {
            if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
                throw "Reparse points are not accepted: $($item.FullName)"
            }
            if ($item.PSIsContainer) { $queue.Enqueue($item.FullName) }
            else { $item }
        }
    }
}

function Test-BlacKKingBundle {
    param([Parameter(Mandatory = $true)][string]$Root)
    $Root = [IO.Path]::GetFullPath($Root).TrimEnd('\', '/')
    if ($Root -match '^[A-Za-z]:$') { throw 'The bundle must be in its own directory, not a drive root.' }
    Assert-BlacKKingPlainPath $Root
    $manifestPath = Join-Path $Root 'package-manifest.json'
    if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
        throw 'Missing package-manifest.json. Extract the complete release ZIP first.'
    }
    Assert-BlacKKingPlainPath $manifestPath
    $manifest = Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($null -eq $manifest.PSObject.Properties['files'] -or $manifest.files -isnot [array] -or $manifest.files.Count -eq 0) {
        throw 'The manifest must contain a nonempty files array.'
    }
    $expected = New-Object 'System.Collections.Generic.Dictionary[string,object]' ([StringComparer]::OrdinalIgnoreCase)
    $totalBytes = [long]0
    foreach ($member in $manifest.files) {
        foreach ($field in @('path', 'bytes', 'sha256')) {
            if ($null -eq $member.PSObject.Properties[$field]) { throw "Manifest member lacks $field." }
        }
        $name = $member.path
        if ($name -isnot [string] -or [string]::IsNullOrEmpty($name) -or $name.Contains('\') -or
            $name -match '(^/|[<>:"|?*\x00-\x1f])') { throw "Unsafe manifest path: $name" }
        foreach ($part in $name.Split('/')) {
            if ($part -eq '' -or $part -eq '.' -or $part -eq '..' -or $part -match '[. ]$' -or
                $part -match '^(?i:CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])(?:\.|$)') {
                throw "Unsafe Windows manifest path: $name"
            }
        }
        if ($name -ieq 'package-manifest.json' -or $expected.ContainsKey($name)) {
            throw "Duplicate or self-listed manifest path: $name"
        }
        $size = $member.bytes
        if ($size -isnot [ValueType] -or $size -is [bool] -or $size -lt 0 -or
            [decimal]$size -ne [decimal]::Truncate([decimal]$size) -or [decimal]$size -gt [long]::MaxValue) {
            throw "Invalid byte count for $name"
        }
        if ($member.sha256 -isnot [string] -or $member.sha256 -notmatch '^[a-fA-F0-9]{64}$') {
            throw "Invalid SHA256 for $name"
        }
        $fullPath = [IO.Path]::GetFullPath((Join-Path $Root $name.Replace('/', '\')))
        if (-not $fullPath.StartsWith($Root + '\', [StringComparison]::OrdinalIgnoreCase)) {
            throw "Manifest path escaped the bundle: $name"
        }
        $expected.Add($name, $member)
        $totalBytes += [long]$size
    }
    foreach ($required in @('runtime/node/node.exe', 'runtime/rea/scripts/rea.mjs', 'runtime/rea/package.json',
            'skills/blackking-rea-workflow/SKILL.md', 'config/machine-profile.example.json', 'source/rea-source.zip',
            'Install-BlacKKing-REA.ps1', 'Verify-BlacKKing-REA.ps1', 'Install-BlacKKing-REA.cmd', 'BlacKKing-REA.cmd')) {
        if (-not $expected.ContainsKey($required)) { throw "Required bundle member is unlisted: $required" }
    }
    $seen = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
    foreach ($file in Get-BlacKKingTreeFiles $Root) {
        $relative = $file.FullName.Substring($Root.Length + 1).Replace('\', '/')
        if ($relative -ieq 'package-manifest.json') { continue }
        if (-not $expected.ContainsKey($relative)) { throw "Unlisted bundle file: $relative" }
        $member = $expected[$relative]
        if ($file.Length -ne [long]$member.bytes -or
            (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash -ine $member.sha256) {
            throw "Size or SHA256 mismatch: $relative"
        }
        [void]$seen.Add($relative)
    }
    if ($seen.Count -ne $expected.Count) {
        $missing = @($expected.Keys | Where-Object { -not $seen.Contains($_) })
        throw "Missing bundle file(s): $($missing -join ', ')"
    }
    [pscustomobject]@{ Root = $Root; Files = $seen.Count; Bytes = $totalBytes
        ManifestSha256 = (Get-FileHash -LiteralPath $manifestPath -Algorithm SHA256).Hash.ToLowerInvariant()
        Node = Join-Path $Root 'runtime\node\node.exe'; Entry = Join-Path $Root 'runtime\rea\scripts\rea.mjs' }
}

function ConvertTo-BlacKKingNativeArgument {
    param([AllowEmptyString()][string]$Value)
    # Windows CommandLineToArgvW quoting, including spaces, quotes and trailing slashes.
    $quoted = [regex]::Replace($Value, '(\\*)"', '$1$1\"')
    $quoted = [regex]::Replace($quoted, '(\\+)$', '$1$1')
    return '"' + $quoted + '"'
}

function Invoke-BlacKKingRea {
    param([Parameter(Mandatory = $true)]$Bundle,
        [Parameter(Mandatory = $true)][string[]]$Arguments, [string]$CodexHome,
        [switch]$NodeOnly)
    $start = New-Object Diagnostics.ProcessStartInfo
    $start.FileName = $Bundle.Node
    $nativeArguments = @()
    if (-not $NodeOnly) { $nativeArguments += $Bundle.Entry }
    $nativeArguments += $Arguments
    $start.Arguments = (($nativeArguments | ForEach-Object { ConvertTo-BlacKKingNativeArgument $_ }) -join ' ')
    $start.WorkingDirectory = $Bundle.Root
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    $start.StandardOutputEncoding = New-Object Text.UTF8Encoding($false)
    $start.StandardErrorEncoding = New-Object Text.UTF8Encoding($false)
    # Keep environment changes child-local. Never transfer ambient provider paths
    # or Node preload hooks into the portable registration.
    foreach ($key in @($start.EnvironmentVariables.Keys)) {
        if ($key -match '^(?i:REA_|GHIDRA|HOPPER)' -or
            $key -match '^(?i:NODE_OPTIONS|NODE_PATH|npm_command|npm_execpath|npm_config_user_agent|JAVA_HOME|SDKROOT)$') {
            $start.EnvironmentVariables.Remove($key)
        }
    }
    if ($CodexHome) { $start.EnvironmentVariables['CODEX_HOME'] = $CodexHome }
    $process = New-Object Diagnostics.Process
    $process.StartInfo = $start
    try {
        [void]$process.Start()
        $stdoutTask = $process.StandardOutput.ReadToEndAsync()
        $stderrTask = $process.StandardError.ReadToEndAsync()
        $process.WaitForExit()
        $stdout = $stdoutTask.GetAwaiter().GetResult()
        $stderr = $stderrTask.GetAwaiter().GetResult()
        if ($process.ExitCode -ne 0) {
            throw "Bundled CLI failed (exit $($process.ExitCode)).`n$stdout`n$stderr"
        }
        if ($stderr) { Write-Verbose $stderr }
        return $stdout
    } finally { $process.Dispose() }
}

function Test-BlacKKingCli {
    param([Parameter(Mandatory = $true)]$Bundle)
    $version = (Invoke-BlacKKingRea $Bundle @('--version') -NodeOnly).Trim()
    if ($version -cne 'v24.22.1') { throw "Expected bundled Node v24.22.1; found $version" }
    $help = Invoke-BlacKKingRea $Bundle @('--help')
    if ([string]::IsNullOrWhiteSpace($help) -or $help -notmatch '(?i)rea') { throw 'REA --help returned no recognizable help.' }
    return $version
}

if ($MyInvocation.InvocationName -ne '.') {
    try {
        $bundle = Test-BlacKKingBundle $PSScriptRoot
        $nodeVersion = Test-BlacKKingCli $bundle
        Write-Host "Verified $($bundle.Files) files / $($bundle.Bytes) bytes; Node $nodeVersion; REA --help passed."
        [pscustomobject]@{ status = 'verified'; files = $bundle.Files; bytes = $bundle.Bytes
            manifest_sha256 = $bundle.ManifestSha256; node_version = $nodeVersion; target_executed = $false }
    } catch { Write-Error $_; exit 1 }
}
