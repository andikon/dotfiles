function New-DotfilesWorkbenchFrame($State, [int]$Width, [int]$Height) {
    $canvas = New-DotfilesCanvas ([Math]::Max(1, $Width)) ([Math]::Max(1, $Height))
    if ($Width -lt 72 -or $Height -lt 22) {
        Set-DotfilesCanvasText $canvas 1 1 'dotfiles / setup' 2
        Set-DotfilesCanvasText $canvas 1 3 'Resize to at least 72 columns x 22 rows.' 5
        Set-DotfilesCanvasText $canvas 1 5 'Your selections are kept. Esc cancels.' 1
        if ($State.Dialog) { Set-DotfilesCanvasText $canvas 1 7 'Cancel setup? Y exits, Esc keeps editing.' 5 }
        return $canvas
    }
    $model = Get-DotfilesWorkbenchPage $State
    $rail = if ($Width -lt 90) { 15 } else { 18 }
    $bodyX = $rail + 3; $bodyWidth = $Width - $bodyX - 3
    $wide = $bodyWidth -ge 78
    $detailWidth = if ($wide) { [Math]::Min(34, [int][Math]::Floor($bodyWidth * .38)) } else { $bodyWidth }
    $listWidth = if ($wide) { $bodyWidth - $detailWidth - 3 } else { $bodyWidth }
    $detailX = if ($wide) { $bodyX + $listWidth + 3 } else { $bodyX }
    $lastBody = $Height - 7
    $check = [string][char]0x2713; $pointer = [string][char]0x203a; $vertical = [string][char]0x2502
    Set-DotfilesCanvasText $canvas 2 1 '>_ dotfiles / setup' 2
    Set-DotfilesCanvasText $canvas ($Width - 23) 1 'WINDOWS / CURRENT USER' 1
    Set-DotfilesCanvasRule $canvas 0 3 $Width
    for ($y = 4; $y -le $lastBody; $y++) { Set-DotfilesCanvasText $canvas $rail $y $vertical 9 }
    $steps = @('Inspect','Dependencies','Configs','Review','Finish')
    for ($i = 0; $i -lt $steps.Count; $i++) {
        $y = 5 + ($i * 2)
        $active = $i -eq $State.Page
        if ($active) { Set-DotfilesCanvasText $canvas 1 $y (' ' * ($rail - 2)) 6 }
        $mark = if ($i -lt $State.Page) { $check + ' ' } else { '{0:D2}' -f ($i + 1) }
        $role = if ($active) { 7 } elseif ($i -lt $State.Page) { 3 } else { 1 }
        Set-DotfilesCanvasText $canvas 2 $y $mark $role 2
        $stepLabel = if ($rail -lt 18 -and $i -eq 1) { 'Software' } else { $steps[$i] }
        Set-DotfilesCanvasText $canvas 5 $y $stepLabel $(if ($active) { 7 } else { 0 }) ($rail - 6)
    }
    if ($lastBody -gt 20) {
        Set-DotfilesCanvasText $canvas 2 ($lastBody - 2) 'User settings' 1 ($rail - 3)
        Set-DotfilesCanvasText $canvas 2 ($lastBody - 1) $(if ($State.DryRun) { 'Preview only' } else { 'Backups on' }) 1 ($rail - 3)
    }
    Set-DotfilesCanvasText $canvas $bodyX 5 ('STEP {0:D2} / 05' -f ($State.Page + 1)) 1 $bodyWidth
    Set-DotfilesCanvasText $canvas $bodyX 7 $model.Title $(if ($State.Complete -and -not @($State.Results + $State.PackageResults | Where-Object { -not $_.Success }).Count) { 3 } else { 8 }) $bodyWidth
    $introLines = @(Split-DotfilesTerminalText $model.Intro $bodyWidth)
    for ($i = 0; $i -lt [Math]::Min(2, $introLines.Count); $i++) { Set-DotfilesCanvasText $canvas $bodyX (8 + $i) $introLines[$i] 1 $bodyWidth }
    $headerY = 11
    if ($State.Applying) {
        $barWidth = [Math]::Min(24, $bodyWidth - 10); $filled = [Math]::Min($barWidth, [int][Math]::Floor($barWidth * $State.Progress))
        $bar = '[' + ('#' * $filled) + ('.' * ($barWidth - $filled)) + '] ' + ('{0,3}%' -f [int]($State.Progress * 100))
        Set-DotfilesCanvasText $canvas $bodyX 10 $bar 2 $bodyWidth
        $headerY = 12
    }
    $startY = $headerY + 2
    $stride = if ($Height -ge 34 -and $model.Rows.Count -le 10) { 2 } else { 1 }
    $visible = [Math]::Max(1, [int][Math]::Floor(($lastBody - $startY + 1) / $stride))
    $cursor = $State.Cursor[$State.Page]
    $scroll = [Math]::Min($State.Scroll[$State.Page], $cursor)
    if ($cursor -ge $scroll + $visible) { $scroll = $cursor - $visible + 1 }
    $State.Scroll[$State.Page] = [Math]::Max(0, $scroll)
    if ($wide -or -not $State.DetailsFocused) {
        Set-DotfilesCanvasText $canvas $bodyX $headerY $model.Label $(if (-not $State.DetailsFocused) { 2 } else { 1 }) $listWidth
        Set-DotfilesCanvasRule $canvas $bodyX ($headerY + 1) $listWidth
        for ($rowIndex = $scroll; $rowIndex -lt [Math]::Min($model.Rows.Count, $scroll + $visible); $rowIndex++) {
            $row = $model.Rows[$rowIndex]; $y = $startY + (($rowIndex - $scroll) * $stride); $focused = $rowIndex -eq $cursor
            if ($focused) { Set-DotfilesCanvasText $canvas $bodyX $y (' ' * $listWidth) 6 }
            $labelRole = if ($focused) { 6 } elseif ($row.Disabled) { 1 } else { 0 }
            $mark = if ($row.Kind -in @('config','package')) { if ($row.Checked) { '[x]' } else { '[ ]' } } elseif ($row.Kind -eq 'mode') { if ($row.Checked) { '(*)' } else { '( )' } } elseif ($focused) { $pointer + '  ' } else { '   ' }
            Set-DotfilesCanvasText $canvas $bodyX $y $mark $(if ($focused) { 7 } else { 2 }) 3
            $badgeWidth = if ($listWidth -ge 43) { 12 } else { 9 }
            $labelWidth = $listWidth - 5 - $badgeWidth
            if ($row.Kind -eq 'mode') { $labelWidth = $listWidth - 5 }
            Set-DotfilesCanvasText $canvas ($bodyX + 4) $y $row.Label $labelRole $labelWidth
            if ($row.Badge) {
                $role = [int]$row.Role
                if ($focused) { $role = switch ($role) { 1 { 14 } 2 { 7 } 3 { 11 } 4 { 12 } 5 { 13 } default { 6 } } }
                Set-DotfilesCanvasText $canvas ($bodyX + $listWidth - $badgeWidth) $y $row.Badge.PadLeft($badgeWidth) $role $badgeWidth
            }
        }
        if ($model.Rows.Count -gt $visible) {
            Set-DotfilesCanvasText $canvas $bodyX ($lastBody + 1) ("{0}-{1} of {2}  /  PgUp PgDn" -f ($scroll + 1), [Math]::Min($model.Rows.Count, $scroll + $visible), $model.Rows.Count) 1 $listWidth
        }
        if ($model.Rows.Count -eq 0) {
            $lines = @(Split-DotfilesTerminalText $model.Empty $listWidth)
            for ($i = 0; $i -lt [Math]::Min($lines.Count, $visible); $i++) { Set-DotfilesCanvasText $canvas $bodyX ($startY + $i) $lines[$i] 1 $listWidth }
        }
    }
    if ($wide -or $State.DetailsFocused) {
        if ($wide) { for ($y = $headerY; $y -le $lastBody; $y++) { Set-DotfilesCanvasText $canvas ($detailX - 2) $y $vertical 9 } }
        Set-DotfilesCanvasText $canvas $detailX $headerY 'DETAILS / Tab' $(if ($State.DetailsFocused) { 2 } else { 1 }) $detailWidth
        Set-DotfilesCanvasRule $canvas $detailX ($headerY + 1) $detailWidth
        $details = @()
        if ($model.Rows.Count) { $details += @($model.Rows[$cursor].Label, '') + @($model.Rows[$cursor].Details) }
        if ($State.Page -eq 4) {
            if ($State.Run) { $details += @('', 'BACKUP RUN', $State.Run.Directory) }
            if ($State.Log.Count) { $details += @('', 'LATEST OUTPUT') + @($State.Log | Select-Object -Last 5) }
        }
        if (-not $details.Count) { $details = @($State.ScanMessage) }
        $wrapped = New-Object 'System.Collections.Generic.List[object]'
        $lineIndex = 0
        foreach ($line in $details) {
            $role = if ($lineIndex -eq 0) { 2 } elseif ($line.StartsWith('! ')) { 5 } elseif ($line.StartsWith('+ ')) { 3 } elseif ($line -cmatch '^[A-Z /]+$') { 1 } else { 0 }
            $line = $line -replace '^[!+] ', ''
            if (-not $line) { $wrapped.Add([pscustomobject]@{ Text = ''; Role = 0 }) }
            else { foreach ($part in @(Split-DotfilesTerminalText $line $detailWidth)) { $wrapped.Add([pscustomobject]@{ Text = $part; Role = $role }) } }
            $lineIndex++
        }
        $detailHeight = [Math]::Max(1, $lastBody - $startY + 1)
        $State.DetailScroll = [Math]::Min($State.DetailScroll, [Math]::Max(0, $wrapped.Count - $detailHeight))
        for ($i = 0; $i -lt [Math]::Min($detailHeight, $wrapped.Count - $State.DetailScroll); $i++) {
            $line = $wrapped[$State.DetailScroll + $i]
            Set-DotfilesCanvasText $canvas $detailX ($startY + $i) $line.Text $line.Role $detailWidth
        }
        if ($wrapped.Count -gt $detailHeight) { Set-DotfilesCanvasText $canvas $detailX ($lastBody + 1) 'Tab + arrows scroll details' 1 $detailWidth }
    }
    Set-DotfilesCanvasRule $canvas 0 ($Height - 6) $Width
    $summary = if ($State.DryRun) { 'PREVIEW / no changes' } elseif ($State.Mode -eq 'install') { 'Software: selected installs' } elseif ($State.Mode -eq 'skip') { 'Software: skip unavailable' } else { 'Software: handled by you' }
    Set-DotfilesCanvasText $canvas 2 ($Height - 5) $summary 1 ([int]($Width / 2) - 3)
    $count = "$( @(Get-DotfilesWorkbenchSelected $State).Count ) configs selected / backups on"
    Set-DotfilesCanvasText $canvas ([Math]::Max([int]($Width / 2), $Width - $count.Length - 2)) ($Height - 5) $count 1
    Set-DotfilesCanvasRule $canvas 0 ($Height - 4) $Width
    $action = if ($State.Applying) { 'Applying...' } elseif ($State.Complete) { 'Enter Exit' } elseif ($State.Page -eq 3 -and $State.DryRun) { 'Enter Finish preview' } elseif ($State.Page -eq 3) { 'Enter Apply settings' } else { 'Enter Continue' }
    $actionX = $Width - $action.Length - 4
    $hints = if ($Width -ge 105) { 'Up/Down move  Space select  A all  Tab details  ? help  Esc cancel' } else { 'Arrows Space A Tab ? Esc' }
    if ($State.Complete) { $hints = 'Up/Down results  Tab details  Esc exit' }
    if ($State.Applying) { $hints = 'Applying the reviewed changes...' }
    Set-DotfilesCanvasText $canvas 2 ($Height - 2) $hints 1 ($actionX - 3)
    Set-DotfilesCanvasText $canvas $actionX ($Height - 2) (' ' + $action + ' ') 10
    if ($State.Dialog) {
        $dialogWidth = [Math]::Min(68, $Width - 8); $dialogHeight = [Math]::Min(14, $Height - 6)
        $left = [int][Math]::Floor(($Width - $dialogWidth) / 2); $top = [int][Math]::Floor(($Height - $dialogHeight) / 2)
        for ($y = $top; $y -lt $top + $dialogHeight; $y++) { Set-DotfilesCanvasText $canvas $left $y (' ' * $dialogWidth) 0 }
        Set-DotfilesCanvasRule $canvas $left $top $dialogWidth 2
        Set-DotfilesCanvasRule $canvas $left ($top + $dialogHeight - 1) $dialogWidth 2
        for ($y = $top + 1; $y -lt $top + $dialogHeight - 1; $y++) { Set-DotfilesCanvasText $canvas $left $y $vertical 2; Set-DotfilesCanvasText $canvas ($left + $dialogWidth - 1) $y $vertical 2 }
        Set-DotfilesCanvasText $canvas ($left + 3) ($top + 2) $(if ($State.Dialog -eq 'help') { 'KEYBOARD CONTROLS' } else { 'CANCEL THIS SETUP?' }) 8 ($dialogWidth - 6)
        $message = if ($State.Dialog -eq 'help') { 'Arrows move; Space selects; A toggles all. Enter continues; Backspace returns. Tab switches to details; PgUp/PgDn scroll. 1-4 jump to visited pages. Esc cancels.' } else { 'No pending changes have been applied. Keep editing, or exit setup?' }
        $lines = @(Split-DotfilesTerminalText $message ($dialogWidth - 6))
        for ($i = 0; $i -lt [Math]::Min($lines.Count, $dialogHeight - 6); $i++) { Set-DotfilesCanvasText $canvas ($left + 3) ($top + 4 + $i) $lines[$i] 1 ($dialogWidth - 6) }
        $buttons = if ($State.Dialog -eq 'help') { '[ Enter: Got it ]' } elseif ($State.DialogChoice -eq 0) { '[ Keep editing ]    Exit setup' } else { '  Keep editing    [ Exit setup ]' }
        Set-DotfilesCanvasText $canvas ($left + 3) ($top + $dialogHeight - 3) $buttons 2 ($dialogWidth - 6)
    }
    return $canvas
}
