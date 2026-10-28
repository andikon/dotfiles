#Requires -Version 7.2
[CmdletBinding()]
param(
    [string]$RootsJson = (ConvertTo-Json -InputObject @((Join-Path $env:USERPROFILE 'Code')) -Compress),
    [ValidateRange(0, 12)][int]$MaxDepth = 4
)

$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
$git = (Get-Command git -CommandType Application -ErrorAction Stop | Select-Object -First 1).Source
$projects = [System.Collections.Generic.List[object]]::new()
$warnings = [System.Collections.Generic.List[string]]::new()
$seenRepositories = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
$seenCheckouts = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
$skip = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
@('.git', 'node_modules', 'vendor', 'target', 'dist', 'build', 'bin', 'obj', '.cache', '.venv', 'venv', '$RECYCLE.BIN') |
    ForEach-Object { [void]$skip.Add($_) }

function Normalize-Path([string]$Path) {
    $full = [IO.Path]::GetFullPath($Path).Replace('\', '/')
    # Keep drive/share roots intact.
    if ($full.Length -gt [IO.Path]::GetPathRoot($full).Length) { $full = $full.TrimEnd('/') }
    return $full
}

function Read-Worktrees([string]$Directory) {
    $common = & $git -C $Directory rev-parse --path-format=absolute --git-common-dir 2>$null
    if ($LASTEXITCODE -ne 0 -or -not $common) { return }
    $common = Normalize-Path ($common | Select-Object -First 1)
    if (-not $seenRepositories.Add($common)) { return }

    # Preserve NUL-separated fields, spaces and Unicode; never parse Git's display table.
    $output = & $git -C $Directory worktree list --porcelain -z 2>$null
    if ($LASTEXITCODE -ne 0) {
        $warnings.Add("Could not list worktrees: $Directory")
        return
    }
    $records = [System.Collections.Generic.List[hashtable]]::new()
    $record = @{}
    foreach ($field in ([string]::Join("`n", @($output)) -split "`0")) {
        if ($field.Length -eq 0) {
            if ($record.ContainsKey('worktree')) { $records.Add($record) }
            $record = @{}
            continue
        }
        $pair = $field -split ' ', 2
        $record[$pair[0]] = if ($pair.Count -eq 2) { $pair[1] } else { $true }
    }
    if ($record.ContainsKey('worktree')) { $records.Add($record) }
    if ($records.Count -eq 0) { return }

    $repositoryPath = [string]$records[0].worktree
    $repositoryName = Split-Path $repositoryPath -Leaf
    if ($repositoryName -eq '.bare') { $repositoryName = Split-Path (Split-Path $repositoryPath -Parent) -Leaf }
    $repositoryName = $repositoryName -replace '\.git$', ''

    foreach ($entry in $records) {
        if ($entry.ContainsKey('bare') -or $entry.ContainsKey('prunable')) { continue }
        $path = Normalize-Path $entry.worktree
        if (-not (Test-Path -LiteralPath $path -PathType Container) -or -not $seenCheckouts.Add($path)) { continue }
        $branch = if ($entry.branch) { $entry.branch -replace '^refs/heads/', '' }
            elseif ($entry.HEAD) { 'detached ' + $entry.HEAD.Substring(0, [Math]::Min(8, $entry.HEAD.Length)) }
            else { 'unborn' }
        $bytes = [Text.Encoding]::UTF8.GetBytes($path.ToLowerInvariant())
        $hash = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($bytes)).ToLowerInvariant()
        $projects.Add([pscustomobject]@{
            workspace = 'project:' + $hash
            path = $path
            repository = $repositoryName
            branch = $branch
            kind = if ($entry.worktree -eq $repositoryPath -and -not $records[0].ContainsKey('bare')) { 'repository' } else { 'worktree' }
        })
    }
}

$roots = @($RootsJson | ConvertFrom-Json)
foreach ($root in $roots) {
    if (-not (Test-Path -LiteralPath $root -PathType Container)) {
        $warnings.Add("Project folder not found: $root")
        continue
    }
    $pending = [System.Collections.Generic.Queue[object]]::new()
    $pending.Enqueue(@{ Path = (Normalize-Path $root); Depth = 0 })
    while ($pending.Count -gt 0) {
        $current = $pending.Dequeue()
        $marker = Join-Path $current.Path '.git'
        $isBareCandidate = (Test-Path -LiteralPath (Join-Path $current.Path 'HEAD') -PathType Leaf) -and
            (Test-Path -LiteralPath (Join-Path $current.Path 'objects') -PathType Container) -and
            (Test-Path -LiteralPath (Join-Path $current.Path 'config') -PathType Leaf)
        if ((Test-Path -LiteralPath $marker) -or $isBareCandidate) {
            Read-Worktrees $current.Path
            # Traverse grouping folders, not source/dependency trees. Git lists nested worktrees for us.
            continue
        }
        if ($current.Depth -ge $MaxDepth) { continue }
        try {
            foreach ($child in (Get-ChildItem -LiteralPath $current.Path -Directory -Force -ErrorAction Stop)) {
                if ($skip.Contains($child.Name) -or ($child.Attributes -band [IO.FileAttributes]::ReparsePoint)) { continue }
                $pending.Enqueue(@{ Path = $child.FullName; Depth = $current.Depth + 1 })
            }
        } catch {
            $warnings.Add("Could not read folder: $($current.Path)")
        }
    }
}

[pscustomobject]@{
    projects = @($projects | Sort-Object repository, branch, path)
    warnings = @($warnings)
} | ConvertTo-Json -Depth 5 -Compress
