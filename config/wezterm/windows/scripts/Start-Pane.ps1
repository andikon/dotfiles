#Requires -Version 7
param(
    [Parameter(Mandatory)][ValidateSet('editor', 'agent')][string]$Role,
    [Parameter(Mandatory)][string]$Program
)

$command = Get-Command -Name $Program -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $command) {
    Write-Host "$Program is not on PATH. See docs/tools/windows-dependencies.md, then run it here." -ForegroundColor Yellow
    return
}

# -NoExit leaves this pane as a useful project shell when the editor/agent exits.
& $command.Source
