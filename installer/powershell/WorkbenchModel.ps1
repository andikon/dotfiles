function New-DotfilesWorkbenchState {
    param($Context, [object[]]$Tools, [bool]$SkipDependencies, [bool]$SkipMissing, [bool]$DryRun)
    return [pscustomobject]@{
        Context = $Context; Tools = $Tools; Statuses = @{}; Configs = @(); PackageItems = @()
        Page = 0; Visited = 0; Cursor = @(0,0,0,0,0); Scroll = @(0,0,0,0,0); DetailScroll = 0; DetailsFocused = $false
        Mode = $(if ($SkipMissing) { 'skip' } else { 'manual' }); SkipDependencies = $SkipDependencies; SkipMissing = $SkipMissing; DryRun = $DryRun
        ConfigChosen = @{}; ConfigTouched = @{}; PackageChosen = @{}
        Scanning = $true; ScanMessage = 'Checking installed tools...'; Dialog = ''; DialogChoice = 0
        ApplyRequested = $false; Applying = $false; Complete = $false; Exit = $false; Cancelled = $false
        Progress = 0; CurrentOperation = ''; Log = (New-Object 'System.Collections.Generic.List[string]')
        Results = @(); PackageResults = @(); Run = $null
    }
}

function Get-DotfilesWorkbenchPackages($State) {
    if ($State.Mode -ne 'install' -or $State.SkipDependencies) { return @() }
    return @($State.PackageItems | Where-Object { -not $_.Disabled -and $State.PackageChosen[$_.Id] } | ForEach-Object Id)
}

function Test-DotfilesWorkbenchToolReady($State, $Tool, [bool]$IncludeQueued) {
    $queued = @(Get-DotfilesWorkbenchPackages $State)
    foreach ($id in @($Tool.id) + @($Tool.required -split ',' | Where-Object { $_ -ne '-' })) {
        if ($State.Statuses.ContainsKey($id) -and $State.Statuses[$id].Ready) { continue }
        $equivalent = if ($id -eq 'powershell') { 'pwsh' } else { $id }
        if ($IncludeQueued -and ($id -in $queued -or $equivalent -in $queued -or ($id -eq 'pwsh' -and 'powershell' -in $queued))) { continue }
        return $false
    }
    return $true
}

function Update-DotfilesWorkbenchInventory($State, [scriptblock]$OnScan) {
    $State.Statuses = @{}
    foreach ($tool in $State.Tools) {
        foreach ($id in @($tool.id) + @($tool.required -split ',') + @($tool.optional -split ',')) {
            if ($id -eq '-' -or $State.Statuses.ContainsKey($id)) { continue }
            $State.ScanMessage = "Checking $id..."
            if ($OnScan) { & $OnScan }
            $State.Statuses[$id] = Get-DotfilesStatus $State.Context $id
        }
    }
    $requiredIds = @($State.Tools.id) + @($State.Tools | ForEach-Object { $_.required -split ',' })
    $winget = Get-Command winget -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    $packages = @(); $seen = @{}
    foreach ($id in @($State.Statuses.Keys | Sort-Object)) {
        if ($State.Statuses[$id].Ready) { continue }
        $package = $State.Context.Packages | Where-Object id -eq $id | Select-Object -First 1
        $extension = $id -eq 'vscode-extensions'
        $available = $extension -or ($winget -and $package -and $package.winget -ne '-')
        $provider = if ($extension) { 'VS Code CLI' } elseif ($available) { "WinGet: $($package.winget)" } else { 'Manual installation' }
        $identity = if ($available -and -not $extension) { $package.winget } else { $id }
        if ($seen.ContainsKey($identity)) { continue }
        $seen[$identity] = $true
        $packages += [pscustomobject]@{ Id = $id; Label = $id; Provider = $provider; Disabled = -not $available; Required = ($id -in $requiredIds) }
        if (-not $State.PackageChosen.ContainsKey($id)) { $State.PackageChosen[$id] = $available -and $id -in $requiredIds }
    }
    $State.PackageItems = $packages
    $State.Scanning = $false
    Update-DotfilesWorkbenchConfigurations $State
}

function Update-DotfilesWorkbenchConfigurations($State) {
    $configs = @()
    foreach ($tool in $State.Tools) {
        $ready = Test-DotfilesWorkbenchToolReady $State $tool $false
        $plannedReady = Test-DotfilesWorkbenchToolReady $State $tool $true
        $targets = @(Get-DotfilesTargets $State.Context $tool.id)
        $invalid = ''
        foreach ($target in $targets) {
            try { [void](Assert-DotfilesTarget $State.Context $target.Destination) } catch { $invalid = $_.Exception.Message }
        }
        $disabled = [bool]$invalid -or (($State.SkipMissing -or $State.Mode -eq 'skip') -and -not $ready)
        if (-not $State.ConfigTouched.ContainsKey($tool.id)) { $State.ConfigChosen[$tool.id] = $plannedReady -and -not $disabled }
        if ($disabled) { $State.ConfigChosen[$tool.id] = $false }
        $exists = @($targets | Where-Object { Test-DotfilesEntry $_.Destination }).Count -gt 0
        $configs += [pscustomobject]@{ Id = $tool.id; Tool = $tool; Label = $tool.label; Targets = $targets; Ready = $ready; PlannedReady = $plannedReady; Existing = $exists; Disabled = $disabled; Invalid = $invalid }
    }
    $State.Configs = $configs
}

