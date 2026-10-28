function Write-DotfilesStatus($Status, [string]$Label, [string]$Prefix = '') {
    $color = if ($Status.Ready) { 'Green' } else { 'Red' }
    Write-Host ("{0}{1,-27} {2,-15} {3}" -f $Prefix, $Label, $Status.Status, $Status.Detail) -ForegroundColor $color
}

function Read-DotfilesSelection([object[]]$Items, [string]$Title) {
    if ($Items.Count -eq 0) { return @() }
    Write-Host "`n$Title" -ForegroundColor Cyan
    $selected = @($Items | ForEach-Object { [bool]$_.Default })
    $useKeys = $false
    try { $useKeys = $env:DOTFILES_NO_TUI -ne '1' -and -not [Console]::IsInputRedirected -and [Console]::WindowHeight -gt 16 -and [Console]::WindowWidth -gt 40 } catch { }
    if ($useKeys) {
        $height = [Math]::Min(10, $Items.Count)
        Write-Host 'Arrows: move | Space: select | A: all | Enter: continue | Esc: cancel'
        for ($i = 0; $i -lt $height; $i++) { Write-Host '' }
        $top = [Console]::CursorTop - $height
        $cursor = 0
        while ($true) {
            $start = [Math]::Max(0, [Math]::Min($cursor - $height + 1, $Items.Count - $height))
            [Console]::SetCursorPosition(0, $top)
            for ($row = 0; $row -lt $height; $row++) {
                $index = $start + $row
                $mark = if ($selected[$index]) { 'x' } else { ' ' }
                $arrow = if ($index -eq $cursor) { '>' } else { ' ' }
                $line = "$arrow [$mark] $($Items[$index].Label)"
                $width = [Math]::Max(20, [Console]::WindowWidth - 1)
                if ($line.Length -gt $width) { $line = $line.Substring(0, $width - 3) + '...' }
                Write-Host $line.PadRight($width)
            }
            $key = [Console]::ReadKey($true)
            switch ($key.Key) {
                'UpArrow' { $cursor = [Math]::Max(0, $cursor - 1) }
                'DownArrow' { $cursor = [Math]::Min($Items.Count - 1, $cursor + 1) }
                'Spacebar' { $selected[$cursor] = -not $selected[$cursor] }
                'A' { $all = @($selected | Where-Object { -not $_ }).Count -gt 0; for ($i = 0; $i -lt $selected.Count; $i++) { $selected[$i] = $all } }
                'Escape' { throw [OperationCanceledException]::new('Cancelled; no further changes will be applied.') }
                'Enter' { return @($Items | Where-Object { $selected[[array]::IndexOf($Items, $_)] } | ForEach-Object Id) }
            }
        }
    }
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

function Install-DotfilesDependencies($Context, [string[]]$Ids) {
    $winget = Get-Command winget -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    foreach ($id in $Ids) {
        if ($id -eq 'vscode-extensions') {
            $code = Get-DotfilesCommand $Context 'vscode'
            if (-not $code) { Write-Warning 'Install VS Code first, then rerun for extensions.'; continue }
            foreach ($extension in Get-Content -LiteralPath (Join-Path $Context.Root 'config/vscode/common/extensions.txt')) {
                if ($extension.Trim()) {
                    & $code --install-extension $extension.Trim()
                    if ($LASTEXITCODE -ne 0) { Write-Warning "Could not install extension $extension" }
                }
            }
            continue
        }
        $package = $Context.Packages | Where-Object id -eq $id | Select-Object -First 1
        if (-not $winget -or -not $package -or $package.winget -eq '-') { Write-Host "MANUAL: $id - see docs/tools/windows-dependencies.md" -ForegroundColor Yellow; continue }
        Write-Host "Installing $id with WinGet (user scope)..."
        & $winget.Source install --id $package.winget --exact --source winget --scope user
        if ($LASTEXITCODE -ne 0) { Write-Warning "$id could not be installed in user scope. Install through your company portal or package manager." }
    }
    # Refresh PATH for applications installed during this wizard.
    if ($Ids.Count) { $env:PATH = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [Environment]::GetEnvironmentVariable('Path', 'User') }
}
