# Native console drawing only. Keep this file ASCII so Windows PowerShell 5.1 can read it without a BOM.
function Get-DotfilesTerminalSize {
    try { return [pscustomobject]@{ Width = [Console]::WindowWidth; Height = [Console]::WindowHeight } }
    catch { return [pscustomobject]@{ Width = 0; Height = 0 } }
}

function Test-DotfilesWorkbenchAvailable {
    if ($env:DOTFILES_NO_TUI -eq '1') { return $false }
    try {
        $size = Get-DotfilesTerminalSize
        return -not [Console]::IsInputRedirected -and -not [Console]::IsOutputRedirected -and $size.Width -ge 72 -and $size.Height -ge 22
    } catch { return $false }
}

function Get-DotfilesTextElements([string]$Text) {
    $clean = $Text -replace '\x1b\[[0-?]*[ -/]*[@-~]', '' -replace '[\x00-\x1f\x7f]', ' '
    $iterator = [Globalization.StringInfo]::GetTextElementEnumerator($clean)
    while ($iterator.MoveNext()) {
        $value = [string]$iterator.Current
        $point = [char]::ConvertToUtf32($value, 0)
        $wide = ($point -ge 0x1100 -and $point -le 0x115f) -or ($point -ge 0x2e80 -and $point -le 0xa4cf) -or ($point -ge 0xac00 -and $point -le 0xd7a3) -or ($point -ge 0xf900 -and $point -le 0xfaff) -or ($point -ge 0xfe10 -and $point -le 0xfe6f) -or ($point -ge 0xff01 -and $point -le 0xff60) -or ($point -ge 0xffe0 -and $point -le 0xffe6) -or $point -ge 0x1f300
        [pscustomobject]@{ Text = $value; Width = $(if ($wide) { 2 } else { 1 }) }
    }
}

function Split-DotfilesTerminalText([string]$Text, [int]$Width) {
    if ($Width -lt 1) { return @() }
    $line = New-Object Text.StringBuilder
    $used = 0
    foreach ($element in @(Get-DotfilesTextElements $Text)) {
        if ($element.Width -gt $Width) { continue }
        if ($used + $element.Width -gt $Width) { $line.ToString(); [void]$line.Clear(); $used = 0 }
        [void]$line.Append($element.Text); $used += $element.Width
    }
    if ($line.Length) { $line.ToString() }
}

function New-DotfilesCanvas([int]$Width, [int]$Height) {
    $rows = New-Object 'System.Collections.Generic.List[object]'
    for ($y = 0; $y -lt $Height; $y++) {
        $rows.Add([pscustomobject]@{ Cells = @(' ') * $Width; Roles = (New-Object 'byte[]' $Width) })
    }
    return [pscustomobject]@{ Width = $Width; Height = $Height; Rows = $rows }
}

function Set-DotfilesCanvasText {
    param($Canvas, [int]$X, [int]$Y, [string]$Text, [byte]$Role = 0, [int]$Width = 0)
    if ($Y -lt 0 -or $Y -ge $Canvas.Height -or $X -lt 0 -or $X -ge $Canvas.Width) { return }
    $limit = if ($Width -gt 0) { [Math]::Min($Canvas.Width, $X + $Width) } else { $Canvas.Width }
    $row = $Canvas.Rows[$Y]
    $position = $X
    # Most of the frame is ASCII. Avoid text-element allocation on that hot path.
    if ($Text -notmatch '[^\x20-\x7e]') {
        for ($i = 0; $i -lt $Text.Length -and $position -lt $limit; $i++) {
            $row.Cells[$position] = [string]$Text[$i]; $row.Roles[$position] = $Role; $position++
        }
        return
    }
    foreach ($element in @(Get-DotfilesTextElements $Text)) {
        if ($position + $element.Width -gt $limit) { break }
        $row.Cells[$position] = $element.Text; $row.Roles[$position] = $Role; $position++
        if ($element.Width -eq 2) { $row.Cells[$position] = ''; $row.Roles[$position] = $Role; $position++ }
    }
}

function Set-DotfilesCanvasRule($Canvas, [int]$X, [int]$Y, [int]$Width, [byte]$Role = 9) {
    Set-DotfilesCanvasText $Canvas $X $Y (([string][char]0x2500) * [Math]::Max(0, $Width)) $Role $Width
}

function Get-DotfilesCanvasLines($Canvas) {
    foreach ($row in $Canvas.Rows) { -join $row.Cells }
}

