#Requires -Version 5.1
$ErrorActionPreference = 'Stop'
$root = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$fixture = Join-Path ([IO.Path]::GetTempPath()) ('dotfiles-prompt-' + [guid]::NewGuid())
try {
    [void][IO.Directory]::CreateDirectory($fixture)
    git -C $fixture init -b prompt-test | Out-Null
    [IO.File]::WriteAllText((Join-Path $fixture 'staged.txt'), 'staged')
    [IO.File]::WriteAllText((Join-Path $fixture 'untracked.txt'), 'untracked')
    git -C $fixture add staged.txt
    $module = Import-Module (Join-Path $root 'config/powershell/windows/Modules/Dev.Prompt/Dev.Prompt.psm1') -Force -PassThru
    & $module {
        param($Directory)
        $null = Get-PromptGit $Directory
        $deadline = [DateTime]::UtcNow.AddSeconds(10)
        while (-not $script:gitQuery.Handle.IsCompleted -and [DateTime]::UtcNow -lt $deadline) { Start-Sleep -Milliseconds 20 }
        if (-not $script:gitQuery.Handle.IsCompleted) { throw 'Git worker never finished.' }
        $result = Get-PromptGit $Directory
        if ($result.Branch -ne 'prompt-test' -or $result.Staged -ne 1 -or $result.Untracked -ne 1) { throw 'Async Git state was incorrect.' }
        if (Get-PromptGit ([IO.Path]::GetTempPath())) { throw 'Changing directories reused another checkout status.' }
        while (-not $script:gitQuery.Handle.IsCompleted) { Start-Sleep -Milliseconds 20 }
        $null = Get-PromptGit ([IO.Path]::GetTempPath())
        # Simulate a genuinely slow Git worker. Drawing from cache must never wait.
        $worker = [PowerShell]::Create()
        [void]$worker.AddScript({ Start-Sleep -Seconds 3 })
        $script:gitQuery = @{ PowerShell = $worker; Handle = $worker.BeginInvoke(); Directory = $Directory }
        $timer = [Diagnostics.Stopwatch]::StartNew()
        $result = Get-PromptGit $Directory
        if ($timer.ElapsedMilliseconds -ge 200 -or $result.Branch -ne 'prompt-test') { throw 'A slow Git query blocked cached prompt state.' }
    } $fixture
    Write-Host 'PASS: async Git status, per-directory isolation, staged/untracked counts and nonblocking cached reads.'
} finally {
    Remove-Module Dev.Prompt -ErrorAction SilentlyContinue
    $absolute = [IO.Path]::GetFullPath($fixture)
    $boundary = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
    if ($absolute.StartsWith($boundary + 'dotfiles-prompt-', [StringComparison]::OrdinalIgnoreCase)) { Remove-Item -LiteralPath $absolute -Recurse -Force }
}
