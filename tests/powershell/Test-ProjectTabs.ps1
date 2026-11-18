#Requires -Version 7.2
$ErrorActionPreference = 'Stop'
$root = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$fixture = Join-Path ([IO.Path]::GetTempPath()) ('dotfiles-project-tabs-' + [guid]::NewGuid())
$previousLocal = $env:LOCALAPPDATA
try {
    $env:LOCALAPPDATA = Join-Path $fixture 'state'
    $checkout = Join-Path $fixture "checkout with space & apostrophe's"
    New-Item -ItemType Directory -Path $checkout -Force | Out-Null
    git -C $checkout init -b main | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'Git fixture failed.' }
    Add-Type -AssemblyName UIAutomationClient, UIAutomationTypes
    $module = Import-Module (Join-Path $root 'config/powershell/windows/Modules/Dev.Projects/Dev.Projects.psm1') -Force -PassThru
    & $module {
        $script:tabs = @()
        $script:launches = [Collections.Generic.List[object]]::new()
        function script:Get-ProjectTabs { $script:tabs }
        function script:Invoke-ProjectTerminal([string[]]$Arguments) { $script:launches.Add($Arguments) }
    }
    proj -Path $checkout
    & $module {
        if ($script:launches.Count -ne 1) { throw 'Expected one new project tab.' }
        $arguments = $script:launches[0]
        if ($arguments[0] -ne '-w' -or $arguments[1] -ne '0' -or $arguments[2] -ne 'new-tab') {
            throw 'Project launch must target the current Terminal window.'
        }
        if ($arguments -contains 'split-pane' -or $arguments -contains ';' -or $arguments -notcontains 'pwsh.exe') {
            throw 'A project must open a single PowerShell tab.'
        }
        if ($arguments[4] -notlike "*checkout with space & apostrophe's") { throw 'The project tab must start in the selected checkout.' }
        $title = $arguments[[array]::IndexOf($arguments, '--title') + 1]
        if ($title -ne "checkout with space & apostrophe's") { throw 'Tab titles must show only the checkout name.' }
    }
    & $module {
        param($Path)
        $script:selected = $false
        $pattern = [pscustomobject]@{}
        $pattern | Add-Member ScriptMethod Select { & (Get-Module Dev.Projects) { $script:selected = $true } }
        $element = [pscustomobject]@{ Pattern = $pattern }
        $element | Add-Member ScriptMethod GetCurrentPattern { param($Kind) $this.Pattern }
        $script:tabs = @(
            [pscustomobject]@{ Name = 'Unrelated shell'; Element = $null },
            [pscustomobject]@{ Name = (Get-ProjectTitle $Path (Get-ProjectId $Path)); Element = $element })
    } $checkout
    proj -Path $checkout
    & $module {
        if (-not $script:selected -or $script:launches.Count -ne 1) { throw 'An open project must select its existing tab.' }
        $script:tabs = @($script:tabs[1], $script:tabs[0])
        $script:selected = $false
    }
    proj -Path $checkout
    & $module {
        if (-not $script:selected -or $script:launches.Count -ne 1) { throw 'Reordering tabs broke project selection.' }
    }
    & $module {
        param($Path)
        Write-ProjectState (Join-Path $env:LOCALAPPDATA 'dotfiles/terminal-projects/checkouts.json') @(
            [pscustomobject]@{ Path = $Path; Name = Split-Path -Leaf $Path; Branch = 'main' })
        function script:Select-ProjectCheckout($Projects) { return @($Projects)[0] }
        $script:selected = $false
    } $checkout
    proj -Active
    & $module {
        if (-not $script:selected -or $script:launches.Count -ne 1) { throw 'The active project command must reuse a live tab.' }
        $script:tabs = @()
    }
    proj -Path $checkout
    & $module {
        if ($script:launches.Count -ne 2) { throw 'A closed project tab must reopen in the current window.' }
    }
    Write-Host 'PASS: current-window project tabs, existing-tab reuse, reorder, and reopening after closure.'
} finally {
    Remove-Module Dev.Projects -ErrorAction SilentlyContinue
    $env:LOCALAPPDATA = $previousLocal
    $absolute = [IO.Path]::GetFullPath($fixture)
    $boundary = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
    if ($absolute.StartsWith($boundary + 'dotfiles-project-tabs-', [StringComparison]::OrdinalIgnoreCase)) {
        Remove-Item -LiteralPath $absolute -Recurse -Force
    }
}
