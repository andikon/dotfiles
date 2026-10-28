#Requires -Version 7.2
[CmdletBinding()]
param([switch]$Runtime)

$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false
$repositoryRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$configurationRoot = Join-Path $repositoryRoot 'config/wezterm/windows'
$scanner = Join-Path $configurationRoot 'scripts/Get-Projects.ps1'
$installer = Join-Path $repositoryRoot 'install.ps1'
$testRoot = Join-Path ([IO.Path]::GetTempPath()) ('wezterm-workflow-' + [guid]::NewGuid().ToString('N'))
$gitExecutable = (Get-Command git -CommandType Application | Select-Object -First 1).Source

function Assert([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}
function Invoke-TestGit([string[]]$Arguments) {
    $output = & $gitExecutable -c commit.gpgsign=false -c "core.hooksPath=$testRoot/empty-hooks" @Arguments 2>&1
    if ($LASTEXITCODE -ne 0) { throw "Git fixture failed: $($Arguments -join ' ')`n$output" }
}
function Remove-TestDirectory([string]$Path) {
    $resolved = [IO.Path]::GetFullPath($Path)
    $boundary = [IO.Path]::GetFullPath($testRoot)
    if ($resolved -ne $boundary -and -not $resolved.StartsWith($boundary + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing to remove a path outside the test directory: $resolved"
    }
    if (Test-Path -LiteralPath $resolved) { Remove-Item -LiteralPath $resolved -Recurse -Force }
}
function New-TestRepository([string]$Path) {
    New-Item -ItemType Directory -Path $Path -Force | Out-Null
    Invoke-TestGit @('init', '--initial-branch=main', $Path)
    Invoke-TestGit @('-C', $Path, '-c', 'user.name=WezTerm Test', '-c', 'user.email=wezterm-test@example.invalid', 'commit', '--allow-empty', '-m', 'fixture')
}
function Read-Catalog([object[]]$Roots, [int]$Depth = 4) {
    $json = & $scanner -RootsJson (ConvertTo-Json -InputObject @($Roots) -Compress) -MaxDepth $Depth
    return $json | ConvertFrom-Json
}

try {
    $code = Join-Path $testRoot 'Code'
    $first = Join-Path $code 'group one/shared'
    $second = Join-Path $code 'group two/shared'
    $external = Join-Path $testRoot "outside/feature Ü & team's worktree"
    $detached = Join-Path $code '.worktrees/detached'
    $missing = Join-Path $testRoot 'outside/missing checkout'
    New-Item -ItemType Directory -Path "$testRoot/empty-hooks" -Force | Out-Null
    New-TestRepository $first
    New-TestRepository $second
    Invoke-TestGit @('-C', $first, 'worktree', 'add', '-b', 'feature/one', $external)
    Invoke-TestGit @('-C', $first, 'worktree', 'lock', '--reason', 'fixture', $external)
    Invoke-TestGit @('-C', $first, 'worktree', 'add', '--detach', $detached)
    Invoke-TestGit @('-C', $first, 'worktree', 'add', '-b', 'gone', $missing)
    Remove-TestDirectory $missing
    $bare = Join-Path $code 'server.git'
    $bareCheckout = Join-Path $testRoot 'outside/bare checkout'
    # A local metadata copy avoids transport, credentials and hard-link assumptions.
    Copy-Item -LiteralPath (Join-Path $second '.git') -Destination $bare -Recurse
    Invoke-TestGit @('-C', $bare, 'config', 'core.bare', 'true')
    Invoke-TestGit @('-C', $bare, 'worktree', 'add', '-b', 'review', $bareCheckout)

    $catalog = Read-Catalog @($code, $code.ToUpperInvariant(), $detached, "$testRoot/absent")
    Assert ($catalog.projects.Count -eq 5) 'Expected two main checkouts, two linked worktrees and one bare-repository worktree, without duplicates.'
    Assert (@($catalog.projects.workspace | Select-Object -Unique).Count -eq 5) 'Checkout identities collided.'
    Assert (@($catalog.projects | Where-Object branch -eq 'feature/one').Count -eq 1) 'The external, locked Unicode/space/apostrophe worktree was lost.'
    Assert (@($catalog.projects | Where-Object branch -Like 'detached *').Count -eq 1) 'Detached worktree was lost.'
    Assert (@($catalog.projects | Where-Object branch -eq 'review').Count -eq 1) 'Bare-repository worktree was lost.'
    Assert (@($catalog.projects | Where-Object branch -eq 'gone').Count -eq 0) 'Missing worktree was included.'
    Assert ($catalog.warnings.Count -eq 1) 'Missing-root diagnostics were not isolated from JSON output.'
    $firstRecord = $catalog.projects | Where-Object { $_.path -eq $first.Replace('\', '/') }
    Invoke-TestGit @('-C', $first, 'branch', '-m', 'renamed-main')
    $renamed = Read-Catalog @($code)
    $renamedRecord = $renamed.projects | Where-Object { $_.path -eq $first.Replace('\', '/') }
    Assert ($renamedRecord.workspace -eq $firstRecord.workspace) 'Changing the branch changed checkout identity.'
    Assert ((Read-Catalog @($code) 0).projects.Count -eq 0) 'The discovery depth bound was ignored.'
    Assert ((Read-Catalog @("$testRoot/absent")).projects.Count -eq 0) 'An empty catalog did not serialize as an array.'
    Write-Host 'PASS: real Git discovery, external/hidden/locked/detached worktrees, bare repositories, Unicode paths, deduplication and stable identity.'

    $cacheDirectory = Join-Path $testRoot 'project-cache'
    $refresher = Join-Path $configurationRoot 'scripts/Refresh-Projects.ps1'
    $cacheFile = & $refresher -RootsJson (ConvertTo-Json -InputObject @($code) -Compress) -CacheDirectory $cacheDirectory
    $savedIndex = Get-Content -LiteralPath $cacheFile -Raw | ConvertFrom-Json
    Assert ($savedIndex.projects.Count -eq 5 -and -not $savedIndex.error) 'The persistent index did not include all worktrees.'
    $cacheLock = [IO.File]::Open("$cacheFile.lock", 'OpenOrCreate', 'ReadWrite', 'None')
    try {
        & $refresher -RootsJson (ConvertTo-Json -InputObject @($code) -Compress) -CacheFile $cacheFile
        Assert ((Get-Content -LiteralPath $cacheFile -Raw | ConvertFrom-Json).generation -eq $savedIndex.generation) 'A concurrent scan ignored the worker lock.'
    } finally { $cacheLock.Dispose() }
    $previousPath = $env:PATH
    try {
        $env:PATH = Join-Path $testRoot 'no-git-here'
        [void](& $refresher -RootsJson (ConvertTo-Json -InputObject @($code) -Compress) -CacheFile $cacheFile)
    } finally { $env:PATH = $previousPath }
    $failedIndex = Get-Content -LiteralPath $cacheFile -Raw | ConvertFrom-Json
    Assert ($failedIndex.error -and $failedIndex.projects.Count -eq 5) 'A failed refresh erased the last good catalog.'
    [void](& $refresher -RootsJson (ConvertTo-Json -InputObject @($code) -Compress) -CacheFile $cacheFile)
    Assert (@(Get-ChildItem -LiteralPath $cacheDirectory -Filter '*.tmp').Count -eq 0) 'Atomic-write temporary files were left behind.'
    Write-Host 'PASS: persistent index, concurrent-worker lock, atomic publication and last-good results after a failed refresh.'

    $portable = Join-Path $testRoot 'Portable WezTerm'
    New-Item -ItemType Directory -Path $portable -Force | Out-Null
    Set-Content -LiteralPath "$portable/wezterm.exe" -Value 'installation fixture; never executed'
    # Keep installation-time index preparation inside the disposable fixture directory.
    $previousLocalAppData = $env:LOCALAPPDATA
    $env:LOCALAPPDATA = Join-Path $testRoot 'LocalAppData'
    & $installer -Only wezterm -WezTermDirectory $portable -HomeDirectory $testRoot -WhatIf
    Assert (-not (Test-Path -LiteralPath "$portable/wezterm.lua")) '-WhatIf wrote configuration.'
    & $installer -Only wezterm -WezTermDirectory $portable -HomeDirectory $testRoot -Yes -SkipDependencies
    Assert (Test-Path -LiteralPath "$portable/scripts/Get-Projects.ps1") 'Portable scripts were not installed.'
    Set-Content -LiteralPath "$portable/local.lua" -Value 'return { opacity = 1.0 }'
    Set-Content -LiteralPath "$portable/wezterm.lua" -Value 'previous configuration'
    & $installer -Only wezterm -WezTermDirectory $portable -HomeDirectory $testRoot -Yes -SkipDependencies
    Assert (-not (Test-Path -LiteralPath "$portable/local.lua")) 'Full replacement preserved local.lua.'
    $backupRun = Get-ChildItem -LiteralPath "$testRoot/AppData/Local/dotfiles/backups" -Directory | Sort-Object CreationTime -Descending | Select-Object -First 1
    $journal = Get-Content -LiteralPath (Join-Path $backupRun.FullName 'manifest.json') -Raw | ConvertFrom-Json
    $previousConfig = $journal.Entries | Where-Object { $_.Destination -eq "$portable/wezterm.lua" -or $_.Destination -eq (Join-Path $portable 'wezterm.lua') }
    Assert ((Get-Content -LiteralPath $previousConfig.Backup -Raw).Trim() -eq 'previous configuration') 'Existing configuration was not backed up.'
    $env:LOCALAPPDATA = $previousLocalAppData
    Write-Host 'PASS: portable install, repeat install, timestamped backups, complete replacement and -WhatIf.'

    $wezterm = Get-Command wezterm -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($wezterm) {
        $bindings = & $wezterm.Source --config-file "$portable/wezterm.lua" show-keys --lua 2>&1
        Assert ($LASTEXITCODE -eq 0 -and "$bindings" -match 'LEADER') 'Installed WezTerm rejected the portable configuration.'
        Assert ("$bindings" -match "key = 't', mods = 'LEADER', action = act.TogglePaneZoomState") 'Ctrl+a t must use native zoom for the currently focused pane.'
        Write-Host 'PASS: installed WezTerm loads the portable configuration and key tables.'
    }
    $nvim = Get-Command nvim -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($nvim) {
        & $nvim.Source --headless -u NONE -l (Join-Path $PSScriptRoot 'verify-workspaces.lua')
        Assert ($LASTEXITCODE -eq 0) 'Workspace behavior checks failed.'
        & $nvim.Source --headless -u NONE -l (Join-Path $PSScriptRoot 'verify-picker-latency.lua')
        Assert ($LASTEXITCODE -eq 0) 'Picker latency checks failed.'
    } else { Write-Warning 'Neovim not found; skipped Lua workspace behavior checks.' }

    if ($Runtime) {
        if (-not $wezterm) { throw 'The runtime check requires WezTerm on PATH.' }
        & (Join-Path $PSScriptRoot 'Verify-WezTermRuntime.ps1') -ConfigurationDirectory $portable -FixtureDirectory $testRoot
    }
} finally {
    if ($previousLocalAppData) { $env:LOCALAPPDATA = $previousLocalAppData }
    Remove-TestDirectory $testRoot
}
