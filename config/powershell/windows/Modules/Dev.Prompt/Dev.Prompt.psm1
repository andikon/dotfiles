# One asynchronous Git query at a time; never wait for Git while drawing a prompt.
$script:gitCache = @{}
$script:gitQuery = $null
function Get-PromptGit([string]$Directory) {
    if ($script:gitQuery -and $script:gitQuery.Handle.IsCompleted) {
        $query = $script:gitQuery
        try {
            $value = @($query.PowerShell.EndInvoke($query.Handle)) | Select-Object -Last 1
            if ($script:gitCache.Count -ge 32) { $script:gitCache.Clear() }
            $script:gitCache[$query.Directory] = @{ Value = $value; Updated = [DateTime]::UtcNow }
        } catch { } finally { $query.PowerShell.Dispose(); $script:gitQuery = $null }
    }
    $cached = $script:gitCache[$Directory]
    if (-not $script:gitQuery -and (-not $cached -or ([DateTime]::UtcNow - $cached.Updated).TotalSeconds -ge 2)) {
        $worker = [PowerShell]::Create()
        [void]$worker.AddScript({
            param($directory)
            $lines = @(git --no-optional-locks -C $directory status --porcelain=v1 --branch 2>$null)
            if ($LASTEXITCODE -ne 0 -or -not $lines.Count) { return }
            $branch = $lines[0] -replace '^## (No commits yet on |Initial commit on )?', '' -replace '\.\..*$', ''
            $files = @($lines | Select-Object -Skip 1)
            [pscustomobject]@{
                Branch = $branch
                Staged = @($files | Where-Object { $_ -match '^[AMDRCT]' }).Count
                Modified = @($files | Where-Object { $_ -match '^.[MT]' }).Count
                Deleted = @($files | Where-Object { $_ -match '^.D' }).Count
                Untracked = @($files | Where-Object { $_ -match '^\?\?' }).Count
                Conflicts = @($files | Where-Object { $_ -match '^(DD|AU|UD|UA|DU|AA|UU)' }).Count
            }
        }).AddArgument($Directory)
        $script:gitQuery = @{ PowerShell = $worker; Handle = $worker.BeginInvoke(); Directory = $Directory }
    }
    if ($cached) { return $cached.Value }
}

function prompt {

    # Report the shell's directory so terminals can duplicate the focused pane's cwd.
    if ($env:WT_SESSION -and $PWD.Provider.Name -eq 'FileSystem') {
        [Console]::Write("$([char]27)]9;9;`"$($PWD.ProviderPath)`"$([char]27)\")
    }
    if ($env:WEZTERM_PANE -and $PWD.Provider.Name -eq 'FileSystem') {
        $directoryUri = [Uri]::new($PWD.ProviderPath)
        [Console]::Write("$([char]27)]7;$($directoryUri.AbsoluteUri)$([char]27)\")
    }

    function Write-Colored($text, $color) {
        Write-Host $text -NoNewline -ForegroundColor $color
    }

    function Get-TruncatedPath {
        $path = (Get-Location).Path

        $parts = $path -split '[\\/]' | Where-Object { $_ }
        if ($parts.Count -gt 3) {
            $parts = $parts[-3..-1]
        }

        ($parts -join '/')
    }

    # directory
    Write-Colored (Get-TruncatedPath) Cyan

    # read-only indicator
    if (-not (Test-Path . -PathType Container -ErrorAction SilentlyContinue)) {
        Write-Colored " " DarkGray
    }

    $git = if ($PWD.Provider.Name -eq 'FileSystem') { Get-PromptGit $PWD.ProviderPath }
    if ($git) {
        Write-Colored "  $($git.Branch)" Yellow
        $changes = @()
        if ($git.Staged) { $changes += "+$($git.Staged)" }
        if ($git.Modified) { $changes += "~$($git.Modified)" }
        if ($git.Deleted) { $changes += "-$($git.Deleted)" }
        if ($git.Untracked) { $changes += "?$($git.Untracked)" }
        if ($git.Conflicts) { $changes += "!$($git.Conflicts)" }
        if ($changes.Count) { Write-Colored ("  " + ($changes -join ' ')) DarkGray }
    }
    Write-Host ""
    Write-Colored "_ " Green

    if ($env:DOTFILES_PROJECT_LAUNCH_TICKS) {
        $started = 0L
        if ([long]::TryParse($env:DOTFILES_PROJECT_LAUNCH_TICKS, [ref]$started) -and $env:LOCALAPPDATA) {
            $elapsed = ([DateTime]::UtcNow.Ticks - $started) / 10000.0
            $state = Join-Path $env:LOCALAPPDATA 'dotfiles/terminal-projects'
            try {
                [void][IO.Directory]::CreateDirectory($state)
                [IO.File]::WriteAllText((Join-Path $state 'picker-last-launch.json'),
                    (ConvertTo-Json @{ ReadyMilliseconds = [Math]::Round($elapsed, 1); BudgetMet = $elapsed -lt 200 }))
            } catch { } # Timing must never prevent a usable prompt.
        }
        Remove-Item Env:DOTFILES_PROJECT_LAUNCH_TICKS
    }

    return " "
}

$ExecutionContext.SessionState.Module.OnRemove = {
    if ($script:gitQuery) {
        $script:gitQuery.PowerShell.Stop()
        $script:gitQuery.PowerShell.Dispose()
    }
}
Export-ModuleMember -Function prompt
