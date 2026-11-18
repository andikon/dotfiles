#Requires -Version 7.2
param([int]$BudgetMilliseconds = 200)
$ErrorActionPreference = 'Stop'
$root = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$module = Join-Path $root 'config/powershell/windows/Modules/Dev.Projects'
$settings = Get-Content (Join-Path $root 'config/windows-terminal/windows/settings.json') -Raw | ConvertFrom-Json
foreach ($key in @('alt+f', 'alt+w')) {
    $binding = $settings.keybindings | Where-Object keys -eq $key
    $action = $settings.actions | Where-Object id -eq $binding.id
    if (($key -eq 'alt+f' -and ($action.command.action -ne 'newTab' -or $action.command.commandline -notlike '*picker.exe*')) -or
        ($key -eq 'alt+w' -and $action.command.action -ne 'tabSearch')) {
        throw "$key must open or search project tabs."
    }
}
$fixture = Join-Path ([IO.Path]::GetTempPath()) ('dotfiles-tui-test-' + [guid]::NewGuid())
[void][IO.Directory]::CreateDirectory($fixture)
try {
    $compiler = Join-Path $env:WINDIR 'Microsoft.NET/Framework64/v4.0.30319/csc.exe'
    $framework = Join-Path $env:WINDIR 'Microsoft.NET/Framework64/v4.0.30319'
    if (-not (Test-Path $framework)) { $framework = Join-Path $env:WINDIR 'Microsoft.NET/Framework/v4.0.30319' }
    $references = @('WPF/UIAutomationClient.dll', 'WPF/UIAutomationTypes.dll', 'WPF/WindowsBase.dll', 'System.Web.Extensions.dll') | ForEach-Object { '/reference:' + (Join-Path $framework $_) }
    $exe = Join-Path $fixture 'picker.exe'
    & $compiler /nologo /target:exe /optimize+ @references "/out:$exe" (Join-Path $module 'ProjectPicker.cs') (Join-Path $module 'ProjectWindows.cs')
    if ($LASTEXITCODE -ne 0) { throw 'Compilation failed.' }
    $lines = @(0..999 | ForEach-Object {
        (@("C:\Code\project-$_", "project-$_", "feature/branch-$_") | ForEach-Object {
            [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($_))
        }) -join "`t"
    })
    [IO.File]::WriteAllLines((Join-Path $fixture 'picker.tsv'), [string[]]$lines)
    $capture = Join-Path $fixture 'launch.txt'
    $recorder = Join-Path $fixture 'capture.exe'
    $recorderSource = Join-Path $fixture 'Capture.cs'
    [IO.File]::WriteAllText($recorderSource, 'using System; using System.IO; class Capture { static void Main(string[] args) { File.WriteAllLines(Environment.GetEnvironmentVariable("DOTFILES_TEST_LAUNCH_CAPTURE"), args); } }')
    & $compiler /nologo /target:exe /optimize+ @references "/out:$recorder" $recorderSource
    if ($LASTEXITCODE -ne 0) { throw 'Recorder compilation failed.' }
    $previousCapture = $env:DOTFILES_TEST_LAUNCH_CAPTURE
    try {
        $env:DOTFILES_TEST_LAUNCH_CAPTURE = $capture
        $projectPath = Join-Path $fixture "work space's;project"
        [void][IO.Directory]::CreateDirectory($projectPath)
        $launchTimes = @()
        foreach ($iteration in 1..20) {
            $elapsed = [double]::Parse((& $exe --benchmark-open $recorder $projectPath), [Globalization.CultureInfo]::InvariantCulture)
            $launchTimes += $elapsed
            if ($LASTEXITCODE -ne 0 -or -not (Test-Path $capture)) { throw 'Selection did not reach the terminal launcher.' }
            $launch = [IO.File]::ReadAllLines($capture)
            if ($launch[0] -ne '-w' -or $launch[1] -ne '0' -or $launch[2] -ne 'new-tab' -or $launch -notcontains '{574e775e-4f2a-5b96-ac1e-a2962a402336}' -or $launch -notcontains '--inheritEnvironment' -or $launch -notcontains $projectPath.Replace(';', '\;')) { throw 'Native selection lost current-window routing, shell or checkout arguments.' }
            if ($launch[[array]::IndexOf($launch, '--title') + 1] -ne (Split-Path -Leaf $projectPath).Replace(';', '\;')) { throw 'Native tab title must show only the checkout name.' }
            if ($elapsed -ge $BudgetMilliseconds) { throw "Selection-to-launch exceeded $BudgetMilliseconds ms." }
        }
        Write-Host ("Selection to terminal recorder completion: max {0:N1} ms" -f ($launchTimes | Measure-Object -Maximum).Maximum)
        Write-Host 'PASS: selection reaches the native terminal launcher within budget, including spaces, apostrophes and semicolons.'
    } finally { $env:DOTFILES_TEST_LAUNCH_CAPTURE = $previousCapture }
    foreach ($geometry in @(@(100, 20), @(45, 12), @(12, 5))) {
        $screen = (& $exe --render $geometry[0] $geometry[1] 'project-99') -join "`n"
        $plain = $screen -replace '\x1b\[[0-9;?]*[A-Za-z]', ''
        $rows = $plain -split "`r?`n"
        if ($rows.Count -ne $geometry[1] -or @($rows | Where-Object Length -gt $geometry[0]).Count) { throw 'Picker layout overflows the viewport.' }
        if ($geometry[0] -ge 45 -and ($plain -notlike '*PROJECTS*' -or $plain -notlike '*Search / project-99*' -or $plain -notlike '*Enter open*')) { throw 'Picker header, query or help is missing.' }
    }
    $screen = (& $exe --render 80 12 'no-such-project') -join "`n"
    if ($screen -notlike '*No matches*') { throw 'Empty filtering needs an explicit empty state.' }
    & $exe --record-selection $fixture main
    & $exe --record-selection $projectPath feature/work
    $history = Get-Content (Join-Path $fixture 'history.json') -Raw | ConvertFrom-Json
    $opened = @(Get-Content (Join-Path $fixture 'opened.json') -Raw | ConvertFrom-Json)
    if ($history.current -ne $projectPath -or $history.previous -ne $fixture -or $opened.Count -ne 2 -or $opened[1].Branch -ne 'feature/work') { throw 'Native selection lost project history or worktree metadata.' }
    Write-Host 'PASS: responsive TUI layout, empty state and native selection history.'
    $times = @()
    foreach ($iteration in 1..20) {
        $timer = [Diagnostics.Stopwatch]::StartNew()
        $info = [Diagnostics.ProcessStartInfo]::new($exe, '--benchmark')
        $info.UseShellExecute = $false
        $info.RedirectStandardOutput = $true
        $info.CreateNoWindow = $true
        $process = [Diagnostics.Process]::Start($info)
        $rendered = $process.StandardOutput.ReadToEnd()
        $process.WaitForExit()
        $elapsed = $timer.Elapsed.TotalMilliseconds
        if ($process.ExitCode -ne 0 -or $rendered -notlike '*11 results*') { throw 'First input did not filter rendered results.' }
        $times += $elapsed
        $process.Dispose()
    }
    $maximum = ($times | Measure-Object -Maximum).Maximum
    Write-Host ("Console process launch + snapshot load + first render and filter, 1,000 projects: first {0:N1} ms, max {1:N1} ms" -f $times[0], $maximum)
    if ($maximum -ge $BudgetMilliseconds) { throw "Picker exceeded $BudgetMilliseconds ms." }
    Write-Host 'PASS: Terminal tab shortcuts and console startup/filter latency.'
} finally {
    $absolute = [IO.Path]::GetFullPath($fixture)
    $boundary = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
    if ($absolute.StartsWith($boundary + 'dotfiles-tui-test-', [StringComparison]::OrdinalIgnoreCase)) {
        Remove-Item -LiteralPath $absolute -Recurse -Force
    }
}
