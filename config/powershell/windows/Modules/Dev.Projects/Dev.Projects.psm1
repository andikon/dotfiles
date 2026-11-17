function Get-ProjectId([string]$Path) {
    $bytes = [Text.Encoding]::UTF8.GetBytes($Path.ToUpperInvariant())
    'dotfiles-project-' + [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($bytes)).ToLowerInvariant()
}

function Get-ProjectTitle([string]$Path, [string]$Id) {
    "$(Split-Path -Leaf $Path) [$($Id.Substring($Id.Length - 8))]"
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

function proj {
    [CmdletBinding(DefaultParameterSetName = 'Picker')]
    param(
        [Parameter(ParameterSetName = 'Picker')][switch]$Active,
        [Parameter(ParameterSetName = 'Picker')][switch]$Refresh,
        [Parameter(ParameterSetName = 'Path', Mandatory)][string]$Path,
        [Parameter(ParameterSetName = 'Last', Mandatory)][switch]$Last,
        [switch]$NewTab,
        [ValidateSet('editor', 'full')][string]$Layout = 'editor',
        [switch]$PickerTab
    )
    if (-not $IsWindows) { Write-Warning 'Project windows require Windows Terminal on Windows.'; return }
    if (-not ('Dotfiles.ProjectWindows' -as [type])) {
        try { Add-Type -Path (Join-Path $PSScriptRoot 'ProjectWindows.cs') -ErrorAction Stop }
        catch {
            Write-Warning "Windows project switching could not load its window helper. $($_.Exception.Message)"
            return
        }
    }
    $stateDir = Join-Path $env:LOCALAPPDATA 'dotfiles/terminal-projects'
    [void][IO.Directory]::CreateDirectory($stateDir)
    $historyFile = Join-Path $stateDir 'history.json'
    $cacheFile = Join-Path $stateDir 'checkouts.json'
    $openedFile = Join-Path $stateDir 'opened.json'
    if ($Last) {
        $projectPath = (Read-ProjectState $historyFile).previous
        if (-not $projectPath) { Write-Warning 'No previous project window.'; return }
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
        if ($Active) {
            $projects = @($projects | Where-Object {
                $id = Get-ProjectId $_.Path
                [Dotfiles.ProjectWindows]::Find($id, (Get-ProjectTitle $_.Path $id)) -ne [IntPtr]::Zero
            })
        }
        if (-not $projects) { Write-Warning 'No matching project windows or checkouts.'; return }
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
        $window = [Dotfiles.ProjectWindows]::Find($id, $title)
        if ($window -ne [IntPtr]::Zero) {
            if ($NewTab) { Invoke-ProjectTerminal @('-w', $id, 'new-tab', '-d', $projectPath, 'pwsh.exe') }
            elseif (-not [Dotfiles.ProjectWindows]::Focus($window)) {
                Write-Warning 'Windows did not grant focus. Select the project window with Alt+Tab.'
                return
            }
        } else {
            if ($Active -or $Last) { Write-Warning 'That project window has closed.'; return }
            if (-not (Test-Path -LiteralPath $projectPath -PathType Container)) {
                Write-Warning 'The checkout is no longer on disk. Run proj -Refresh.'
                return
            }
            $editor = Get-Command nvim.exe -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
            $agent = if ($Layout -eq 'full') { Get-Command copilot.exe -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1 }
            if (-not $editor) { Write-Warning 'Neovim is unavailable. Opening PowerShell in the editor pane.' }
            if ($Layout -eq 'full' -and -not $agent) { Write-Warning 'Copilot is unavailable. Opening PowerShell in the agent pane.' }
            $launch = @('-w', $id, 'new-tab', '-d', $projectPath, '--title', $title, '--suppressApplicationTitle',
                $(if ($editor) { $editor.Source } else { 'pwsh.exe' }),
                ';', 'split-pane', '-V', '-d', $projectPath, '--title', $title, '--suppressApplicationTitle',
                $(if ($agent) { $agent.Source } else { 'pwsh.exe' }))
            if ($Layout -eq 'full') { $launch += @(';', 'split-pane', '-H', '-d', $projectPath, '--title', $title, '--suppressApplicationTitle', 'pwsh.exe') }
            $launch += @(';', 'move-focus', 'left')
            Invoke-ProjectTerminal $launch
            for ($attempt = 0; $attempt -lt 40; $attempt++) {
                $window = [Dotfiles.ProjectWindows]::Find($id, $title)
                if ($window -ne [IntPtr]::Zero) { break }
                Start-Sleep -Milliseconds 100
            }
            if ($window -eq [IntPtr]::Zero) {
                Write-Warning 'Windows Terminal did not confirm the project window. Check Alt+Tab before retrying.'
                return
            }
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

Export-ModuleMember -Function proj
