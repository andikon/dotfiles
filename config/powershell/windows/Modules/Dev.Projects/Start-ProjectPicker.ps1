#Requires -Version 7.2
param([switch]$Refresh)
$ErrorActionPreference = 'Stop'
$state = Join-Path $env:LOCALAPPDATA 'dotfiles/terminal-projects'
[void][IO.Directory]::CreateDirectory($state)
$mutex = [Threading.Mutex]::new($false, 'Local\Dotfiles.Terminal.ProjectPicker.Prepare')
$owned = $false
try {
    try { $owned = $mutex.WaitOne(0) } catch [Threading.AbandonedMutexException] { $owned = $true }
    if (-not $owned) { exit }
    $sources = @((Join-Path $PSScriptRoot 'ProjectPicker.cs'), (Join-Path $PSScriptRoot 'ProjectWindows.cs'))
    $framework = Join-Path $env:WINDIR 'Microsoft.NET/Framework64/v4.0.30319'
    if (-not (Test-Path $framework)) { $framework = Join-Path $env:WINDIR 'Microsoft.NET/Framework/v4.0.30319' }
    $references = @('WPF/UIAutomationClient.dll', 'WPF/UIAutomationTypes.dll', 'WPF/WindowsBase.dll', 'System.Web.Extensions.dll') | ForEach-Object { '/reference:' + (Join-Path $framework $_) }
    $hash = ($sources | Get-FileHash | ForEach-Object Hash) -join ''
    $exe = Join-Path $state 'picker.exe'
    $hashFile = Join-Path $state 'picker.hash'
    if (-not (Test-Path $exe) -or -not (Test-Path $hashFile) -or [IO.File]::ReadAllText($hashFile) -ne $hash) {
        $compiler = Join-Path $env:WINDIR 'Microsoft.NET/Framework64/v4.0.30319/csc.exe'
        if (-not (Test-Path $compiler)) { $compiler = Join-Path $env:WINDIR 'Microsoft.NET/Framework/v4.0.30319/csc.exe' }
        $stage = Join-Path $state "picker.$PID.exe"
        & $compiler /nologo /target:exe /optimize+ @references "/out:$stage" $sources
        if ($LASTEXITCODE -ne 0) { throw 'Console picker compilation failed.' }
        [IO.File]::Move($stage, $exe, $true)
        [IO.File]::WriteAllText($hashFile, $hash)
    }
    [IO.File]::WriteAllText((Join-Path $state 'picker.module.txt'), (Join-Path $PSScriptRoot 'Dev.Projects.psm1'))
    $snapshot = Join-Path $state 'picker.tsv'
    $cached = Get-Item $snapshot -ErrorAction SilentlyContinue
    if ($Refresh -or -not $cached -or ((Get-Date) - $cached.LastWriteTime).TotalSeconds -gt 60) {
        Import-Module (Join-Path $PSScriptRoot 'Dev.Projects.psm1') -Force
        $module = Get-Module Dev.Projects
        $projects = @(& $module { Get-ProjectCheckouts })
        $projects += @(& $module { param($File) Read-ProjectState $File } (Join-Path $state 'opened.json'))
        $lines = @($projects | Where-Object { $_ } | Sort-Object Path -Unique | ForEach-Object {
            $project = $_
            (@($project.Path, $project.Name, $project.Branch) | ForEach-Object {
                [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes([string]$_))
            }) -join "`t"
        })
        $temp = "$snapshot.$PID.tmp"
        [IO.File]::WriteAllLines($temp, [string[]]$lines)
        [IO.File]::Move($temp, $snapshot, $true)
    }
    [IO.File]::Delete((Join-Path $state 'picker-error.log'))
} catch {
    [IO.File]::WriteAllText((Join-Path $state 'picker-error.log'), ($_ | Out-String))
    exit 1
} finally {
    if ($owned) { $mutex.ReleaseMutex() }
    $mutex.Dispose()
}
