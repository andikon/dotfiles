function Invoke-DotfilesApply {
    param($Context, [string[]]$Selected, [string[]]$Packages = @(), [switch]$NonInteractive, [scriptblock]$OnProgress)
    $lock = $null; $run = $null
    $results = New-Object 'System.Collections.Generic.List[object]'
    $packageResults = New-Object 'System.Collections.Generic.List[object]'
    $total = $Selected.Count + $Packages.Count; $completed = 0
    if ($total -eq 0) { return [pscustomobject]@{ Run = $null; Results = @(); PackageResults = @() } }
    try {
        New-Item -ItemType Directory -Path $Context.State -Force | Out-Null
        $lock = [IO.File]::Open((Join-Path $Context.State 'installer.lock'), 'OpenOrCreate', 'ReadWrite', 'None')
        foreach ($id in $Packages) {
            if ($OnProgress) { & $OnProgress ([pscustomobject]@{ Id = $id; Kind = 'package'; Completed = $completed; Total = $total; Message = "Installing $id" }) }
            try {
                & { Install-DotfilesDependencies $Context @($id) -PassThru -NonInteractive:$NonInteractive } *>&1 | ForEach-Object {
                    if ($_.PSObject.Properties['Success'] -and $_.PSObject.Properties['Id']) { $packageResults.Add($_) }
                    elseif ($OnProgress) { & $OnProgress ([pscustomobject]@{ Id = $id; Kind = 'log'; Completed = $completed; Total = $total; Message = $_.ToString() }) }
                    else { Write-Host $_.ToString() }
                }
                foreach ($packageResult in @($packageResults | Where-Object { $_.Id -eq $id })) {
                    $status = Get-DotfilesStatus $Context $id
                    if ($status.Ready) { $packageResult.Success = $true; $packageResult.Message = "Requirements satisfied: $($status.Detail)" }
                    else { $packageResult.Success = $false; $packageResult.Message = "$id still needs attention: $($status.Detail) Install manually if permissions or package agreements are required." }
                }
            } catch { $packageResults.Add([pscustomobject]@{ Id = $id; Success = $false; Message = $_.Exception.Message }) }
            $completed++
        }
        if ($Selected.Count) {
            $run = New-DotfilesRun $Context
            if ($OnProgress) { & $OnProgress ([pscustomobject]@{ Id = ''; Kind = 'backup'; Completed = $completed; Total = $total; Message = 'Backup journal prepared.'; Run = $run }) }
        }
        foreach ($id in $Selected) {
            if ($OnProgress) { & $OnProgress ([pscustomobject]@{ Id = $id; Kind = 'config'; Completed = $completed; Total = $total; Message = "Backing up and installing $id" }) }
            try {
                Install-DotfilesTool $Context $run $id
                $result = [pscustomobject]@{ Id = $id; Success = $true; Message = 'Configuration installed; previous targets are in the backup.' }
                if ($id -eq 'wezterm' -and -not $Context.Staging) {
                    $pwsh = Get-DotfilesCommand $Context 'pwsh'
                    if ($pwsh) {
                        try {
                            $indexOutput = & $pwsh -NoProfile -File (Join-Path $Context.Variables.WEZTERM 'scripts/Refresh-Projects.ps1') 2>&1
                            if ($LASTEXITCODE -ne 0) { $result.Message += ' Project index will refresh when WezTerm starts.' }
                        }
                        catch { $result.Message += ' Project index will refresh when WezTerm starts.' }
                    }
                }
            } catch { $result = [pscustomobject]@{ Id = $id; Success = $false; Message = $_.Exception.Message } }
            $results.Add($result); $completed++
            if ($OnProgress) { & $OnProgress ([pscustomobject]@{ Id = $id; Kind = 'result'; Completed = $completed; Total = $total; Message = $result.Message; Result = $result }) }
            elseif ($result.Success) { Write-Host "INSTALLED: $id" -ForegroundColor Green }
            else { Write-Warning "FAILED: $id. $($result.Message)" }
        }
        return [pscustomobject]@{ Run = $run; Results = $results.ToArray(); PackageResults = $packageResults.ToArray() }
    } finally { if ($lock) { $lock.Dispose() } }
}