function Start-DotfilesWorkbench {
    $supportsAnsi = $false
    try { $supportsAnsi = [bool]$Host.UI.SupportsVirtualTerminal } catch { }
    if ($env:WT_SESSION -or $env:WEZTERM_PANE -or $env:TERM_PROGRAM -eq 'WezTerm') { $supportsAnsi = $true }
    $session = [pscustomobject]@{
        Ansi = $supportsAnsi; LastRows = @(); Size = (Get-DotfilesTerminalSize)
        Foreground = [Console]::ForegroundColor; Background = [Console]::BackgroundColor
        CursorVisible = $true; ControlC = [Console]::TreatControlCAsInput; Encoding = [Console]::OutputEncoding
        SavedBuffer = $null; SavedCursor = $null; Started = $false
        # Roles: text, muted, accent, good, bad, warning, selection, selected accent, title, border, primary button.
        Colors = @('216;223;235','145;157;173','139;188;241','166;201;145','236;153;167','232;196;135','216;223;235','139;188;241','230;236;245','52;60;73','21;25;31','166;201;145','236;153;167','232;196;135','145;157;173')
        ConsoleColors = @('Gray','DarkGray','Blue','Green','Red','Yellow','White','Cyan','White','DarkGray','Black','Green','Red','Yellow','Gray')
    }
    try {
        try { $session.CursorVisible = [Console]::CursorVisible } catch { }
        if ($session.Ansi) { [Console]::Write("$([char]27)[?1049h$([char]27)[?25l") }
        else {
            try {
                $session.SavedCursor = $Host.UI.RawUI.CursorPosition
                $rect = New-Object Management.Automation.Host.Rectangle(0, [Console]::WindowTop, ($session.Size.Width - 1), ([Console]::WindowTop + $session.Size.Height - 1))
                $session.SavedBuffer = $Host.UI.RawUI.GetBufferContents($rect)
            } catch { }
        }
        $session.Started = $true
        [Console]::CursorVisible = $false
        [Console]::TreatControlCAsInput = $true
        [Console]::OutputEncoding = New-Object Text.UTF8Encoding($false)
        return $session
    } catch { Stop-DotfilesWorkbench $session; throw }
}

function Stop-DotfilesWorkbench($Session) {
    if (-not $Session) { return }
    try {
        if ($Session.Started) {
            if ($Session.Ansi) { [Console]::Write("$([char]27)[0m$([char]27)[?1049l") }
            elseif ($Session.SavedBuffer) { $Host.UI.RawUI.SetBufferContents((New-Object Management.Automation.Host.Coordinates(0, [Console]::WindowTop)), $Session.SavedBuffer) }
            else { [Console]::Clear() }
        }
    } finally {
        [Console]::ForegroundColor = $Session.Foreground; [Console]::BackgroundColor = $Session.Background
        [Console]::OutputEncoding = $Session.Encoding
        [Console]::TreatControlCAsInput = $Session.ControlC
        try { [Console]::CursorVisible = $Session.CursorVisible } catch { }
        if (-not $Session.Ansi -and $Session.SavedCursor) { try { $Host.UI.RawUI.CursorPosition = $Session.SavedCursor } catch { } }
    }
}

function Write-DotfilesWorkbenchFrame($Session, $Canvas) {
    $escape = [string][char]27
    $builder = New-Object Text.StringBuilder
    $currentRows = New-Object 'System.Collections.Generic.List[string]'
    # Clear the final row too after resize, while leaving the bottom-right cell alone to prevent scrolling.
    for ($y = 0; $y -lt $Canvas.Height; $y++) {
        $row = $Canvas.Rows[$y]
        $signature = (-join $row.Cells) + ':' + [Convert]::ToBase64String($row.Roles)
        $currentRows.Add($signature)
        if ($y -lt $Session.LastRows.Count -and $Session.LastRows[$y] -eq $signature) { continue }
        if ($Session.Ansi) { [void]$builder.Append("$escape[$($y + 1);1H") }
        else { [Console]::SetCursorPosition(0, [Console]::WindowTop + $y) }
        $start = 0
        $limit = if ($y -eq $Canvas.Height - 1) { [Math]::Max(0, $Canvas.Width - 1) } else { $Canvas.Width }
        while ($start -lt $limit) {
            $role = [int]$row.Roles[$start]
            $end = $start + 1
            while ($end -lt $limit -and $row.Roles[$end] -eq $role) { $end++ }
            $text = -join $row.Cells[$start..($end - 1)]
            $background = if ($role -in 6,7,11,12,13,14) { '35;46;60' } elseif ($role -eq 10) { '139;188;241' } else { '21;25;31' }
            if ($Session.Ansi) {
                [void]$builder.Append("$escape[38;2;$($Session.Colors[$role])m$escape[48;2;${background}m$text")
            } else {
                [Console]::ForegroundColor = $Session.ConsoleColors[$role]
                [Console]::BackgroundColor = if ($role -in 6,7,11,12,13,14) { 'DarkBlue' } elseif ($role -eq 10) { 'Cyan' } else { 'Black' }
                [Console]::Write($text)
            }
            $start = $end
        }
    }
    if ($Session.Ansi) { [Console]::Write($builder.ToString()) }
    $Session.LastRows = @($currentRows)
}

function Read-DotfilesWorkbenchEvent($Session) {
    while ($true) {
        $size = Get-DotfilesTerminalSize
        if ($size.Width -ne $Session.Size.Width -or $size.Height -ne $Session.Size.Height) {
            $Session.Size = $size; $Session.LastRows = @()
            return [pscustomobject]@{ Key = 'Resize'; Character = ''; Control = $false }
        }
        if ([Console]::KeyAvailable) {
            $key = [Console]::ReadKey($true)
            return [pscustomobject]@{ Key = $key.Key.ToString(); Character = [string]$key.KeyChar; Control = [bool]($key.Modifiers -band [ConsoleModifiers]::Control) }
        }
        Start-Sleep -Milliseconds 60
    }
}

function Set-DotfilesTerminalControlC([bool]$TreatAsInput) { [Console]::TreatControlCAsInput = $TreatAsInput }
