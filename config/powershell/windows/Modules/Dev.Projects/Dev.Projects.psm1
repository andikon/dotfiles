function Get-ProjectId([string]$Path) {
    $bytes = [Text.Encoding]::UTF8.GetBytes($Path.ToUpperInvariant())
    'dotfiles-project-' + [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($bytes)).ToLowerInvariant()
}

function Get-ProjectTitle([string]$Path, [string]$Id) {
    Split-Path -Leaf $Path
}

function Get-ProjectCheckouts {
    $roots = if ($env:DOTFILES_PROJECT_ROOTS) { $env:DOTFILES_PROJECT_ROOTS -split ';' } else {
        Join-Path $HOME 'Code'
        Join-Path $HOME 'projects'
    }
    $queue = [Collections.Generic.Queue[object]]::new()
    foreach ($root in $roots) { $queue.Enqueue(@($root, 0)) }
    $seen = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    while ($queue.Count) {
        $dir, $depth = $queue.Dequeue()
        if (-not (Test-Path -LiteralPath $dir -PathType Container)) { continue }
        if ((Test-Path -LiteralPath (Join-Path $dir '.git')) -or
            ((Test-Path -LiteralPath (Join-Path $dir 'HEAD')) -and (Test-Path -LiteralPath (Join-Path $dir 'objects')))) {
            $lines = @(git -C $dir -c core.quotePath=false worktree list --porcelain 2>$null)
            $checkout = $branch = $null
            foreach ($line in ($lines + '')) {
                if ($line.StartsWith('worktree ')) { $checkout = $line.Substring(9); $branch = 'detached' }
                elseif ($line.StartsWith('branch refs/heads/')) { $branch = $line.Substring(18) }
                elseif ($line -eq 'bare' -or $line.StartsWith('prunable')) { $checkout = $null }
                elseif ($line -eq '' -and $checkout) {
                    $path = [IO.Path]::GetFullPath($checkout)
                    if ((Test-Path -LiteralPath $path -PathType Container) -and $seen.Add($path)) {
                        [pscustomobject]@{ Path = $path; Name = Split-Path -Leaf $path; Branch = $branch }
                    }
                    $checkout = $null
                }
            }
            continue
        }
        if ($depth -ge 4) { continue }
        foreach ($child in (Get-ChildItem -LiteralPath $dir -Directory -ErrorAction SilentlyContinue)) {
            if (-not ($child.Attributes -band [IO.FileAttributes]::ReparsePoint)) {
                $queue.Enqueue(@($child.FullName, ($depth + 1)))
            }
        }
    }
}

function Select-ProjectCheckout($Projects) {
    if ([Console]::IsInputRedirected) { Write-Warning 'Use proj -Path in a noninteractive shell.'; return }
    $query = ''
    $index = 0
    $normal = $pendingG = $false
    $rows = 0
    try {
        while ($true) {
            $words = @($query -split '\s+' | Where-Object { $_ })
            $matches = @($Projects | Where-Object {
                $label = "$($_.Name) $($_.Branch) $($_.Path)"
                -not ($words | Where-Object { $label.IndexOf($_, [StringComparison]::OrdinalIgnoreCase) -lt 0 })
            })
            $index = [Math]::Max(0, [Math]::Min($index, $matches.Count - 1))
            $height = [Math]::Max(1, [Math]::Min(10, [Console]::WindowHeight - 3))
            $start = [Math]::Max(0, $index - $height + 1)
            if ($rows) { [Console]::Write(("`e[{0}F`e[J" -f $rows)) }
            $width = [Math]::Max(1, [Console]::WindowWidth - 3)
            $prompt = "{0}> {1}" -f $(if ($normal) { 'NORMAL' } else { 'Projects' }), $query
            Write-Host $prompt.Substring(0, [Math]::Min($width, $prompt.Length))
            $rows = 1
            for ($i = $start; $i -lt [Math]::Min($matches.Count, $start + $height); $i++) {
                $entry = $matches[$i]
                $line = "{0} {1}  [{2}]  {3}" -f $(if ($i -eq $index) { '>' } else { ' ' }), $entry.Name, $entry.Branch, $entry.Path
                Write-Host $line.Substring(0, [Math]::Min($width, $line.Length))
                $rows++
            }
            $key = [Console]::ReadKey($true)
            $ctrl = [bool]($key.Modifiers -band [ConsoleModifiers]::Control)
            if (($ctrl -and $key.Key -in @('Oem4', 'Escape')) -or $key.Key -eq 'Tab') { $normal = -not $normal; continue }
            if ($key.Key -eq 'Escape') { return }
            if ($key.Key -eq 'Enter') { if ($matches.Count) { return $matches[$index] }; continue }
            if ($key.Key -eq 'DownArrow' -or ($ctrl -and $key.Key -eq 'J') -or ($normal -and $key.KeyChar -ceq 'j')) { $index++; $pendingG = $false; continue }
            if ($key.Key -eq 'UpArrow' -or ($ctrl -and $key.Key -eq 'K') -or ($normal -and $key.KeyChar -ceq 'k')) { $index--; $pendingG = $false; continue }
            if ($normal) {
                if ($key.KeyChar -ceq 'g') {
                    if ($pendingG) { $index = 0 }
                    $pendingG = -not $pendingG
                } else {
                    $pendingG = $false
                    if ($key.KeyChar -ceq 'G') { $index = $matches.Count - 1 }
                    if ($key.KeyChar -eq '/') { $normal = $false }
                }
            } elseif ($key.Key -eq 'Backspace' -and $query.Length) {
                $query = $query.Substring(0, $query.Length - 1); $index = 0
            } elseif (-not [char]::IsControl($key.KeyChar)) {
                $query += $key.KeyChar; $index = 0
            }
        }
    } finally {
        if ($rows) { [Console]::Write(("`e[{0}F`e[J" -f $rows)) }
    }
}

