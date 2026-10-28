#Requires -Version 7.2
[CmdletBinding()]
param([switch]$Runtime)

$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false
$windowsRoot = Split-Path $PSScriptRoot -Parent
$scanner = Join-Path $windowsRoot 'wezterm/scripts/Get-Projects.ps1'
$installer = Join-Path $windowsRoot 'install.ps1'
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

    $portable = Join-Path $testRoot 'Portable WezTerm'
    New-Item -ItemType Directory -Path $portable -Force | Out-Null
    Set-Content -LiteralPath "$portable/wezterm.exe" -Value 'installation fixture; never executed'
    & $installer -Only WezTerm -WezTermDirectory $portable -WhatIf
    Assert (-not (Test-Path -LiteralPath "$portable/wezterm.lua")) '-WhatIf wrote configuration.'
    & $installer -Only WezTerm -WezTermDirectory $portable
    Assert (Test-Path -LiteralPath "$portable/scripts/Get-Projects.ps1") 'Portable scripts were not installed.'
    Set-Content -LiteralPath "$portable/local.lua" -Value 'return { opacity = 1.0 }'
    Set-Content -LiteralPath "$portable/wezterm.lua" -Value 'previous configuration'
    & $installer -Only WezTerm -WezTermDirectory $portable
    Assert ((Get-Content -LiteralPath "$portable/local.lua" -Raw).Trim() -eq 'return { opacity = 1.0 }') 'Reinstall overwrote local.lua.'
    Assert ((Get-Content -LiteralPath "$portable/wezterm.lua.bak" -Raw).Trim() -eq 'previous configuration') 'Existing configuration was not backed up.'
    Write-Host 'PASS: portable install, repeat install, backups, preserved overrides and -WhatIf.'

    $wezterm = Get-Command wezterm -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($wezterm) {
        $bindings = & $wezterm.Source --config-file "$portable/wezterm.lua" show-keys --lua 2>&1
        Assert ($LASTEXITCODE -eq 0 -and "$bindings" -match 'LEADER') 'Installed WezTerm rejected the portable configuration.'
        Write-Host 'PASS: installed WezTerm loads the portable configuration and key tables.'
    }
    $nvim = Get-Command nvim -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($nvim) {
        & $nvim.Source --headless -u NONE -l (Join-Path $PSScriptRoot 'verify-workspaces.lua')
        Assert ($LASTEXITCODE -eq 0) 'Workspace behavior checks failed.'
    } else { Write-Warning 'Neovim not found; skipped Lua workspace behavior checks.' }

    if ($Runtime) {
        if (-not $wezterm) { throw 'The runtime check requires WezTerm on PATH.' }
        & (Join-Path $PSScriptRoot 'Verify-WezTermRuntime.ps1') -ConfigurationDirectory $portable -FixtureDirectory $testRoot
    }
} finally {
    Remove-TestDirectory $testRoot
}
