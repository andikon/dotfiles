function Test-DotfilesPlatform($Row, [string]$Platform) {
    return @($Row.platforms -split ',') -contains $Platform
}

function New-DotfilesContext {
    param([string]$Root, [string]$HomeDirectory, [string]$WezTermDirectory, [string]$VSCodeDirectory, [string]$TerminalDirectory)
    $staging = -not [string]::IsNullOrWhiteSpace($HomeDirectory)
    $userHome = if ($staging) { [IO.Path]::GetFullPath($HomeDirectory) } else { $env:USERPROFILE }
    if (-not $userHome) { throw 'Could not locate your home directory.' }
    $local = if ($staging) { Join-Path $userHome 'AppData/Local' } else { $env:LOCALAPPDATA }
    $app = if ($staging) { Join-Path $userHome 'AppData/Roaming' } else { $env:APPDATA }
    $config = if (-not $staging -and $env:XDG_CONFIG_HOME) { $env:XDG_CONFIG_HOME } else { Join-Path $userHome '.config' }
    $state = Join-Path $local 'dotfiles'
    $documents = if ($staging) { Join-Path $userHome 'Documents' } else { [Environment]::GetFolderPath('MyDocuments') }
    $profilePath = Join-Path $documents 'PowerShell/Microsoft.PowerShell_profile.ps1'
    $pwsh = Get-Command pwsh -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $staging -and $pwsh) {
        $discovered = & $pwsh.Source -NoLogo -NoProfile -NonInteractive -Command '$PROFILE.CurrentUserCurrentHost'
        if ($LASTEXITCODE -eq 0 -and $discovered) { $profilePath = [string](@($discovered)[-1]) }
    }
    $nvimName = if (-not $staging -and $env:NVIM_APPNAME) { $env:NVIM_APPNAME } else { 'nvim' }
    $nvimBase = if (-not $staging -and $env:XDG_CONFIG_HOME) { $config } else { $local }
    if ([IO.Path]::IsPathRooted($nvimName) -or @($nvimName -split '[\\/]') -contains '..') { throw 'NVIM_APPNAME must be a relative name without parent traversal.' }
    $wezterm = if ($WezTermDirectory) { [IO.Path]::GetFullPath($WezTermDirectory) } else { Join-Path $config 'wezterm' }
    if ($WezTermDirectory -and -not (Test-Path -LiteralPath (Join-Path $wezterm 'wezterm.exe') -PathType Leaf)) {
        throw 'WezTermDirectory must contain the portable wezterm.exe.'
    }
    $vscode = if ($VSCodeDirectory) { $VSCodeDirectory } elseif (-not $staging -and $env:VSCODE_PORTABLE) { Join-Path $env:VSCODE_PORTABLE 'user-data/User' } else { Join-Path $app 'Code/User' }
    $terminals = @()
    if ($TerminalDirectory) { $terminals = @($TerminalDirectory) } else {
        foreach ($relative in @('Packages/Microsoft.WindowsTerminal_8wekyb3d8bbwe/LocalState', 'Packages/Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe/LocalState', 'Microsoft/Windows Terminal')) {
            $candidate = Join-Path $local $relative
            if (Test-Path -LiteralPath $candidate -PathType Container) { $terminals += $candidate }
        }
        if ($terminals.Count -eq 0) { $terminals = @(Join-Path $local 'Packages/Microsoft.WindowsTerminal_8wekyb3d8bbwe/LocalState') }
    }
    $glazewm = if (-not $staging -and $env:GLAZEWM_CONFIG_PATH) { $env:GLAZEWM_CONFIG_PATH } else { Join-Path $userHome '.glzr/glazewm/config.yaml' }
    $variables = @{
        HOME = $userHome; CONFIG = $config; LOCALAPPDATA = $local; APPDATA = $app
        NVIM = (Join-Path $nvimBase $nvimName); WEZTERM = $wezterm; VSCODE = $vscode
        PSPROFILE = $profilePath; PSMODULES = (Join-Path (Split-Path $profilePath -Parent) 'Modules'); GLAZEWM = $glazewm
    }
    $allowed = @($userHome, $config, $local, $app, (Split-Path $profilePath -Parent), (Split-Path $glazewm -Parent), $vscode) + $terminals
    if ($WezTermDirectory) { $allowed += $wezterm }
    return [pscustomobject]@{
        Root = [IO.Path]::GetFullPath($Root); Home = $userHome; State = $state; Variables = $variables
        Terminals = $terminals; Allowed = $allowed; Portable = [bool]$WezTermDirectory; Staging = $staging
        Tools = @(Import-Csv -LiteralPath (Join-Path $Root 'catalog/tools.tsv') -Delimiter "`t")
        Targets = @(Import-Csv -LiteralPath (Join-Path $Root 'catalog/targets.tsv') -Delimiter "`t")
        Packages = @(Import-Csv -LiteralPath (Join-Path $Root 'catalog/packages.tsv') -Delimiter "`t")
        Requirements = @(Import-Csv -LiteralPath (Join-Path $Root 'catalog/requirements.tsv') -Delimiter "`t")
    }
}