function Get-DotfilesWorkbenchSelected($State) {
    return @($State.Configs | Where-Object { -not $_.Disabled -and $State.ConfigChosen[$_.Id] } | ForEach-Object Id)
}

function New-DotfilesWorkbenchRow {
    param([string]$Id, [string]$Label, [string]$Kind = 'info', [string]$Badge = '', [byte]$Role = 0, [string[]]$Details = @(), [bool]$Disabled = $false, [bool]$Checked = $false, [string]$Secondary = '')
    return [pscustomobject]@{ Id = $Id; Label = $Label; Kind = $Kind; Badge = $Badge; Role = $Role; Details = $Details; Disabled = $Disabled; Checked = $Checked; Secondary = $Secondary }
}

function Get-DotfilesWorkbenchConfigDetails($Config) {
    $details = @('DESTINATION')
    foreach ($target in $Config.Targets) {
        if ($target.Kind -eq 'absent') {
            if (Test-DotfilesEntry $target.Destination) { $details += @('', '! LEGACY CONFIG FOUND', $target.Destination, '! Move into the backup so the new settings take effect.') }
        } else { $details += $target.Destination }
    }
    $description = if ($Config.Id -eq 'windows-terminal') { 'Update shared settings; preserve machine profiles, default profile and custom color schemes.' }
        elseif ($Config.Existing) { 'Replace the displayed targets completely.' } else { 'Install new configuration files.' }
    $details += @('', 'ACTION', $description, '', '+ Backup before replacement')
    if (-not $Config.Ready) { $details += @('', '! Requirements missing. These config files can be staged for software you install later.') }
    if ($Config.Invalid) { $details += @('', '! ' + $Config.Invalid) }
    return $details
}

