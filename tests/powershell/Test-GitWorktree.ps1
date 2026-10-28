#Requires -Version 5.1
$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false
$root = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$modulePath = Join-Path $root 'config/powershell/windows/Modules/Dev.Git/Dev.Git.psm1'
$scriptPath = Join-Path (Split-Path $modulePath -Parent) 'New-GitWorktree.ps1'
$fixture = Join-Path ([IO.Path]::GetTempPath()) ('gwt-test-' + [guid]::NewGuid().ToString('N'))
$originalLocation = Get-Location
$previousConfig = $env:GIT_CONFIG_GLOBAL
$previousSystem = $env:GIT_CONFIG_NOSYSTEM
function Assert([bool]$Condition, [string]$Message) { if (-not $Condition) { throw $Message } }
function Invoke-FixtureGit([string[]]$Arguments) {
    $previous = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $result = @(& git -c commit.gpgsign=false -c "core.hooksPath=$fixture/empty-hooks" @Arguments 2>&1)
        $code = $LASTEXITCODE
    } finally { $ErrorActionPreference = $previous }
    if ($code -ne 0) { throw "Fixture Git failed: $result" }
    return ($result -join "`n")
}
function Expect-Failure([scriptblock]$Action, [string]$Pattern) {
    $failure = $null
    try { & $Action | Out-Null } catch { $failure = $_.ToString() }
    Assert ($failure -and $failure -match $Pattern) "Expected error '$Pattern', got '$failure'"
}
try {
    New-Item -ItemType Directory -Path $fixture | Out-Null
    $env:GIT_CONFIG_GLOBAL = Join-Path $fixture 'gitconfig'
    $env:GIT_CONFIG_NOSYSTEM = '1'
    Set-Content -LiteralPath $env:GIT_CONFIG_GLOBAL -Value "[user]`n name = Worktree Test`n email = test@example.invalid`n[core]`n hooksPath = $($fixture.Replace('\','/'))/empty-hooks"
    Import-Module $modulePath -Force -DisableNameChecking
    Set-Location -LiteralPath $fixture
    Expect-Failure { gwt outside } 'inside a Git checkout'
    $repo = Join-Path $fixture "repo $([char]0x00dc) space & apostrophe's"
    $null = Invoke-FixtureGit @('init', '--initial-branch=main', $repo)
    Set-Location -LiteralPath $repo
    $null = Invoke-FixtureGit @('commit', '--allow-empty', '-m', 'initial')
    $initial = Invoke-FixtureGit @('rev-parse', 'HEAD')
    $null = Invoke-FixtureGit @('branch', 'existing')
    New-Item -ItemType Directory -Path (Join-Path $repo 'sub') | Out-Null
    Set-Location -LiteralPath (Join-Path $repo 'sub')
    $first = gwt feature/login
    Assert (Test-Path -LiteralPath (Join-Path $first.Path '.git')) 'New worktree missing'
    Assert ($first.Path -eq (Join-Path ($repo + '.worktrees') 'feature-login')) 'Destination must be beside the main checkout'
    Assert ((Get-Location).Path -eq (Join-Path $repo 'sub')) 'Creation moved the caller without -Enter'
    Assert ((Invoke-FixtureGit @('-C', $first.Path, 'branch', '--show-current')) -eq 'feature/login') 'New branch was not checked out'
    $existingTree = gwt -Existing existing
    Assert ((Invoke-FixtureGit @('-C', $existingTree.Path, 'branch', '--show-current')) -eq 'existing') 'Existing branch was detached'
    Expect-Failure { gwt -Existing existing } ([regex]::Escape($existingTree.Path.Replace('\', '/')))
    Expect-Failure { gwt feature/login } 'already exists'
    Expect-Failure { gwt 'invalid..branch' } 'Invalid branch'
    Expect-Failure { gwt -Existing missing } 'does not exist'
    Expect-Failure { gwt invalid-base -Base origin/missing } 'Git failed'
    $null = gwt preview -WhatIf
    Assert (-not (Test-Path -LiteralPath (Join-Path ($repo + '.worktrees') 'preview'))) 'WhatIf created files'
    & git show-ref --verify --quiet refs/heads/preview
    Assert ($LASTEXITCODE -ne 0) 'WhatIf created a branch'
    $occupied = Join-Path $fixture 'occupied'
    New-Item -ItemType Directory $occupied | Out-Null
    Expect-Failure { gwt occupied -Path $occupied } 'Destination already exists'
    $null = gwt collision/one
    Expect-Failure { gwt collision-one } 'Destination already exists'
    Set-Location -LiteralPath $first.Path
    $fromLinked = gwt linked -Base main -Path (Join-Path $fixture 'custom destination') -Enter
    Assert ((Get-Location).Path -eq $fromLinked.Path) '-Enter did not change the current shell'
    Assert ((Invoke-FixtureGit @('rev-parse', 'HEAD')) -eq $initial) 'Local base resolved incorrectly'

    # A local bare remote exercises real fetch/ref behavior without network access.
    $remote = Join-Path $fixture 'remote.git'
    $null = Invoke-FixtureGit @('init', '--bare', $remote)
    Set-Location -LiteralPath $repo
    $null = Invoke-FixtureGit @('remote', 'add', 'origin', $remote)
    $reviewCommit = Invoke-FixtureGit @('commit-tree', 'HEAD^{tree}', '-p', $initial, '-m', 'remote review')
    $null = Invoke-FixtureGit @('push', 'origin', ($reviewCommit + ':refs/heads/feature/review'))
    $null = Invoke-FixtureGit @('update-ref', '-d', 'refs/remotes/origin/feature/review')
    $null = gwt fetch-preview -Base main -Fetch -WhatIf
    & git show-ref --verify --quiet refs/remotes/origin/feature/review
    Assert ($LASTEXITCODE -ne 0) 'WhatIf fetched remote refs'
    $review = gwt review/pr-123 -Base origin/feature/review -Fetch
    Assert ((Invoke-FixtureGit @('-C', $review.Path, 'rev-parse', 'HEAD')) -eq $reviewCommit) 'Remote base commit was not used'
    Assert ((Invoke-FixtureGit @('-C', $review.Path, 'branch', '--show-current')) -eq 'review/pr-123') 'Review worktree is not on a new local branch'
    $standalone = & $scriptPath standalone -Base main
    Assert (Test-Path -LiteralPath $standalone.Path) 'Standalone script failed'

    # Drive the actual interactive prompts, including remote branch selection and cancel.
    $global:TestGwtAnswers = [Collections.Generic.Queue[string]]::new()
    function global:Read-Host { param($Prompt) if ($global:TestGwtAnswers.Count -eq 0) { throw "Unexpected prompt: $Prompt" }; $global:TestGwtAnswers.Dequeue() }
    foreach ($answer in @('n', '1', 'review/interactive', '3', '1', '', 'y')) { $global:TestGwtAnswers.Enqueue($answer) }
    $interactive = & $scriptPath
    Assert ($interactive.Branch -eq 'review/interactive') 'Interactive remote creation failed'
    Assert ($global:TestGwtAnswers.Count -eq 0) 'Interactive wizard skipped expected prompts'
    foreach ($answer in @('n', '')) { $global:TestGwtAnswers.Enqueue($answer) }
    $cancelled = & $scriptPath
    Assert ($null -eq $cancelled) 'Cancellation returned a created worktree'
    Write-Host 'PASS: gwt local/new/existing/remote branches, fetch, prompts, cancellation, subdirectories, linked worktrees, path conflicts, preview and standalone use.'
} finally {
    Remove-Item Function:\Read-Host -ErrorAction SilentlyContinue
    Remove-Variable TestGwtAnswers -Scope Global -ErrorAction SilentlyContinue
    Set-Location -LiteralPath $originalLocation.Path
    $env:GIT_CONFIG_GLOBAL = $previousConfig
    $env:GIT_CONFIG_NOSYSTEM = $previousSystem
    Remove-Module Dev.Git -ErrorAction SilentlyContinue
    $resolved = [IO.Path]::GetFullPath($fixture)
    $tempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\') + '\'
    if ($resolved.StartsWith($tempRoot, [StringComparison]::OrdinalIgnoreCase) -and (Split-Path $resolved -Leaf) -like 'gwt-test-*') {
        if (Test-Path -LiteralPath $resolved) { Remove-Item -LiteralPath $resolved -Recurse -Force }
    } else { throw 'Unexpected fixture cleanup path' }
}