function Get-DotfilesCommand($Context, [string]$Id) {
    $tool = $Context.Tools | Where-Object id -eq $Id | Select-Object -First 1
    $command = if ($tool) { $tool.command } else { $Id }
    if ($Id -eq 'wezterm' -and $Context.Portable) { return Join-Path $Context.Variables.WEZTERM 'wezterm.exe' }
    $found = Get-Command $command -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($found) { return $found.Source }
    $candidates = @()
    switch ($Id) {
        'wezterm' { $candidates = @("$env:ProgramFiles/WezTerm/wezterm.exe") }
        'glazewm' { $candidates = @("$env:ProgramFiles/glzr.io/GlazeWM/glazewm.exe", "$env:LOCALAPPDATA/Programs/glzr.io/GlazeWM/glazewm.exe") }
        'zebar' { $candidates = @("$env:ProgramFiles/glzr.io/Zebar/zebar.exe", "$env:LOCALAPPDATA/Programs/glzr.io/Zebar/zebar.exe") }
        'vscode' { $candidates = @("$env:LOCALAPPDATA/Programs/Microsoft VS Code/bin/code.cmd", "$env:ProgramFiles/Microsoft VS Code/bin/code.cmd") }
        'windows-terminal' {
            foreach ($directory in $Context.Terminals) { if (Test-Path -LiteralPath (Join-Path $directory 'settings.json')) { return 'Windows Terminal (configuration found)' } }
        }
        'idea' {
            $candidates = @(Get-ChildItem -Path "$env:ProgramFiles/JetBrains/IntelliJ IDEA*/bin/idea64.exe", "$env:LOCALAPPDATA/JetBrains/Toolbox/apps/*/bin/idea64.exe" -ErrorAction SilentlyContinue | ForEach-Object FullName)
        }
    }
    foreach ($candidate in $candidates) { if (Test-Path -LiteralPath $candidate -PathType Leaf) { return $candidate } }
    return $null
}