function Invoke-ProjectTerminal([string[]]$Arguments) {
    $start = [Diagnostics.ProcessStartInfo]::new((Get-Command wt.exe -CommandType Application -ErrorAction Stop).Source)
    foreach ($arg in $Arguments) {
        # Only the standalone separators supplied by the layout are commands.
        $start.ArgumentList.Add($(if ($arg -eq ';') { $arg } else { $arg.Replace(';', '\;') }))
    }
    [Diagnostics.Process]::Start($start).Dispose()
}

function Read-ProjectState([string]$File) {
    try { Get-Content -LiteralPath $File -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop }
    catch { $null }
}

function Write-ProjectState([string]$File, $Value) {
    $temp = "$File.$PID.tmp"
    [IO.File]::WriteAllText($temp, (ConvertTo-Json -InputObject $Value))
    [IO.File]::Move($temp, $File, $true)
}

function Get-ProjectTabs {
    if (-not ('Dotfiles.ProjectWindows' -as [type])) {
        Add-Type -Path (Join-Path $PSScriptRoot 'ProjectWindows.cs') -ErrorAction Stop
    }
    $window = [Dotfiles.ProjectWindows]::CurrentTerminalWindow()
    if ($window -eq [IntPtr]::Zero) { throw 'Run proj inside the Windows Terminal window where the project should open.' }
    Add-Type -AssemblyName UIAutomationClient, UIAutomationTypes -ErrorAction Stop
    $root = [System.Windows.Automation.AutomationElement]::FromHandle($window)
    $condition = [System.Windows.Automation.PropertyCondition]::new(
        [System.Windows.Automation.AutomationElement]::ControlTypeProperty,
        [System.Windows.Automation.ControlType]::TabItem)
    $tabs = $root.FindAll([System.Windows.Automation.TreeScope]::Descendants, $condition)
    if ($tabs.Count -eq 0) { throw 'Windows Terminal did not expose its tabs to UI Automation.' }
    foreach ($tab in $tabs) {
        [pscustomobject]@{ Name = $tab.Current.Name; Element = $tab }
    }
}