function Get-DotfilesWorkbenchPage($State) {
    $rows = @(); $title = ''; $intro = ''; $label = ''; $empty = ''; $selected = @(Get-DotfilesWorkbenchSelected $State)
    switch ($State.Page) {
        0 {
            $title = 'YOUR MACHINE, AT A GLANCE'; $intro = 'Check what is ready before choosing any changes.'; $label = 'TOOLS & DEPENDENCIES'; $seen = @{}
            foreach ($tool in $State.Tools) {
                if (-not $State.Statuses.ContainsKey($tool.id)) { continue }
                $status = $State.Statuses[$tool.id]; $seen[$tool.id] = $true
                $details = @('STATUS', $status.Status, $status.Detail, '', 'REQUIRED', $tool.required, '', 'OPTIONAL', $tool.optional)
                $rows += New-DotfilesWorkbenchRow -Id $tool.id -Label $tool.label -Badge $status.Status -Role $(if ($status.Ready) { 3 } else { 4 }) -Details $details
            }
            foreach ($id in @($State.Statuses.Keys | Sort-Object)) {
                if ($seen.ContainsKey($id)) { continue }
                $status = $State.Statuses[$id]
                $rows += New-DotfilesWorkbenchRow -Id $id -Label $id -Badge $status.Status -Role $(if ($status.Ready) { 3 } else { 4 }) -Details @('STATUS', $status.Status, $status.Detail)
            }
            $empty = $State.ScanMessage
        }
        1 {
            $title = 'HANDLE MISSING TOOLS'; $intro = 'Choose how software should be handled. Nothing is installed yet.'; $label = 'SOFTWARE CHOICE'
            $choices = @(
                @('manual', 'I will handle software myself', 'Use your company portal or approved installer. Configurations can still be selected.'),
                @('install', 'Install selected missing tools', 'Queue the checked packages for installation after Review. WinGet uses user scope.'),
                @('skip', 'Skip tools with missing requirements', 'Only configure tools whose required programs are ready.')
            )
            foreach ($choice in $choices) {
                $disabled = $choice[0] -eq 'install' -and $State.SkipDependencies
                $details = @('SOFTWARE', $choice[2], '', '+ No changes until you apply the Review page.')
                if ($disabled) { $details += @('', '! Software installation was disabled by -SkipDependencies.') }
                $rows += New-DotfilesWorkbenchRow -Id $choice[0] -Label $choice[1] -Kind mode -Checked ($State.Mode -eq $choice[0]) -Disabled $disabled -Details $details
            }
            if ($State.Mode -eq 'install') {
                foreach ($package in $State.PackageItems) {
                    $rows += New-DotfilesWorkbenchRow -Id $package.Id -Label $package.Label -Kind package -Checked ([bool]$State.PackageChosen[$package.Id]) -Disabled $package.Disabled -Badge $(if ($package.Disabled) { 'MANUAL' } else { 'QUEUE' }) -Role $(if ($package.Disabled) { 5 } else { 2 }) -Details @('INSTALL METHOD', $package.Provider, '', 'STATUS', $State.Statuses[$package.Id].Detail, '', '! Package availability and versions will be checked again after installation.')
                }
            } else {
                foreach ($package in $State.PackageItems) { $rows += New-DotfilesWorkbenchRow -Id $package.Id -Label $package.Label -Badge 'Missing' -Role 4 -Details @('MISSING SOFTWARE', $State.Statuses[$package.Id].Detail, '', $package.Provider) }
            }
        }
        2 {
            $title = 'MAKE THIS SETUP YOURS'; $intro = 'Choose configurations to install or replace.'; $label = 'CONFIGURATIONS'
            foreach ($config in $State.Configs) {
                $chosen = [bool]$State.ConfigChosen[$config.Id]
                $action = if ($config.Disabled -or -not $chosen) { 'SKIP' } elseif ($config.Existing -and $config.Id -eq 'windows-terminal') { 'UPDATE' } elseif ($config.Existing) { 'REPLACE' } else { 'INSTALL' }
                $rows += New-DotfilesWorkbenchRow -Id $config.Id -Label $config.Label -Kind config -Checked $chosen -Disabled $config.Disabled -Badge $action -Role $(if ($chosen) { 2 } else { 1 }) -Details (Get-DotfilesWorkbenchConfigDetails $config)
            }
        }
        3 {
            $title = 'REVIEW YOUR CHANGES'; $intro = 'Everything is queued. Apply only when you are ready.'; $label = 'QUEUED CHANGES'
            foreach ($config in $State.Configs) {
                if ($config.Id -notin $selected) { continue }
                $rows += New-DotfilesWorkbenchRow -Id $config.Id -Label $config.Label -Badge $(if ($config.Existing -and $config.Id -eq 'windows-terminal') { 'UPDATE' } elseif ($config.Existing) { 'REPLACE' } else { 'INSTALL' }) -Role 2 -Details (Get-DotfilesWorkbenchConfigDetails $config)
            }
            foreach ($id in @(Get-DotfilesWorkbenchPackages $State)) {
                $rows += New-DotfilesWorkbenchRow -Id $id -Label "$id program" -Badge 'INSTALL' -Role 3 -Details @('SOFTWARE INSTALLATION', 'Selected software only. Missing permissions, package agreements or old versions may require manual installation.', '', 'BACKUP LOCATION', (Join-Path $State.Context.State 'backups'))
            }
            $empty = 'Nothing selected. You can go back or finish without changes.'
            if ($State.DryRun) { $intro = 'Preview only. No software, settings or backups will be changed.' }
        }
        4 {
            if ($State.Applying) {
                $title = 'APPLYING YOUR SETUP'; $intro = $State.CurrentOperation; $label = 'PROGRESS'
            } elseif ($State.DryRun) {
                $title = 'PREVIEW COMPLETE'; $intro = 'No software, configurations or backups were changed.'; $label = 'WOULD APPLY'
            } else {
                $failures = @($State.Results + $State.PackageResults | Where-Object { -not $_.Success }).Count
                $title = if ($failures) { 'SETUP NEEDS ATTENTION' } else { 'YOUR SETUP IS READY' }
                $intro = if ($failures) { 'Review the failed items below. Their diagnostics remain available.' } else { 'Reopen affected applications to use your settings.' }
                $label = 'RESULTS'
            }
            foreach ($result in @($State.Results) + @($State.PackageResults)) {
                $rows += New-DotfilesWorkbenchRow -Id $result.Id -Label $result.Id -Badge $(if ($result.Success) { 'DONE' } else { 'FAILED' }) -Role $(if ($result.Success) { 3 } else { 4 }) -Details @('RESULT', $result.Message, '', 'BACKUP RUN', $(if ($State.Run) { $State.Run.Directory } else { 'No configuration backup was needed.' }))
            }
            if ($State.DryRun) {
                foreach ($config in $State.Configs) {
                    if ($config.Id -in $selected) { $rows += New-DotfilesWorkbenchRow -Id $config.Id -Label $config.Label -Badge 'PREVIEW' -Role 2 -Details (Get-DotfilesWorkbenchConfigDetails $config) }
                }
            }
            if ($rows.Count -eq 0 -and $State.Applying) { $empty = $State.CurrentOperation }
            elseif ($rows.Count -eq 0) { $empty = 'No configuration changes were selected.' }
        }
    }
    if ($State.Cursor[$State.Page] -ge $rows.Count) { $State.Cursor[$State.Page] = [Math]::Max(0, $rows.Count - 1) }
    return [pscustomobject]@{ Title = $title; Intro = $intro; Label = $label; Rows = $rows; Empty = $empty }
}

