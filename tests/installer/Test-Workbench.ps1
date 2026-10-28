#Requires -Version 5.1
$ErrorActionPreference = 'Stop'
$repo = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
. (Join-Path $repo 'installer/powershell/Installer.ps1')
$realApply = ${function:Invoke-DotfilesApply}
$fixture = Join-Path ([IO.Path]::GetTempPath()) ('dotfiles-workbench-' + [guid]::NewGuid().ToString('N'))
$previousPath = $env:PATH
function Assert([bool]$Condition, [string]$Message) { if (-not $Condition) { throw $Message } }
function Key([string]$Name, [string]$Character = '') { return [pscustomobject]@{ Key = $Name; Character = $Character; Control = $false } }

# The fake inventory uses the real catalog and filesystem targets, with no external program execution.
function Get-DotfilesStatus($Context, [string]$Id) {
    return [pscustomobject]@{ Id = $Id; Ready = ($Id -ne 'rg'); Status = $(if ($Id -eq 'rg') { 'Not found' } else { 'Installed' }); Detail = $(if ($Id -eq 'rg') { 'Install ripgrep for editor search.' } else { "test executable: $Id" }) }
}
function New-State([string]$Name = 'home', [bool]$Preview = $true) {
    $context = New-DotfilesContext -Root $repo -HomeDirectory (Join-Path $fixture $Name)
    $tools = @($context.Tools | Where-Object { $_.id -in @('nvim','wezterm','powershell') })
    $state = New-DotfilesWorkbenchState $context $tools $false $false $Preview
    Update-DotfilesWorkbenchInventory $state
    return $state
}
try {
    $mockBin = Join-Path $fixture 'bin'
    New-Item -ItemType Directory -Path $mockBin -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $mockBin 'winget.cmd') -Value '@exit /b 0'
    $env:PATH = $mockBin + ';' + $previousPath
    $state = New-State
    Assert (-not (Test-Path -LiteralPath $state.Context.Home)) 'Scanning or planning created the temporary home.'
    Assert (-not $state.ConfigChosen.nvim -and $state.ConfigChosen.wezterm) 'Missing requirements did not affect default selections.'
    Update-DotfilesWorkbenchState $state (Key Enter)
    Assert ($state.Page -eq 1) 'Inspection did not advance to its own dependency page.'
    Update-DotfilesWorkbenchState $state (Key DownArrow)
    Update-DotfilesWorkbenchState $state (Key Spacebar)
    Assert ($state.Mode -eq 'install') 'Software radio selection failed.'
    Assert ($state.PackageChosen.rg) 'Required missing package was not selected by default.'
    Assert $state.ConfigChosen.nvim 'A queued dependency did not make its config eligible for default selection.'
    Update-DotfilesWorkbenchState $state (Key Enter)
    Assert ($state.Page -eq 2) 'Configuration selection has no separate page.'
    $before = @(Get-DotfilesWorkbenchSelected $state).Count
    Update-DotfilesWorkbenchState $state (Key Spacebar)
    Assert (@(Get-DotfilesWorkbenchSelected $state).Count -eq $before - 1) 'Space did not toggle a configuration.'
    Update-DotfilesWorkbenchState $state (Key Backspace)
    Update-DotfilesWorkbenchState $state (Key Enter)
    Assert (@(Get-DotfilesWorkbenchSelected $state).Count -eq $before - 1) 'Back navigation lost an explicit selection.'
    Update-DotfilesWorkbenchState $state (Key Enter)
    Assert ($state.Page -eq 3 -and -not $state.ApplyRequested) 'Entering Review applied changes.'
    Assert (-not (Test-Path -LiteralPath $state.Context.Home)) 'Navigating pages mutated settings or installed packages.'
    Update-DotfilesWorkbenchState $state (Key RightArrow)
    Assert (-not $state.ApplyRequested) 'Right arrow accidentally applied the review.'
    Update-DotfilesWorkbenchState $state (Key Enter)
    Assert $state.ApplyRequested 'Review confirmation did not request application.'
    Write-Host 'PASS: inspection, queued dependencies, remembered selections and review-only application.'

    $packageAttempt = Invoke-DotfilesApply -Context $state.Context -Selected @() -Packages @('rg') -NonInteractive
    Assert ($packageAttempt.PackageResults.Count -eq 1 -and -not $packageAttempt.PackageResults[0].Success) 'A successful package command incorrectly satisfied a still-missing executable.'
    Write-Host 'PASS: queued package results recheck actual requirements instead of trusting a process exit code.'

    $state = New-State 'skip'
    $state.Page = 1; $state.Cursor[1] = 2
    Update-DotfilesWorkbenchState $state (Key Spacebar)
    Assert ($state.Mode -eq 'skip' -and -not $state.ConfigChosen.nvim) 'Skip mode selected an unavailable configuration.'
    $state.Page = 2
    Update-DotfilesWorkbenchState $state (Key A)
    Assert (-not $state.ConfigChosen.nvim) 'Select-all bypassed missing-requirement exclusions.'
    Update-DotfilesWorkbenchState $state (Key Escape)
    Update-DotfilesWorkbenchState $state (Key Enter)
    Assert (-not $state.Exit -and -not $state.Dialog) 'Cancel dialog did not default to keep editing.'
    Update-DotfilesWorkbenchState $state (Key Escape)
    Update-DotfilesWorkbenchState $state (Key RightArrow)
    Update-DotfilesWorkbenchState $state (Key Enter)
    Assert ($state.Exit -and $state.Cancelled) 'Explicit cancel did not exit.'
    Assert (-not (Test-Path -LiteralPath $state.Context.Home)) 'Cancellation created state or configuration.'
    Write-Host 'PASS: skip rules, select-all and cancellation preserve settings.'

    $state = New-State 'geometry'
    foreach ($size in @(@(120,36),@(80,24),@(72,22),@(45,14))) {
        foreach ($page in 0..4) {
            $state.Page = $page
            $frame = New-DotfilesWorkbenchFrame $state $size[0] $size[1]
            Assert ($frame.Rows.Count -eq $size[1]) 'A frame exceeded its terminal height.'
            foreach ($row in $frame.Rows) {
                Assert ($row.Cells.Count -eq $size[0]) 'A frame exceeded its terminal width.'
                Assert ($row.Roles.Count -eq $size[0]) 'Color spans have the wrong geometry.'
            }
        }
    }
    $state.Page = 0; $state.Cursor[0] = 11
    $frame = New-DotfilesWorkbenchFrame $state 80 24
    Assert ($state.Scroll[0] -gt 0) 'The focused item did not scroll into view.'
    $state.Page = 2; $state.Cursor[2] = 1; $state.DetailsFocused = $true
    $frame = New-DotfilesWorkbenchFrame $state 80 24
    Assert ((Get-DotfilesCanvasLines $frame | Out-String) -match 'DESTINATION') 'Compact terminals cannot display selected-tool details.'
    $state.Page = 4; $state.Complete = $true; $state.Results = @([pscustomobject]@{ Id = 'wezterm'; Success = $false; Message = 'A meaningful failure diagnostic.' })
    Update-DotfilesWorkbenchState $state (Key Backspace)
    Assert ($state.Page -eq 4) 'Completed setup could return to an editable review.'
    Update-DotfilesWorkbenchState $state (Key Tab)
    Assert (-not $state.DetailsFocused) 'Completed results do not allow details navigation.'
    $unicode = New-DotfilesCanvas 12 3
    Set-DotfilesCanvasText $unicode 1 1 ('A' + [char]0x4e2d + 'B' + [char]0x301) 2 6
    Assert ($unicode.Rows[1].Cells[3] -eq '') 'Wide text did not reserve its second terminal cell.'
    Set-DotfilesCanvasText $unicode 0 0 ("$([char]27)[31munsafe$([char]27)[0m") 0
    Assert ((-join $unicode.Rows[0].Cells) -notmatch '\[31m') 'Native program color sequences leaked into the frame.'
    Write-Host 'PASS: all pages fit large/compact terminals, scrolling works, and wide/colored text stays within cells.'

    # Exercise the complete real wizard with a scripted console adapter.
    $script:events = New-Object 'System.Collections.Generic.Queue[object]'
    $script:closed = $false; $script:frames = New-Object 'System.Collections.Generic.List[string]'
    function Start-DotfilesWorkbench { return [pscustomobject]@{ Size = [pscustomobject]@{ Width = 100; Height = 30 }; LastRows = @() } }
    function Stop-DotfilesWorkbench($Session) { $script:closed = $true }
    function Get-DotfilesTerminalSize { return [pscustomobject]@{ Width = 100; Height = 30 } }
    function Write-DotfilesWorkbenchFrame($Session, $Canvas) { $script:frames.Add((Get-DotfilesCanvasLines $Canvas | Out-String)) }
    function Read-DotfilesWorkbenchEvent($Session) {
        if (-not $script:events.Count) { throw 'The wizard requested unexpected additional input.' }
        return $script:events.Dequeue()
    }
    function Set-DotfilesTerminalControlC([bool]$TreatAsInput) { }
    $script:applyCalls = 0
    function Invoke-DotfilesApply { param($Context, $Selected, $Packages, [switch]$NonInteractive, [scriptblock]$OnProgress); $script:applyCalls++; throw 'Preview called the real apply engine.' }
    foreach ($key in @('Enter','Enter','Enter','Enter','Enter')) { $script:events.Enqueue((Key $key)) }
    $state = New-State 'preview-loop'
    $preview = Invoke-DotfilesWorkbench -Context $state.Context -Tools $state.Tools -SkipDependencies $true -SkipMissing $false -DryRun $true
    Assert ($preview.Preview -and $script:closed) 'Preview did not restore the console session.'
    Assert ($script:applyCalls -eq 0 -and -not (Test-Path -LiteralPath $state.Context.Home)) 'Preview invoked mutations.'
    Assert (@($script:frames | Where-Object { $_ -match 'PREVIEW COMPLETE' }).Count -gt 0) 'Completion was not rendered as its own page.'
    $script:closed = $false
    $script:events.Enqueue((Key Escape)); $script:events.Enqueue((Key RightArrow)); $script:events.Enqueue((Key Enter))
    $cancel = Invoke-DotfilesWorkbench -Context $state.Context -Tools $state.Tools -SkipDependencies $true -SkipMissing $false -DryRun $false
    Assert ($cancel.Cancelled -and $script:closed -and $script:applyCalls -eq 0) 'Cancel failed to restore the console without applying.'
    $script:closed = $false
    $script:events.Enqueue((Key Enter))
    $failed = $false
    try { Invoke-DotfilesWorkbench -Context $state.Context -Tools $state.Tools -SkipDependencies $true -SkipMissing $false -DryRun $true | Out-Null } catch { $failed = $true }
    Assert ($failed -and $script:closed) 'A failed input loop did not restore its console session.'
    Write-Host 'PASS: the full wizard previews and cancels without mutation, and restores its session on errors.'

    $script:closed = $false; $script:applyCalls = 0
    Set-Item -Path Function:\Invoke-DotfilesApply -Value $realApply
    $script:events.Clear()
    foreach ($key in @('Enter','Enter','Enter','Enter','Enter')) { $script:events.Enqueue((Key $key)) }
    $state = New-State 'apply-loop' $false
    $applied = Invoke-DotfilesWorkbench -Context $state.Context -Tools $state.Tools -SkipDependencies $true -SkipMissing $false -DryRun $false
    Assert ($script:closed -and @($applied.Results | Where-Object { -not $_.Success }).Count -eq 0) 'A confirmed wizard apply failed or left its session open.'
    Assert (Test-Path -LiteralPath (Join-Path $state.Context.Home '.config/wezterm/wezterm.lua')) 'The confirmed wizard did not install selected settings.'
    Assert (-not (Test-Path -LiteralPath (Join-Path $state.Context.Home 'AppData/Local/nvim'))) 'The wizard installed an unselected unavailable configuration.'
    Assert ($applied.Run -and (Test-Path -LiteralPath $applied.Run.Manifest)) 'Wizard application did not use the normal backup journal.'
    Write-Host 'PASS: confirmed Workbench application uses the real installer and backup engine in a temporary home.'
} finally {
    $env:PATH = $previousPath
    $absolute = [IO.Path]::GetFullPath($fixture)
    $boundary = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\','/') + [IO.Path]::DirectorySeparatorChar
    if ($absolute.StartsWith($boundary, [StringComparison]::OrdinalIgnoreCase) -and (Split-Path $absolute -Leaf) -like 'dotfiles-workbench-*' -and (Test-Path -LiteralPath $absolute)) { Remove-Item -LiteralPath $absolute -Recurse -Force }
}