function Get-DotfilesStatus($Context, [string]$Id) {
    $tool = $Context.Tools | Where-Object id -eq $Id | Select-Object -First 1
    $command = if ($tool) { $tool.command } else { $Id }
    $requirement = $Context.Requirements | Where-Object command -eq $command | Select-Object -First 1
    $minimum = if ($requirement) { $requirement.minimum } else { '-' }
    if ($Id -eq 'vscode-extensions') {
        $code = Get-DotfilesCommand $Context 'vscode'
        $missing = @(Get-Content -LiteralPath (Join-Path $Context.Root 'config/vscode/common/extensions.txt') | Where-Object { $_.Trim() })
        if ($code) {
            $installed = @(& $code --list-extensions 2>$null)
            $missing = @($missing | Where-Object { $_ -notin $installed })
        }
        return [pscustomobject]@{ Id = $Id; Ready = ($missing.Count -eq 0); Status = $(if ($missing.Count) { 'Not found' } else { 'Installed' }); Detail = "$($missing.Count) configured VS Code extensions missing" }
    }
    if ($Id -eq 'agent') {
        foreach ($agent in @('codex', 'claude', 'copilot', 'opencode')) {
            if (Get-Command $agent -CommandType Application -ErrorAction SilentlyContinue) { return [pscustomobject]@{ Id = $Id; Ready = $true; Status = 'Installed'; Detail = $agent } }
        }
    }
    if ($Id -eq 'font') {
        $fonts = @(Get-ChildItem -Path "$env:WINDIR/Fonts/*JetBrains*Nerd*", "$env:LOCALAPPDATA/Microsoft/Windows/Fonts/*JetBrains*Nerd*" -ErrorAction SilentlyContinue)
        $registered = @()
        foreach ($key in @('HKCU:/Software/Microsoft/Windows NT/CurrentVersion/Fonts', 'HKLM:/Software/Microsoft/Windows NT/CurrentVersion/Fonts')) {
            $registry = Get-ItemProperty -LiteralPath $key -ErrorAction SilentlyContinue
            if ($registry) { $registered += @($registry.PSObject.Properties.Name | Where-Object { $_ -match 'JetBrains.*Nerd' }) }
        }
        $foundFont = $fonts.Count -gt 0 -or $registered.Count -gt 0
        return [pscustomobject]@{ Id = $Id; Ready = $foundFont; Status = $(if ($foundFont) { 'Installed' } else { 'Not found' }); Detail = 'JetBrains Mono Nerd Font; verify family in your terminal' }
    }
    $path = Get-DotfilesCommand $Context $Id
    if (-not $path) { return [pscustomobject]@{ Id = $Id; Ready = $false; Status = 'Not found'; Detail = 'Install manually or choose a package below' } }
    $detail = $path
    if ($minimum -ne '-') {
        try {
            $versionText = (& $path --version 2>&1 | Out-String)
            if ($versionText -notmatch '(\d+)\.(\d+)(?:\.(\d+))?') { throw 'Version could not be read' }
            $patch = if ($Matches[3]) { $Matches[3] } else { '0' }
            $version = [version]("{0}.{1}.{2}" -f $Matches[1], $Matches[2], $patch)
            if ($version -lt [version]$minimum) { return [pscustomobject]@{ Id = $Id; Ready = $false; Status = 'Too old'; Detail = "$version; needs $minimum+" } }
            $detail = "$version ($path)"
        } catch { return [pscustomobject]@{ Id = $Id; Ready = $false; Status = 'Check version'; Detail = "Needs $minimum+; $path" } }
    }
    return [pscustomobject]@{ Id = $Id; Ready = $true; Status = 'Installed'; Detail = $detail }
}

function Get-DotfilesTargets($Context, [string]$Tool) {
    foreach ($row in $Context.Targets) {
        if ($row.tool -ne $Tool -or -not (Test-DotfilesPlatform $row 'windows')) { continue }
        foreach ($placeholder in [regex]::Matches($row.destination, '\{([^}]+)\}')) {
            if ($placeholder.Groups[1].Value -ne 'TERMINAL' -and -not $Context.Variables.ContainsKey($placeholder.Groups[1].Value)) { throw "Unknown destination variable: $($placeholder.Value)" }
        }
        $destinations = @($row.destination)
        if ($row.destination.Contains('{TERMINAL}')) { $destinations = @($Context.Terminals | ForEach-Object { $row.destination.Replace('{TERMINAL}', $_) }) }
        foreach ($raw in $destinations) {
            $destination = $raw
            foreach ($key in $Context.Variables.Keys) { $destination = $destination.Replace('{' + $key + '}', $Context.Variables[$key]) }
            if ($Tool -eq 'wezterm' -and $Context.Portable) {
                foreach ($entry in Get-ChildItem -LiteralPath (Join-Path $Context.Root $row.source) -Force | Where-Object Name -ne 'local.lua') {
                    [pscustomobject]@{ Tool = $Tool; Kind = $(if ($entry.PSIsContainer) { 'directory' } else { 'file' }); Source = $entry.FullName; Destination = (Join-Path $destination $entry.Name) }
                }
                [pscustomobject]@{ Tool = $Tool; Kind = 'absent'; Source = '-'; Destination = (Join-Path $destination 'local.lua') }
            } else {
                [pscustomobject]@{ Tool = $Tool; Kind = $row.kind; Source = $(if ($row.source -eq '-') { '-' } else { Join-Path $Context.Root $row.source }); Destination = [IO.Path]::GetFullPath($destination) }
            }
        }
    }
}