function Update-DotfilesWorkbenchState($State, $Event) {
    if ($Event.Key -eq 'Resize') { return }
    $key = $Event.Key
    if ($Event.Control -and $key -eq 'C') { $key = 'Escape' }
    if ($State.Dialog) {
        if ($key -eq 'Escape' -or $key -eq 'N') { $State.Dialog = ''; return }
        if ($State.Dialog -eq 'help') { if ($key -in @('Enter', 'Spacebar', 'Oem2')) { $State.Dialog = '' }; return }
        if ($key -in @('LeftArrow','RightArrow','Tab')) { $State.DialogChoice = 1 - $State.DialogChoice }
        if ($key -eq 'Y' -or ($key -eq 'Enter' -and $State.DialogChoice -eq 1)) { $State.Exit = $true; $State.Cancelled = $true }
        elseif ($key -eq 'Enter') { $State.Dialog = '' }
        return
    }
    if ($key -eq 'Escape') {
        if ($State.Complete) { $State.Exit = $true } else { $State.Dialog = 'cancel'; $State.DialogChoice = 0 }
        return
    }
    if ($Event.Character -eq '?') { $State.Dialog = 'help'; return }
    if ($State.Applying) { return }
    if ($State.Complete -and $key -eq 'Enter') { $State.Exit = $true; return }
    if ($State.Complete -and $key -notin @('Tab','UpArrow','DownArrow','PageUp','PageDown','Home','End')) { return }
    if ($key -in @('Backspace','LeftArrow') -and $State.Page -gt 0) { $State.Page--; $State.DetailsFocused = $false; $State.DetailScroll = 0; return }
    if ($key -match '^D([1-4])$' -or $key -match '^NumPad([1-4])$') {
        $page = [int]$Matches[1] - 1
        if ($page -le $State.Visited) { $State.Page = $page; $State.DetailsFocused = $false; $State.DetailScroll = 0 }
        return
    }
    if ($key -eq 'Tab') { $State.DetailsFocused = -not $State.DetailsFocused; return }
    $pageModel = Get-DotfilesWorkbenchPage $State
    if ($key -in @('UpArrow','DownArrow','PageUp','PageDown','Home','End')) {
        $amount = switch ($key) { UpArrow { -1 } DownArrow { 1 } PageUp { -5 } PageDown { 5 } Home { -10000 } End { 10000 } }
        if ($State.DetailsFocused) { $State.DetailScroll = [Math]::Max(0, $State.DetailScroll + $amount) }
        else { $State.Cursor[$State.Page] = [Math]::Max(0, [Math]::Min($pageModel.Rows.Count - 1, $State.Cursor[$State.Page] + $amount)); $State.DetailScroll = 0 }
        return
    }
    if ($key -eq 'A' -and $State.Page -in @(1,2)) {
        $eligible = @($pageModel.Rows | Where-Object { -not $_.Disabled -and $_.Kind -in @('config','package') })
        $allSelected = @($eligible | Where-Object { -not $_.Checked }).Count -eq 0
        foreach ($row in $eligible) {
            if ($row.Kind -eq 'config') { $State.ConfigChosen[$row.Id] = -not $allSelected; $State.ConfigTouched[$row.Id] = $true }
            else { $State.PackageChosen[$row.Id] = -not $allSelected }
        }
        Update-DotfilesWorkbenchConfigurations $State
        return
    }
    if ($key -eq 'Spacebar' -and $pageModel.Rows.Count) {
        $row = $pageModel.Rows[$State.Cursor[$State.Page]]
        if ($row.Disabled) { return }
        switch ($row.Kind) {
            mode { $State.Mode = $row.Id; Update-DotfilesWorkbenchConfigurations $State }
            package { $State.PackageChosen[$row.Id] = -not $State.PackageChosen[$row.Id]; Update-DotfilesWorkbenchConfigurations $State }
            config { $State.ConfigChosen[$row.Id] = -not $State.ConfigChosen[$row.Id]; $State.ConfigTouched[$row.Id] = $true }
        }
        return
    }
    if ($key -in @('Enter','RightArrow')) {
        if ($State.Scanning -or $State.Complete) { return }
        if ($State.Page -eq 3) { if ($key -eq 'Enter') { $State.ApplyRequested = $true }; return }
        $State.Page++; $State.Visited = [Math]::Max($State.Visited, $State.Page); $State.DetailsFocused = $false; $State.DetailScroll = 0
        Update-DotfilesWorkbenchConfigurations $State
    }
}
