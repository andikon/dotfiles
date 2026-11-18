#Requires -Version 5.1
$ErrorActionPreference = 'Stop'
$root = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$originalWriter = [Console]::Out
$originalSession = $env:WT_SESSION
$originalWezTerm = $env:WEZTERM_PANE
$originalCwd = Get-Location
$originalLocal = $env:LOCALAPPDATA
$originalTicks = $env:DOTFILES_PROJECT_LAUNCH_TICKS
$fixture = Join-Path ([IO.Path]::GetTempPath()) ('dotfiles-cwd-' + [guid]::NewGuid())
try {
    $env:WT_SESSION = 'test'
    $env:WEZTERM_PANE = $null
    $env:LOCALAPPDATA = Join-Path $fixture 'local-state'
    $env:DOTFILES_PROJECT_LAUNCH_TICKS = [DateTime]::UtcNow.Ticks.ToString()
    New-Item -ItemType Directory -Path (Join-Path $fixture 'nested folder') -Force | Out-Null
    git -C $fixture init -b main | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'Git fixture initialization failed.' }
    Import-Module (Join-Path $root 'config/powershell/windows/Modules/Dev.Prompt/Dev.Prompt.psm1') -Force
    foreach ($directory in @($fixture, (Join-Path $fixture 'nested folder'))) {
        Set-Location -LiteralPath $directory
        $captured = [IO.StringWriter]::new()
        [Console]::SetOut($captured)
        prompt | Out-Null
        [Console]::SetOut($originalWriter)
        $expected = "$([char]27)]9;9;`"$($PWD.ProviderPath)`"$([char]27)\"
        if (-not $captured.ToString().Contains($expected)) { throw 'The prompt did not report the current pane directory.' }
    }
    $metric = Get-Content (Join-Path $env:LOCALAPPDATA 'dotfiles/terminal-projects/picker-last-launch.json') -Raw | ConvertFrom-Json
    if ($metric.ReadyMilliseconds -le 0 -or $metric.BudgetMet -ne ($metric.ReadyMilliseconds -lt 200) -or $env:DOTFILES_PROJECT_LAUNCH_TICKS) {
        throw 'First prompt must record actual launch readiness and clear the one-shot timestamp.'
    }
    $settings = Get-Content (Join-Path $root 'config/windows-terminal/windows/settings.json') -Raw | ConvertFrom-Json
    foreach ($key in @('alt+v', 'alt+s')) {
        $binding = $settings.keybindings | Where-Object keys -eq $key
        $action = $settings.actions | Where-Object id -eq $binding.id
        if ($action.command.splitMode -ne 'duplicate' -or $action.command.commandline -notlike 'pwsh.exe*') {
            throw 'Splits must inherit the focused pane directory and launch PowerShell.'
        }
    }
    $originalWriter.WriteLine('PASS: pane cwd reporting follows cd, and both split bindings inherit it.')
} finally {
    [Console]::SetOut($originalWriter)
    Set-Location -LiteralPath $originalCwd.ProviderPath
    $env:WT_SESSION = $originalSession
    $env:WEZTERM_PANE = $originalWezTerm
    $env:LOCALAPPDATA = $originalLocal
    $env:DOTFILES_PROJECT_LAUNCH_TICKS = $originalTicks
    Remove-Module Dev.Prompt -ErrorAction SilentlyContinue
    $absolute = [IO.Path]::GetFullPath($fixture)
    $boundary = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
    if ($absolute.StartsWith($boundary + 'dotfiles-cwd-', [StringComparison]::OrdinalIgnoreCase)) {
        Remove-Item -LiteralPath $absolute -Recurse -Force
    }
}
