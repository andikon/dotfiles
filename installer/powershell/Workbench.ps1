. (Join-Path $PSScriptRoot 'Terminal.ps1')
. (Join-Path $PSScriptRoot 'WorkbenchModel.ps1')
. (Join-Path $PSScriptRoot 'WorkbenchFrame.ps1')

function Show-DotfilesWorkbench($Session, $State) {
    $size = Get-DotfilesTerminalSize
    if ($size.Width -ne $Session.Size.Width -or $size.Height -ne $Session.Size.Height) { $Session.Size = $size; $Session.LastRows = @() }
    $frame = New-DotfilesWorkbenchFrame $State $Session.Size.Width $Session.Size.Height
    try { Write-DotfilesWorkbenchFrame $Session $frame }
    catch [ArgumentOutOfRangeException] { $Session.LastRows = @() } # A resize can happen between measuring and drawing.
}

function Invoke-DotfilesWorkbench {
    param($Context, [object[]]$Tools, [bool]$SkipDependencies, [bool]$SkipMissing, [bool]$DryRun)
    $session = $null
    $state = New-DotfilesWorkbenchState $Context $Tools $SkipDependencies $SkipMissing $DryRun
    try {
        $session = Start-DotfilesWorkbench
        Update-DotfilesWorkbenchInventory $state { Show-DotfilesWorkbench $session $state }
        while (-not $state.Exit) {
            Show-DotfilesWorkbench $session $state
            $event = Read-DotfilesWorkbenchEvent $session
            # A small viewport cannot display a review. Keep selections and ignore action keys until it grows.
            if (($session.Size.Width -lt 72 -or $session.Size.Height -lt 22) -and -not $state.Dialog -and $event.Key -ne 'Escape' -and -not ($event.Control -and $event.Key -eq 'C')) { continue }
            Update-DotfilesWorkbenchState $state $event
            if (-not $state.ApplyRequested) { continue }
            $state.ApplyRequested = $false; $state.Page = 4; $state.Visited = 4
            $state.DetailsFocused = $false; $state.DetailScroll = 0
            if ($DryRun) { $state.Complete = $true; continue }
            $state.Applying = $true
            $state.CurrentOperation = 'Preparing the reviewed changes...'
            Show-DotfilesWorkbench $session $state
            try {
                Set-DotfilesTerminalControlC $false
                $progress = {
                    param($update)
                    $state.Progress = if ($update.Total) { $update.Completed / [double]$update.Total } else { 1 }
                    if ($update.Kind -eq 'log') {
                        $state.Log.Add($update.Message)
                        if ($state.Log.Count -gt 100) { $state.Log.RemoveAt(0) }
                    } else { $state.CurrentOperation = $update.Message }
                    if ($update.PSObject.Properties['Result']) { $state.Results += $update.Result; $state.Cursor[4] = [Math]::Max(0, $state.Results.Count - 1) }
                    if ($update.PSObject.Properties['Run']) { $state.Run = $update.Run }
                    Show-DotfilesWorkbench $session $state
                }
                $outcome = Invoke-DotfilesApply -Context $Context -Selected @(Get-DotfilesWorkbenchSelected $state) -Packages @(Get-DotfilesWorkbenchPackages $state) -NonInteractive -OnProgress $progress
                $state.Run = $outcome.Run; $state.Results = @($outcome.Results); $state.PackageResults = @($outcome.PackageResults)
            } catch {
                $state.Results += [pscustomobject]@{ Id = 'setup'; Success = $false; Message = $_.Exception.Message }
            } finally { Set-DotfilesTerminalControlC $true; $state.Applying = $false; $state.Complete = $true; $state.Progress = 1 }
        }
    } finally { Stop-DotfilesWorkbench $session }
    return [pscustomobject]@{ Cancelled = $state.Cancelled; Preview = $DryRun; Run = $state.Run; Results = @($state.Results); PackageResults = @($state.PackageResults); Selected = @(Get-DotfilesWorkbenchSelected $state) }
}
