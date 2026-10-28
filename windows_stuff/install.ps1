#Requires -Version 7
# Installs dotfiles only. Install the programs in deps.md manually.
[CmdletBinding(SupportsShouldProcess)]
param(
    [ValidateSet('All', 'WezTerm', 'PowerShell', 'Neovim', 'WindowsTerminal')]
    [string]$Only = 'All',
    # For portable mode, point to the extracted folder containing wezterm.exe.
    [string]$WezTermDirectory
)

$ErrorActionPreference = 'Stop'

$dotfiles = Split-Path $PSScriptRoot -Parent

function Copy-Folder {
    param([string]$Source, [string]$Destination)

    New-Item -ItemType Directory -Path $Destination -Force | Out-Null
    Copy-Item -Path (Join-Path $Source '*') -Destination $Destination -Recurse -Force
    Write-Host "Copied $Source -> $Destination"
}

# The terminal files hold bare comma-separated objects, so wrap them into an array first.
function Read-JsonFragment {
    param([string]$Path)

    "[$(Get-Content $Path -Raw)]" | ConvertFrom-Json
}

# Entries from $New replace entries of $Existing with the same $Key value; everything else is kept.
function Merge-ByKey {
    param($Existing, $New, [string]$Key)

    $newKeys = @($New | ForEach-Object { $_.$Key })
    $kept = @($Existing | Where-Object { $_.$Key -notin $newKeys })
    [object[]]($kept + @($New))
}

function Install-Nvim {
    Copy-Folder -Source (Join-Path $dotfiles 'nvim\.config\nvim') -Destination (Join-Path $env:LOCALAPPDATA 'nvim')
}

function Install-PowerShell {
    $documents = [Environment]::GetFolderPath('MyDocuments')
    Copy-Folder -Source (Join-Path $PSScriptRoot 'powershell') -Destination (Join-Path $documents 'PowerShell')
}

function Install-WindowsTerminal {
    $packages = Join-Path $env:LOCALAPPDATA 'Packages'
    $settingsFiles = @(
        'Microsoft.WindowsTerminal_8wekyb3d8bbwe',
        'Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe'
    ) | ForEach-Object { Join-Path $packages "$_\LocalState\settings.json" } | Where-Object { Test-Path $_ }

    if (-not $settingsFiles) {
        Write-Warning 'Windows Terminal settings.json not found, skipping.'
        return
    }

    $actions = Read-JsonFragment (Join-Path $PSScriptRoot 'windows_terminal\actions.json')
    $schemes = Read-JsonFragment (Join-Path $PSScriptRoot 'windows_terminal\color_scheme.json')

    foreach ($file in $settingsFiles) {
        Copy-Item $file "$file.bak" -Force
        $settings = Get-Content $file -Raw | ConvertFrom-Json

        $mergedActions = Merge-ByKey -Existing $settings.actions -New $actions -Key 'keys'
        $mergedSchemes = Merge-ByKey -Existing $settings.schemes -New $schemes -Key 'name'
        $settings | Add-Member -NotePropertyName actions -NotePropertyValue $mergedActions -Force
        $settings | Add-Member -NotePropertyName schemes -NotePropertyValue $mergedSchemes -Force

        $settings | ConvertTo-Json -Depth 20 | Set-Content $file -Encoding utf8
        Write-Host "Merged actions and color schemes into $file (backup: settings.json.bak)"
    }
}

function Get-WezTermDestination {
    if ($WezTermDirectory) {
        $destination = [IO.Path]::GetFullPath($WezTermDirectory)
        if (-not (Test-Path -LiteralPath (Join-Path $destination 'wezterm.exe') -PathType Leaf)) {
            throw 'WezTermDirectory must be the extracted portable folder containing wezterm.exe.'
        }
        return $destination
    }
    $configRoot = if ($env:XDG_CONFIG_HOME) { $env:XDG_CONFIG_HOME } else { Join-Path $env:USERPROFILE '.config' }
    return Join-Path $configRoot 'wezterm'
}

function Install-WezTerm([string]$Destination) {
    $source = Join-Path $PSScriptRoot 'wezterm'
    foreach ($file in (Get-ChildItem -LiteralPath $source -Recurse -File)) {
        if ($file.Name -eq 'local.lua') { continue }
        $relative = [IO.Path]::GetRelativePath($source, $file.FullName)
        $target = Join-Path $Destination $relative
        New-Item -ItemType Directory -Path (Split-Path $target -Parent) -Force | Out-Null
        if (Test-Path -LiteralPath $target -PathType Leaf) { Copy-Item -LiteralPath $target -Destination "$target.bak" -Force }
        Copy-Item -LiteralPath $file.FullName -Destination $target -Force
    }
    Write-Host "Installed WezTerm config -> $Destination (local.lua preserved)"
    Write-Host 'Open WezTerm, then press Ctrl+a followed by f to choose a project.'
}

if ($Only -in 'All', 'Neovim') {
    if ($PSCmdlet.ShouldProcess((Join-Path $env:LOCALAPPDATA 'nvim'), 'Install Neovim configuration')) { Install-Nvim }
}
if ($Only -in 'All', 'PowerShell') {
    if ($PSCmdlet.ShouldProcess([Environment]::GetFolderPath('MyDocuments'), 'Install PowerShell profile and modules')) { Install-PowerShell }
}
if ($Only -in 'All', 'WindowsTerminal') {
    if ($PSCmdlet.ShouldProcess('Windows Terminal settings', 'Merge actions and color schemes')) { Install-WindowsTerminal }
}
if ($Only -in 'All', 'WezTerm') {
    $wezTermDestination = Get-WezTermDestination
    if ($PSCmdlet.ShouldProcess($wezTermDestination, 'Install WezTerm configuration and project picker')) { Install-WezTerm $wezTermDestination }
}
