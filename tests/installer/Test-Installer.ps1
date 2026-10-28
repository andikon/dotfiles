#Requires -Version 5.1
$ErrorActionPreference = 'Stop'
$repo = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$entryPoint = Join-Path $repo 'install.ps1'
$fixture = Join-Path ([IO.Path]::GetTempPath()) ('dotfiles-installer-' + [guid]::NewGuid().ToString('N'))
$homeFixture = Join-Path $fixture "home with spaces & apostrophe's {test}"
function Assert([bool]$Condition, [string]$Message) { if (-not $Condition) { throw $Message } }
function Write-Fixture([string]$Path, [string]$Value) {
    New-Item -ItemType Directory -Path (Split-Path $Path -Parent) -Force | Out-Null
    [IO.File]::WriteAllText($Path, $Value)
}
function Latest-Backup([string]$HomePath) {
    return (Get-ChildItem -LiteralPath (Join-Path $HomePath 'AppData/Local/dotfiles/backups') -Directory | Sort-Object CreationTimeUtc -Descending | Select-Object -First 1).FullName
}
try {
    & $entryPoint -Only nvim -DryRun -HomeDirectory $homeFixture
    Assert (-not (Test-Path -LiteralPath $homeFixture)) 'Preview created a home or backup directory.'
    $old = Join-Path $homeFixture 'AppData/Local/nvim/obsolete.txt'
    Write-Fixture $old 'original settings'
    $vscode = Join-Path $homeFixture 'AppData/Roaming/Code/User'
    Write-Fixture (Join-Path $vscode 'unrelated.txt') 'keep me'
    Write-Fixture (Join-Path $vscode 'settings.json') '{ "old": true }'
    & $entryPoint -Only nvim,vscode -Yes -SkipDependencies -HomeDirectory $homeFixture
    Assert (-not (Test-Path -LiteralPath $old)) 'Stale Neovim file survived replacement.'
    Assert (Test-Path -LiteralPath (Join-Path $homeFixture 'AppData/Local/nvim/.') -PathType Container) 'Neovim directory missing.'
    Assert ((Get-Content -LiteralPath (Join-Path $vscode 'unrelated.txt') -Raw) -eq 'keep me') 'An unowned VS Code file changed.'
    $backup = Latest-Backup $homeFixture
    & $entryPoint -Restore $backup -Yes -HomeDirectory $homeFixture
    Assert ((Get-Content -LiteralPath $old -Raw) -eq 'original settings') 'Restore did not recover the previous directory.'
    Assert ((Get-Content -LiteralPath (Join-Path $vscode 'settings.json') -Raw) -eq '{ "old": true }') 'Restore did not recover previous file bytes.'
    Assert (-not (Test-Path -LiteralPath (Join-Path $vscode 'keybindings.json'))) 'Restore did not remove a newly installed file.'
    & $entryPoint -Restore $backup -Yes -HomeDirectory $homeFixture
    Write-Host 'PASS: read-only preview, exact replacement, shared-directory ownership, backups and repeatable restore.'

    $normalWeztermHome = Join-Path $fixture 'normal-wezterm'
    $legacyWezterm = Join-Path $normalWeztermHome '.wezterm.lua'
    Write-Fixture $legacyWezterm 'return { font_size = 19 }'
    & $entryPoint -Only wezterm -Yes -SkipDependencies -HomeDirectory $normalWeztermHome -DryRun
    Assert (Test-Path -LiteralPath $legacyWezterm) 'Preview changed the legacy WezTerm config.'
    & $entryPoint -Only wezterm -Yes -SkipDependencies -HomeDirectory $normalWeztermHome
    Assert (-not (Test-Path -LiteralPath $legacyWezterm)) 'Legacy .wezterm.lua still shadows the installed WezTerm configuration.'
    Assert (Test-Path -LiteralPath (Join-Path $normalWeztermHome '.config/wezterm/wezterm.lua')) 'Canonical WezTerm configuration was not installed.'
    & $entryPoint -Restore (Latest-Backup $normalWeztermHome) -Yes -HomeDirectory $normalWeztermHome
    Assert ((Get-Content -LiteralPath $legacyWezterm -Raw) -eq 'return { font_size = 19 }') 'Restore did not recover the legacy WezTerm config.'
    Write-Host 'PASS: normal WezTerm installation removes the shadowing legacy config with a restorable backup.'

    $portable = Join-Path $homeFixture 'Portable WezTerm'
    $portableHomeConfig = Join-Path $homeFixture '.wezterm.lua'
    Write-Fixture $portableHomeConfig 'return { font_size = 21 }'
    Write-Fixture (Join-Path $portable 'wezterm.exe') 'portable distribution fixture'
    Write-Fixture (Join-Path $portable 'local.lua') 'return { opacity = 1.0 }'
    Write-Fixture (Join-Path $portable 'scripts/obsolete.ps1') 'old script'
    Write-Fixture (Join-Path $portable 'unrelated.dll') 'application file'
    & $entryPoint -Only wezterm -Yes -SkipDependencies -HomeDirectory $homeFixture -WezTermDirectory $portable
    Assert (-not (Test-Path -LiteralPath (Join-Path $portable 'local.lua'))) 'Local override survived explicit replacement.'
    Assert (-not (Test-Path -LiteralPath (Join-Path $portable 'scripts/obsolete.ps1'))) 'A stale managed script survived.'
    Assert ((Get-Content -LiteralPath (Join-Path $portable 'unrelated.dll') -Raw) -eq 'application file') 'Portable application files changed.'
    Assert ((Get-Content -LiteralPath $portableHomeConfig -Raw) -eq 'return { font_size = 21 }') 'Portable installation changed the separate home config.'
    & $entryPoint -Restore (Latest-Backup $homeFixture) -Yes -HomeDirectory $homeFixture -WezTermDirectory $portable
    Assert (Test-Path -LiteralPath (Join-Path $portable 'local.lua')) 'Portable local override was not recoverable.'
    Write-Host 'PASS: portable WezTerm replaces config and preserves executable/library files.'

    . (Join-Path $repo 'installer/powershell/Installer.ps1')
    $context = New-DotfilesContext -Root $repo -HomeDirectory $homeFixture
    $run = New-DotfilesRun $context
    $script:failDestination = Join-Path $vscode 'keybindings.json'
    $script:failOnce = $true
    function Move-Item {
        [CmdletBinding()]
        param([string]$LiteralPath, [string]$Destination, [switch]$Force)
        if ($script:failOnce -and $Destination -eq $script:failDestination -and (Split-Path $LiteralPath -Leaf) -like '.dotfiles-stage-*') {
            $script:failOnce = $false
            throw 'Injected failure after the first target was replaced.'
        }
        Microsoft.PowerShell.Management\Move-Item -LiteralPath $LiteralPath -Destination $Destination -Force:$Force
    }
    $failed = $false
    try { Install-DotfilesTool $context $run 'vscode' } catch { $failed = $true }
    finally { Remove-Item Function:\Move-Item }
    Assert $failed 'Failure injection did not reach the second target.'
    Assert ((Get-Content -LiteralPath (Join-Path $vscode 'settings.json') -Raw) -eq '{ "old": true }') 'A failed tool transaction did not roll back its first target.'
    Assert (-not (Test-Path -LiteralPath (Join-Path $vscode 'keybindings.json'))) 'A failed transaction left a new file.'
    Assert (@(Get-ChildItem -LiteralPath $vscode -Force -Filter '.dotfiles-stage-*').Count -eq 0) 'Staging files leaked.'
    Write-Host 'PASS: failure after a partial apply rolls the complete tool back.'

    $run = New-DotfilesRun $context
    $script:failedOriginal = Join-Path $vscode 'settings.json'
    function Move-Item {
        [CmdletBinding()]
        param([string]$LiteralPath, [string]$Destination, [switch]$Force)
        if ($LiteralPath -eq $script:failedOriginal -and (Split-Path $Destination -Leaf) -eq 'previous') {
            Write-Fixture $Destination 'incomplete cross-volume copy'
            throw 'Injected failure during backup copying; original still exists.'
        }
        Microsoft.PowerShell.Management\Move-Item -LiteralPath $LiteralPath -Destination $Destination -Force:$Force
    }
    $failed = $false
    try { Install-DotfilesTool $context $run 'vscode' } catch { $failed = $true }
    finally { Remove-Item Function:\Move-Item }
    Assert $failed 'Partial backup failure was ignored.'
    Assert ((Get-Content -LiteralPath (Join-Path $vscode 'settings.json') -Raw) -eq '{ "old": true }') 'An incomplete backup replaced the intact original.'
    $run.Journal.Entries[0].Status = 'intent'
    Write-DotfilesJournal $run
    Restore-DotfilesRun $context $run.Directory $false
    Assert ((Get-Content -LiteralPath (Join-Path $vscode 'settings.json') -Raw) -eq '{ "old": true }') 'Interrupted-backup recovery replaced an intact original with partial data.'
    Write-Host 'PASS: failed or interrupted backup copies preserve the intact original.'

    $linkHome = Join-Path $fixture 'legacy-stow'
    $linkTarget = Join-Path $fixture 'original-source'
    Write-Fixture (Join-Path $linkTarget 'original.txt') 'original source must survive'
    New-Item -ItemType Directory -Path (Join-Path $linkHome 'AppData/Local') -Force | Out-Null
    $junction = Join-Path $linkHome 'AppData/Local/nvim'
    New-Item -ItemType Junction -Path $junction -Target $linkTarget | Out-Null
    & $entryPoint -Only nvim -Yes -SkipDependencies -HomeDirectory $linkHome
    Assert ((Get-Content -LiteralPath (Join-Path $linkTarget 'original.txt') -Raw) -eq 'original source must survive') 'Replacing a link modified its original target.'
    & $entryPoint -Restore (Latest-Backup $linkHome) -Yes -HomeDirectory $linkHome
    Assert ([bool]((Get-Item -LiteralPath $junction -Force).Attributes -band [IO.FileAttributes]::ReparsePoint)) 'Restore lost the original junction.'
    [IO.Directory]::Delete($junction)
    $parentLink = Join-Path $linkHome 'redirected'
    New-Item -ItemType Junction -Path $parentLink -Target $linkTarget | Out-Null
    $blocked = $false
    try { [void](Assert-DotfilesTarget (New-DotfilesContext -Root $repo -HomeDirectory $linkHome) (Join-Path $parentLink 'file')) } catch { $blocked = $true }
    Assert $blocked 'A junction in a destination parent was accepted.'
    [IO.Directory]::Delete($parentLink)
    Write-Host 'PASS: legacy links are replaced/restored without traversing their targets; linked parents are refused.'

    $invalid = $false
    try { & $entryPoint -Only does-not-exist -Yes -HomeDirectory $homeFixture } catch { $invalid = $true }
    Assert $invalid 'Unknown tool was accepted.'
    $lock = [IO.File]::Open((Join-Path $context.State 'installer.lock'), 'OpenOrCreate', 'ReadWrite', 'None')
    $blocked = $false
    try { & $entryPoint -Only nvim -Yes -SkipDependencies -HomeDirectory $homeFixture } catch { $blocked = $true }
    finally { $lock.Dispose() }
    Assert $blocked 'Concurrent install was accepted.'
    Write-Host 'PASS: invalid selections and concurrent installation are refused.'

    $previousPath = $env:PATH
    $mockBin = Join-Path $fixture 'bin'
    New-Item -ItemType Directory -Path $mockBin -Force | Out-Null
    $env:DOTFILES_PACKAGE_LOG = Join-Path $fixture 'packages.log'
    Write-Fixture (Join-Path $mockBin 'winget.cmd') "@echo off`r`necho %*>>`"%DOTFILES_PACKAGE_LOG%`"`r`nexit /b 0`r`n"
    Write-Fixture (Join-Path $mockBin 'nvim.cmd') "@echo off`r`necho NVIM v0.11.0`r`n"
    try {
        $env:PATH = $mockBin + ';' + $previousPath
        Install-DotfilesDependencies $context @('nvim')
        Assert ((Get-Content -LiteralPath $env:DOTFILES_PACKAGE_LOG -Raw) -match 'install --id Neovim.Neovim --exact --source winget --scope user') 'WinGet was not constrained to the selected package and user scope.'
        $env:PATH = $mockBin + ';' + $previousPath
        $oldStatus = Get-DotfilesStatus $context 'nvim'
        Assert (-not $oldStatus.Ready -and $oldStatus.Status -eq 'Too old') 'An old Neovim was marked compatible.'
        $missingHome = Join-Path $fixture 'skip-missing'
        & $entryPoint -Only nvim -Yes -SkipDependencies -SkipMissing -HomeDirectory $missingHome
        Assert (-not (Test-Path -LiteralPath $missingHome)) 'Skipping an incompatible tool wrote configuration or state.'
    } finally { $env:PATH = $previousPath; Remove-Item Env:\DOTFILES_PACKAGE_LOG -ErrorAction SilentlyContinue }
    Write-Host 'PASS: simulated WinGet dispatch uses user scope, and incompatible versions can be skipped.'

    $previousNoTui = $env:DOTFILES_NO_TUI
    $env:DOTFILES_NO_TUI = '1'
    $answers = New-Object 'System.Collections.Generic.Queue[string]'
    Set-Item -Path Function:\Read-Host -Value ({ param([string]$Prompt); if ($answers.Count -eq 0) { throw "Unexpected prompt: $Prompt" }; return $answers.Dequeue() }.GetNewClosure())
    try {
        $answers.Enqueue('none')
        $cancelHome = Join-Path $fixture 'cancelled'
        & $entryPoint -Only nvim -SkipDependencies -HomeDirectory $cancelHome
        Assert (-not (Test-Path -LiteralPath $cancelHome)) 'Empty selection made changes.'
        $answers.Enqueue('all'); $answers.Enqueue('no')
        & $entryPoint -Only nvim -SkipDependencies -HomeDirectory $cancelHome
        Assert (-not (Test-Path -LiteralPath $cancelHome)) 'Cancelled final confirmation made changes.'
    } finally { Remove-Item Function:\Read-Host; $env:DOTFILES_NO_TUI = $previousNoTui }
    Write-Host 'PASS: numbered selection and final confirmation can cancel without changes.'

    # Use a local ZIP and substitute HTTP calls; no network request is made.
    $snapshot = Join-Path $fixture 'snapshot'
    New-Item -ItemType Directory -Path $snapshot -Force | Out-Null
    foreach ($name in @('catalog', 'config', 'installer')) { Copy-Item -LiteralPath (Join-Path $repo $name) -Destination (Join-Path $snapshot $name) -Recurse }
    $archiveFixture = Join-Path $fixture 'snapshot.zip'
    Compress-Archive -LiteralPath $snapshot -DestinationPath $archiveFixture
    $downloadUrls = New-Object 'System.Collections.Generic.List[string]'
    Set-Item -Path Function:\Invoke-RestMethod -Value ({ param([string]$Uri, [hashtable]$Headers); $downloadUrls.Add($Uri); return @{ sha = '0000000000000000000000000000000000000001' } }.GetNewClosure())
    Set-Item -Path Function:\Invoke-WebRequest -Value ({ param([string]$Uri, [string]$OutFile, [switch]$UseBasicParsing); $downloadUrls.Add($Uri); Copy-Item -LiteralPath $archiveFixture -Destination $OutFile }.GetNewClosure())
    try {
        $remoteHome = Join-Path $fixture 'remote'
        & $entryPoint -Remote -Ref fixture-branch -Only nvim -Yes -SkipDependencies -HomeDirectory $remoteHome
        Assert (Test-Path -LiteralPath (Join-Path $remoteHome 'AppData/Local/nvim/init.lua')) 'Remote snapshot did not install.'
        Assert (@($downloadUrls | Where-Object { $_ -like '*/commits/fixture-branch' }).Count -eq 1) 'Remote revision was not resolved once.'
        Assert (@($downloadUrls | Where-Object { $_ -like '*/archive/0000000000000000000000000000000000000001.zip' }).Count -eq 1) 'Archive was not pinned to the resolved commit.'
        function Invoke-WebRequest { param([string]$Uri, [string]$OutFile, [switch]$UseBasicParsing); throw 'Simulated failed download.' }
        $failedDownload = $false
        $failedHome = Join-Path $fixture 'download-failed'
        try { & $entryPoint -Remote -Only nvim -Yes -HomeDirectory $failedHome } catch { $failedDownload = $true }
        Assert $failedDownload 'Failed remote download was ignored.'
        Assert (-not (Test-Path -LiteralPath $failedHome)) 'Failed remote download touched configurations.'
    } finally { Remove-Item Function:\Invoke-RestMethod,Function:\Invoke-WebRequest }
    Write-Host 'PASS: clone-free bootstrap uses an immutable snapshot, and download failures make no configuration changes.'

    $allHome = Join-Path $fixture 'all-windows-tools'
    $allWindowsTools = @($context.Tools | Where-Object { Test-DotfilesPlatform $_ 'windows' } | ForEach-Object id)
    & $entryPoint -Only $allWindowsTools -Yes -SkipDependencies -HomeDirectory $allHome
    Assert (Test-Path -LiteralPath (Join-Path $allHome 'Documents/PowerShell/Modules/Dev.Prompt/Dev.Prompt.psm1')) 'PowerShell modules were not staged.'
    Assert (Test-Path -LiteralPath (Join-Path $allHome '.ideavimrc')) 'The IdeaVim dotfile was not staged.'
    Assert (Test-Path -LiteralPath (Join-Path $allHome '.glzr/glazewm/config.yaml')) 'GlazeWM target was not staged.'
    Assert (Test-Path -LiteralPath (Join-Path $allHome '.glzr/zebar/andrij/default_floating.html')) 'Zebar nested assets were not staged.'
    $terminalPath = Join-Path $allHome 'AppData/Local/Packages/Microsoft.WindowsTerminal_8wekyb3d8bbwe/LocalState/settings.json'
    $terminalConfig = Get-Content -LiteralPath $terminalPath -Raw | ConvertFrom-Json
    Assert ($terminalConfig.schemes.Count -gt 0 -and $terminalConfig.actions.Count -gt 0) 'Complete Windows Terminal settings lost their scheme/actions.'
    Write-Host 'PASS: every supported Windows configuration stages independently of a checkout.'
} finally {
    $absoluteFixture = [IO.Path]::GetFullPath($fixture)
    $temporaryBoundary = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
    if ($absoluteFixture.StartsWith($temporaryBoundary, [StringComparison]::OrdinalIgnoreCase) -and (Split-Path $absoluteFixture -Leaf) -like 'dotfiles-installer-*') {
        # Remove links individually before recursively cleaning this verified temporary fixture.
        if (Test-Path -LiteralPath $absoluteFixture) {
            Get-ChildItem -LiteralPath $absoluteFixture -Recurse -Force -Attributes ReparsePoint | ForEach-Object { if ($_.PSIsContainer) { [IO.Directory]::Delete($_.FullName) } else { [IO.File]::Delete($_.FullName) } }
            Remove-Item -LiteralPath $absoluteFixture -Recurse -Force
        }
    }
}
