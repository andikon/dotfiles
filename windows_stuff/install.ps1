#Requires -Version 7
# Installs the nvim config, the PowerShell profile/modules and merges the Windows Terminal settings.
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

Install-Nvim
Install-PowerShell
Install-WindowsTerminal
