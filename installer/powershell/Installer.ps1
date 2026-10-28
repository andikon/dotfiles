. (Join-Path $PSScriptRoot 'Catalog.ps1')
. (Join-Path $PSScriptRoot 'Transaction.ps1')
. (Join-Path $PSScriptRoot 'Interface.ps1')
. (Join-Path $PSScriptRoot 'Apply.ps1')
. (Join-Path $PSScriptRoot 'Workbench.ps1')

function Invoke-DotfilesInstaller {
    [CmdletBinding()]
    param(
        [string]$Root, [string[]]$Only, [bool]$Yes, [bool]$SkipDependencies,
        [bool]$SkipMissing, [bool]$DryRun, [bool]$Plain, [string]$HomeDirectory,
        [string]$WezTermDirectory, [string]$VSCodeDirectory, [string]$TerminalDirectory, [string]$Restore
    )
    if ([Environment]::OSVersion.Platform -ne 'Win32NT') { throw 'Use install.sh on macOS and Linux.' }
    $aliases = @{ Neovim = 'nvim'; WindowsTerminal = 'windows-terminal'; All = '*' }
    $requested = @($Only | Where-Object { $_ } | ForEach-Object { $_ -split ',' } | Where-Object { $_.Trim() } | ForEach-Object { $_ = $_.Trim(); if ($aliases.ContainsKey($_)) { $aliases[$_] } else { $_.ToLowerInvariant() } })
    if ($requested -contains '*') { $requested = @() }
    if ($Yes -and $requested.Count -eq 0 -and -not $Restore) { throw '-Yes requires an explicit -Only list.' }
    $context = New-DotfilesContext -Root $Root -HomeDirectory $HomeDirectory -WezTermDirectory $WezTermDirectory -VSCodeDirectory $VSCodeDirectory -TerminalDirectory $TerminalDirectory
    $tools = @($context.Tools | Where-Object { Test-DotfilesPlatform $_ 'windows' })
    foreach ($id in $requested) { if ($id -notin $tools.id) { throw "Unknown or unsupported Windows tool: $id" } }
    if ($requested.Count) { $tools = @($tools | Where-Object { $_.id -in $requested }) }
    $lock = $null
    try {
        if ($Restore) {
            if (-not $DryRun -and -not $Yes -and (Read-Host 'Restore this backup? Type yes') -ne 'yes') { Write-Host 'Cancelled.'; return }
            if (-not $DryRun) {
                New-Item -ItemType Directory -Path $context.State -Force | Out-Null
                $lock = [IO.File]::Open((Join-Path $context.State 'installer.lock'), 'OpenOrCreate', 'ReadWrite', 'None')
            }
            Restore-DotfilesRun $context $Restore $DryRun
            return
        }
        if (-not $Yes -and -not $Plain -and (Test-DotfilesWorkbenchAvailable)) {
            $outcome = Invoke-DotfilesWorkbench -Context $context -Tools $tools -SkipDependencies $SkipDependencies -SkipMissing $SkipMissing -DryRun $DryRun
            if ($outcome.Cancelled) { Write-Host 'Setup cancelled. No pending changes were applied.'; return }
            if ($outcome.Preview) { Write-Host 'Preview complete. No software, configurations or backups changed.'; return }
            foreach ($result in @($outcome.Results) + @($outcome.PackageResults)) {
                if ($result.Success) { Write-Host "INSTALLED: $($result.Id)" -ForegroundColor Green }
                else { Write-Warning "FAILED: $($result.Id). $($result.Message)" }
            }
            if ($outcome.Run) { Write-Host "Backup run: $($outcome.Run.Directory)" }
            if (@($outcome.Results + $outcome.PackageResults | Where-Object { -not $_.Success }).Count) { throw 'Setup finished with failures; see the results above.' }
            return
        }
        Write-Host "`nDotfiles - Windows" -ForegroundColor Cyan
        Write-Host '1/4 - Tools and dependencies'
        $statuses = @{}
        foreach ($tool in $tools) {
            $statuses[$tool.id] = Get-DotfilesStatus $context $tool.id
            Write-DotfilesStatus $statuses[$tool.id] $tool.label
            foreach ($id in @($tool.required -split ',' | Where-Object { $_ -ne '-' })) {
                if (-not $statuses.ContainsKey($id)) { $statuses[$id] = Get-DotfilesStatus $context $id }
                Write-DotfilesStatus $statuses[$id] $id '  required: '
            }
            foreach ($id in @($tool.optional -split ',' | Where-Object { $_ -ne '-' })) {
                if (-not $statuses.ContainsKey($id)) { $statuses[$id] = Get-DotfilesStatus $context $id }
                Write-DotfilesStatus $statuses[$id] $id '  optional: '
            }
        }
        Write-Host "`n2/4 - Missing dependencies" -ForegroundColor Cyan
        $missing = @($statuses.Keys | Where-Object { -not $statuses[$_].Ready } | Sort-Object)
        $chosenPackages = @()
        if ($missing.Count -and -not $SkipDependencies -and -not $Yes -and -not $DryRun) {
            Write-Host '1. Install selected missing dependencies'
            Write-Host '2. I will handle dependencies myself (default)'
            Write-Host '3. Skip tools with missing requirements'
            $choice = Read-Host 'Choose 1, 2, or 3'
            if ($choice -eq '1') {
                $requiredIds = @($tools.id) + @($tools | ForEach-Object { $_.required -split ',' })
                $items = @($missing | ForEach-Object { [pscustomobject]@{ Id = $_; Label = $_; Default = ($_ -in $requiredIds) } })
                $chosenPackages = @(Read-DotfilesSelection $items 'Select software to install after review')
                Write-Host 'Selected software is queued. Nothing will be installed before the final confirmation.'
            } elseif ($choice -eq '3') { $SkipMissing = $true }
            elseif ($choice -notin @('', '2')) { throw 'Cancelled: choose a displayed dependency option.' }
        } elseif ($missing.Count) { Write-Host ('No software will be installed. Missing: ' + ($missing -join ', ')) }
        else { Write-Host 'All checked requirements are available.' }

        Write-Host "`n3/4 - Configurations" -ForegroundColor Cyan
        $items = @()
        foreach ($tool in $tools) {
            $ready = $statuses[$tool.id].Ready
            foreach ($id in @($tool.required -split ',' | Where-Object { $_ -ne '-' })) { if (-not $statuses[$id].Ready) { $ready = $false } }
            $targets = @(Get-DotfilesTargets $context $tool.id)
            $existing = @($targets | Where-Object { Test-DotfilesEntry $_.Destination }).Count -gt 0
            $action = if ($existing) { 'REPLACE' } else { 'INSTALL' }
            $availability = if ($ready) { 'ready' } else { 'requirements missing; config can be staged' }
            Write-Host ("{0}: {1} ({2})" -f $tool.label, $action, $availability)
            foreach ($target in $targets) {
                [void](Assert-DotfilesTarget $context $target.Destination)
                $verb = if ($target.Kind -eq 'absent') { 'remove conflicting config' } else { $target.Kind }
                Write-Host "  $($target.Destination) [$verb]"
            }
            if ($SkipMissing -and -not $ready) { Write-Host '  SKIPPED: requirements missing'; continue }
            $items += [pscustomobject]@{ Id = $tool.id; Label = "$($tool.label) - $action ($availability)"; Default = $ready }
        }
        if ($DryRun) { Write-Host "`nPreview only: no packages, configurations or backups changed."; return }
        $selected = if ($Yes) { @($items | ForEach-Object Id) } else { @(Read-DotfilesSelection $items 'Select configurations to install or replace') }
        if ($selected.Count -eq 0 -and $chosenPackages.Count -eq 0) { Write-Host 'Nothing selected.'; return }
        Write-Host "`n4/4 - Review" -ForegroundColor Cyan
        Write-Host ('Install/replace: ' + ($selected -join ', '))
        if ($chosenPackages.Count) { Write-Host ('Software to install: ' + ($chosenPackages -join ', ')) }
        Write-Host "Existing targets will be moved into a timestamped backup under $($context.State)/backups."
        if (-not $Yes -and (Read-Host 'Apply these changes? Type yes') -ne 'yes') { Write-Host 'Cancelled.'; return }
        $outcome = Invoke-DotfilesApply -Context $context -Selected $selected -Packages $chosenPackages
        $failures = @($outcome.Results + $outcome.PackageResults | Where-Object { -not $_.Success } | ForEach-Object Id)
        if ($outcome.Run) { Write-Host "`nBackup run: $($outcome.Run.Directory)" }
        Write-Host ('Skipped: ' + (@($tools.id | Where-Object { $_ -notin $selected }) -join ', '))
        Write-Host 'Reopen the affected applications. See docs/configuration.md for first-launch steps and restore commands.'
        if ($failures.Count) { throw ('Installation finished with failures: ' + ($failures -join ', ')) }
    } finally { if ($lock) { $lock.Dispose() } }
}
