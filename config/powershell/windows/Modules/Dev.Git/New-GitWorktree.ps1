#Requires -Version 5.1
<#
.SYNOPSIS
Creates a Git worktree from the current checkout, with optional interactive prompts.
.EXAMPLE
gwt review/pr-123 -Base origin/feature/login -Fetch
#>
[CmdletBinding(SupportsShouldProcess, DefaultParameterSetName = 'New')]
param(
    [Parameter(Position = 0, ParameterSetName = 'New')][string]$Branch,
    [Parameter(ParameterSetName = 'New')][string]$Base = 'HEAD',
    [Parameter(Mandatory, ParameterSetName = 'Existing')][string]$Existing,
    [string]$Path,
    [switch]$Fetch,
    [switch]$Enter
)

$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false
$git = (Get-Command git -CommandType Application -ErrorAction Stop | Select-Object -First 1).Source

function Invoke-WorktreeGit([string[]]$GitArguments, [switch]$AllowFailure) {
    # Windows PowerShell turns native stderr into ErrorRecords even on successful Git operations.
    $previousPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $lines = @(& $git @GitArguments 2>&1)
        $code = $LASTEXITCODE
    } finally { $ErrorActionPreference = $previousPreference }
    $text = ($lines | ForEach-Object { $_.ToString() }) -join "`n"
    if ($code -ne 0 -and -not $AllowFailure) { throw "Git failed: $text" }
    return [pscustomobject]@{ Code = $code; Text = $text }
}

function Select-WorktreeItem([string]$Title, [string[]]$Items) {
    if ($Items.Count -eq 0) { throw "No choices available: $Title" }
    Write-Host "`n$Title" -ForegroundColor Cyan
    for ($i = 0; $i -lt $Items.Count; $i++) {
        Write-Host ('  {0}. {1}' -f ($i + 1), ($Items[$i] -replace '^refs/(heads|remotes)/', ''))
    }
    while ($true) {
        $answer = Read-Host 'Number (blank cancels)'
        if ([string]::IsNullOrWhiteSpace($answer)) { return $null }
        $number = 0
        if ([int]::TryParse($answer, [ref]$number) -and $number -ge 1 -and $number -le $Items.Count) { return $Items[$number - 1] }
        Write-Host 'Choose one of the listed numbers.' -ForegroundColor Yellow
    }
}

if ($PWD.Provider.Name -ne 'FileSystem' -or
    (Invoke-WorktreeGit @('rev-parse', '--is-inside-work-tree') -AllowFailure).Text -ne 'true') {
    throw 'Run gwt inside a Git checkout or one of its subdirectories.'
}
$interactive = -not $Branch -and -not $Existing
if ($interactive -and $WhatIfPreference) { Write-Host 'Preview: specify a branch, for example gwt feature/login -WhatIf.'; return }
if ($interactive) {
    Write-Host "`nGit worktree" -ForegroundColor Cyan
    if (-not $Fetch) { $Fetch = (Read-Host 'Fetch remote branches first? [y/N]') -match '^(?i)y(es)?$' }
}
if ($Fetch -and $PSCmdlet.ShouldProcess('Git remotes', 'Fetch remote branches')) {
    $null = Invoke-WorktreeGit @('fetch', '--all')
}
if ($interactive) {
    $mode = Select-WorktreeItem 'Create a worktree using' @('New branch', 'Existing local branch')
    if (-not $mode) { return }
    if ($mode -eq 'Existing local branch') {
        $locals = (Invoke-WorktreeGit @('for-each-ref', '--format=%(refname:short)', 'refs/heads')).Text
        $Existing = Select-WorktreeItem 'Local branch' @($locals -split "`n" | Where-Object { $_ })
        if (-not $Existing) { return }
    } else {
        $Branch = Read-Host 'New branch name (blank cancels)'
        if ([string]::IsNullOrWhiteSpace($Branch)) { return }
        $source = Select-WorktreeItem 'Start the new branch from' @('Current HEAD', 'Local branch', 'Remote branch')
        if (-not $source) { return }
        if ($source -ne 'Current HEAD') {
            $prefix = if ($source -eq 'Local branch') { 'refs/heads' } else { 'refs/remotes' }
            # Symbolic remote HEAD aliases are not branches.
            $refs = (Invoke-WorktreeGit @('for-each-ref', '--format=%(refname) %(symref)', $prefix)).Text
            $choices = @($refs -split "`n" | Where-Object { $_ -and $_.EndsWith(' ') } | ForEach-Object { $_.TrimEnd() })
            $Base = Select-WorktreeItem $source $choices
            if (-not $Base) { return }
        } else { $Base = 'HEAD' }
    }
}