function proj {
    [CmdletBinding(DefaultParameterSetName = 'Picker')]
    param(
        [Parameter(ParameterSetName = 'Picker')][switch]$Active,
        [Parameter(ParameterSetName = 'Picker')][switch]$Refresh,
        [Parameter(ParameterSetName = 'Path', Mandatory)][string]$Path,
        [Parameter(ParameterSetName = 'Last', Mandatory)][switch]$Last,
        [switch]$NewTab,
        [switch]$PickerTab
    )
    if (-not $IsWindows) { Write-Warning 'Project tabs require Windows Terminal on Windows.'; return }
    $stateDir = Join-Path $env:LOCALAPPDATA 'dotfiles/terminal-projects'
    [void][IO.Directory]::CreateDirectory($stateDir)
    $historyFile = Join-Path $stateDir 'history.json'
    $cacheFile = Join-Path $stateDir 'checkouts.json'
    $openedFile = Join-Path $stateDir 'opened.json'
    if ($Last) {
        $projectPath = (Read-ProjectState $historyFile).previous
        if (-not $projectPath) { Write-Warning 'No previous project tab.'; return }
    } elseif ($PSCmdlet.ParameterSetName -eq 'Path') {
        $resolved = (Resolve-Path -LiteralPath $Path -ErrorAction Stop).ProviderPath
        $projectPath = git -C $resolved rev-parse --show-toplevel 2>$null
        if ($LASTEXITCODE -ne 0) { Write-Warning 'Select a directory inside a Git checkout.'; return }
    } else {
        $cache = Get-Item -LiteralPath $cacheFile -ErrorAction SilentlyContinue
        $projects = if (-not $Refresh -and $cache -and ((Get-Date) - $cache.LastWriteTime).TotalSeconds -lt 60) {
            Read-ProjectState $cacheFile
        }
        if (-not $projects) {
            $projects = @(Get-ProjectCheckouts | Sort-Object Name, Path)
            Write-ProjectState $cacheFile $projects
        }
        $projects = @(@($projects) + @(Read-ProjectState $openedFile) |
            Where-Object { $_ -and (Test-Path -LiteralPath $_.Path -PathType Container) } |
            Sort-Object -Property Path -Unique)
        $tabs = @(Get-ProjectTabs)
        if ($Active) {
            $projects = @($projects | Where-Object {
                (Get-ProjectTitle $_.Path (Get-ProjectId $_.Path)) -in $tabs.Name
            })
        }
        if (-not $projects) { Write-Warning 'No matching project tabs or checkouts.'; return }
        $selected = Select-ProjectCheckout @($projects)
        if (-not $selected) { if ($PickerTab) { exit }; return }
        $projectPath = $selected.Path
    }

    $projectPath = [IO.Path]::GetFullPath($projectPath)
    $id = Get-ProjectId $projectPath
    $title = Get-ProjectTitle $projectPath $id
    $mutex = [Threading.Mutex]::new($false, 'Local\Dotfiles.Terminal.Projects')
    $locked = $false
    try {
        try { $locked = $mutex.WaitOne(8000) }
        catch [Threading.AbandonedMutexException] { $locked = $true }
        if (-not $locked) { Write-Warning 'Another project is opening. Try again.'; return }
        $tabs = @(Get-ProjectTabs)
        $tab = $tabs | Where-Object Name -eq $title | Select-Object -First 1
        # Plain titles can collide across checkouts; open rather than focus a wrong project.
        $otherPaths = @(@(Read-ProjectState $cacheFile) + @(Read-ProjectState $openedFile) | Where-Object {
            $_ -and $_.Path -ne $projectPath -and (Split-Path -Leaf $_.Path) -eq $title
        })
        if ($otherPaths.Count) { $tab = $null }
        if ($tab -and -not $NewTab) {
            $pattern = $tab.Element.GetCurrentPattern([System.Windows.Automation.SelectionItemPattern]::Pattern)
            $pattern.Select()
        } elseif ($tab -and $NewTab) {
            Invoke-ProjectTerminal @('-w', '0', 'new-tab', '-d', $projectPath, 'pwsh.exe')
        } else {
            if ($Active -or $Last) { Write-Warning 'That project tab has closed.'; return }
            if (-not (Test-Path -LiteralPath $projectPath -PathType Container)) {
                Write-Warning 'The checkout is no longer on disk. Run proj -Refresh.'
                return
            }
            Invoke-ProjectTerminal @('-w', '0', 'new-tab', '-d', $projectPath,
                '--title', $title, '--suppressApplicationTitle', 'pwsh.exe', '-NoLogo')
        }

        $current = Read-ProjectState $historyFile
        if ($current.current -ne $projectPath) {
            Write-ProjectState $historyFile @{ current = $projectPath; previous = $current.current }
        }
        $opened = @(Read-ProjectState $openedFile | Where-Object { $_ -and $_.Path -ne $projectPath })
        $branch = git -C $projectPath branch --show-current 2>$null
        $opened += [pscustomobject]@{
            Path = $projectPath
            Name = Split-Path -Leaf $projectPath
            Branch = if ($branch) { $branch } else { 'detached' }
        }
        Write-ProjectState $openedFile $opened
    } finally {
        if ($locked) { $mutex.ReleaseMutex() }
        $mutex.Dispose()
    }
    if ($PickerTab) { exit }
}

function Start-ProjectPicker {
    if (-not $IsWindows -or -not $env:WT_SESSION -or $env:WEZTERM_PANE) { return }
    # Retire an older GUI helper when migrating to the terminal executable.
    Stop-ProjectPicker
    $state = Join-Path $env:LOCALAPPDATA 'dotfiles/terminal-projects'
    $exe = Join-Path $state 'picker.exe'
    $hashFile = Join-Path $state 'picker.hash'
    $snapshot = Get-Item (Join-Path $state 'picker.tsv') -ErrorAction SilentlyContinue
    if ((Test-Path $exe) -and (Test-Path $hashFile) -and $snapshot -and
        ((Get-Date) - $snapshot.LastWriteTime).TotalSeconds -lt 60) {
        $hash = (@('ProjectPicker.cs', 'ProjectWindows.cs') | ForEach-Object {
            Get-FileHash (Join-Path $PSScriptRoot $_) | ForEach-Object Hash
        }) -join ''
        if ([IO.File]::ReadAllText($hashFile) -eq $hash) { return }
    }
    $start = [Diagnostics.ProcessStartInfo]::new((Get-Process -Id $PID).Path)
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    $start.WindowStyle = 'Hidden'
    foreach ($arg in @('-NoLogo', '-NoProfile', '-File', (Join-Path $PSScriptRoot 'Start-ProjectPicker.ps1'))) {
        $start.ArgumentList.Add($arg)
    }
    [Diagnostics.Process]::Start($start).Dispose()
}

function Stop-ProjectPicker {
    $stop = $null
    if ([Threading.EventWaitHandle]::TryOpenExisting('Local\Dotfiles.Terminal.ProjectPicker.Stop', [ref]$stop)) {
        [void]$stop.Set()
        $stop.Dispose()
    }
}

Export-ModuleMember -Function proj, Start-ProjectPicker, Stop-ProjectPicker
