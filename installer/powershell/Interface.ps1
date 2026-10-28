function Write-DotfilesStatus($Status, [string]$Label, [string]$Prefix = '') {
    $color = if ($Status.Ready) { 'Green' } else { 'Red' }
    Write-Host ("{0}{1,-27} {2,-15} {3}" -f $Prefix, $Label, $Status.Status, $Status.Detail) -ForegroundColor $color
}

function Read-DotfilesSelection([object[]]$Items, [string]$Title) {
    if ($Items.Count -eq 0) { return @() }
    Write-Host "`n$Title" -ForegroundColor Cyan
    $selected = @($Items | ForEach-Object { [bool]$_.Default })
    for ($i = 0; $i -lt $Items.Count; $i++) {
        $mark = if ($selected[$i]) { 'x' } else { ' ' }
        Write-Host ("{0,2}. [{1}] {2}" -f ($i + 1), $mark, $Items[$i].Label)
    }
    while ($true) {
        $answer = Read-Host 'Numbers separated by commas; Enter keeps defaults; all, none, or cancel'
        if ($answer -eq 'cancel') { throw [OperationCanceledException]::new('Cancelled; no further changes will be applied.') }
        if ($answer -eq 'all') { return @($Items.Id) }
        if ($answer -eq 'none') { return @() }
        if (-not $answer.Trim()) { return @($Items | Where-Object { $selected[[array]::IndexOf($Items, $_)] } | ForEach-Object Id) }
        $indexes = @($answer -split ',' | ForEach-Object { $_.Trim() })
        if (@($indexes | Where-Object { $_ -notmatch '^\d+$' -or [int]$_ -lt 1 -or [int]$_ -gt $Items.Count }).Count) { Write-Host 'Choose one of the displayed numbers.'; continue }
        return @($indexes | ForEach-Object { $Items[[int]$_ - 1].Id } | Select-Object -Unique)
    }
}

function Install-DotfilesDependencies {
    param($Context, [string[]]$Ids, [switch]$NonInteractive, [switch]$PassThru)
    $results = New-Object 'System.Collections.Generic.List[object]'
    $winget = Get-Command winget -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    foreach ($id in $Ids) {
        if ($id -eq 'vscode-extensions') {
            $code = Get-DotfilesCommand $Context 'vscode'
            if (-not $code) {
                Write-Warning 'Install VS Code first, then rerun for extensions.'
                $results.Add([pscustomobject]@{ Id = $id; Success = $false; Message = 'Install VS Code first, then rerun for extensions.' }); continue
            }
            $success = $true
            foreach ($extension in Get-Content -LiteralPath (Join-Path $Context.Root 'config/vscode/common/extensions.txt')) {
                if ($extension.Trim()) {
                    & $code --install-extension $extension.Trim()
                    if ($LASTEXITCODE -ne 0) { $success = $false; Write-Warning "Could not install extension $extension" }
                }
            }
            $results.Add([pscustomobject]@{ Id = $id; Success = $success; Message = $(if ($success) { 'Extensions installed.' } else { 'Some extensions need manual installation.' }) })
            continue
        }
        $package = $Context.Packages | Where-Object id -eq $id | Select-Object -First 1
        if (-not $winget -or -not $package -or $package.winget -eq '-') {
            Write-Host "MANUAL: $id - see docs/tools/windows-dependencies.md" -ForegroundColor Yellow
            $results.Add([pscustomobject]@{ Id = $id; Success = $false; Message = 'Install through your company portal or approved package manager.' }); continue
        }
        Write-Host "Installing $id with WinGet (user scope)..."
        $arguments = @('install', '--id', $package.winget, '--exact', '--source', 'winget', '--scope', 'user')
        if ($NonInteractive) { $arguments += '--disable-interactivity' }
        & $winget.Source @arguments
        $success = $LASTEXITCODE -eq 0
        if (-not $success) { Write-Warning "$id could not be installed in user scope. Install through your company portal or package manager." }
        $results.Add([pscustomobject]@{ Id = $id; Success = $success; Message = $(if ($success) { 'Package command completed; version will be checked again.' } else { 'Manual installation required. Any package agreements must be handled in your normal installer.' }) })
    }
    # Refresh PATH for applications installed during this wizard.
    if ($Ids.Count) { $env:PATH = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [Environment]::GetEnvironmentVariable('Path', 'User') }
    if ($PassThru) { $results.ToArray() }
}