$name = if ($Existing) { $Existing } else { $Branch }
if ((Invoke-WorktreeGit @('check-ref-format', '--branch', $name) -AllowFailure).Code -ne 0) { throw "Invalid branch name: $name" }
$localRef = 'refs/heads/' + $name
$exists = (Invoke-WorktreeGit @('show-ref', '--verify', '--quiet', $localRef) -AllowFailure).Code -eq 0
if ($Existing -and -not $exists) { throw "Local branch '$name' does not exist. Use a new branch with -Base origin/branch for a remote branch." }
if (-not $Existing -and $exists) { throw "Local branch '$name' already exists. Use gwt -Existing '$name'." }

$listing = (Invoke-WorktreeGit @('-c', 'core.quotePath=false', 'worktree', 'list', '--porcelain', '-z')).Text
$main = $null
$worktreePath = $null
foreach ($field in ($listing -split "`0")) {
    if ($field.StartsWith('worktree ')) {
        $worktreePath = $field.Substring(9)
        if (-not $main) { $main = $worktreePath }
    } elseif ($Existing -and $field -eq ('branch ' + $localRef)) {
        throw "Branch '$name' is already checked out at $worktreePath"
    }
}
if (-not $main) { throw 'Git did not report a main worktree.' }
$commit = if ($Existing) { $Existing } else { (Invoke-WorktreeGit @('rev-parse', '--verify', '--end-of-options', ($Base + '^{commit}'))).Text }
if (-not $Path) {
    $slug = ($name -replace '[<>:"/\\|?*\x00-\x1f]', '-').TrimEnd('.', ' ')
    if (-not $slug -or $slug -match '^(?i)(CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])(\..*)?$') { throw 'Specify -Path for this branch name; it cannot be used as a Windows folder name.' }
    $Path = Join-Path ($main + '.worktrees') $slug
}
if (-not [IO.Path]::IsPathRooted($Path)) { $Path = Join-Path $PWD.ProviderPath $Path }
$destination = [IO.Path]::GetFullPath($Path)
if ($interactive) {
    $override = Read-Host "Destination [$destination] (blank accepts)"
    if ($override) {
        if (-not [IO.Path]::IsPathRooted($override)) { $override = Join-Path $PWD.ProviderPath $override }
        $destination = [IO.Path]::GetFullPath($override)
    }
}
if (Test-Path -LiteralPath $destination) { throw "Destination already exists: $destination. Choose another -Path." }
Write-Host ("`nBranch: {0}`nSource: {1}`nDestination: {2}" -f $name, $(if ($Existing) { 'existing local branch' } else { $Base }), $destination)
if ($interactive -and (Read-Host 'Create this worktree? [y/N]') -notmatch '^(?i)y(es)?$') { return }
if (-not $PSCmdlet.ShouldProcess($destination, "Create worktree for $name")) { return }
$arguments = @('worktree', 'add')
if (-not $Existing) { $arguments += @('-b', $name) }
$arguments += @('--', $destination, $commit)
$null = Invoke-WorktreeGit $arguments
if ($Enter) { Set-Location -LiteralPath $destination }
[pscustomobject]@{ Branch = $name; Path = $destination; Base = $(if ($Existing) { $localRef } else { $Base }) }
