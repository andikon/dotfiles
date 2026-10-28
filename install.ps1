#Requires -Version 5.1
[CmdletBinding(SupportsShouldProcess)]
param(
    [string[]]$Only,
    [switch]$Yes,
    [switch]$SkipDependencies,
    [switch]$SkipMissing,
    [switch]$DryRun,
    [string]$HomeDirectory,
    [string]$WezTermDirectory,
    [string]$VSCodeDirectory,
    [string]$TerminalDirectory,
    [string]$Restore,
    [string]$Ref = 'main',
    [string]$Repository = 'andikon/dotfiles',
    [switch]$Remote
)
$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false
$localRoot = $PSScriptRoot
$temporaryRoot = $null
try {
    if ($Remote -or -not (Test-Path -LiteralPath (Join-Path $localRoot 'catalog/tools.tsv'))) {
        [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
        if ($Repository -notmatch '^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$') { throw 'Invalid repository name.' }
        $temporaryRoot = Join-Path ([IO.Path]::GetTempPath()) ('dotfiles-' + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $temporaryRoot | Out-Null
        $headers = @{ 'User-Agent' = 'dotfiles-installer'; Accept = 'application/vnd.github+json' }
        $revision = Invoke-RestMethod -Uri ("https://api.github.com/repos/{0}/commits/{1}" -f $Repository, [Uri]::EscapeDataString($Ref)) -Headers $headers
        if ($revision.sha -notmatch '^[a-f0-9]{40}$') { throw 'GitHub did not return an immutable revision.' }
        Write-Host "Downloading $Repository at $($revision.sha)"
        $archive = Join-Path $temporaryRoot 'snapshot.zip'
        Invoke-WebRequest -UseBasicParsing -Uri "https://github.com/$Repository/archive/$($revision.sha).zip" -OutFile $archive
        Expand-Archive -LiteralPath $archive -DestinationPath (Join-Path $temporaryRoot 'snapshot')
        $localRoot = (Get-ChildItem -LiteralPath (Join-Path $temporaryRoot 'snapshot') -Directory | Select-Object -First 1).FullName
    }
    . (Join-Path $localRoot 'installer/powershell/Installer.ps1')
    $options = @{
        Root = $localRoot; Only = $Only; Yes = [bool]$Yes; SkipDependencies = [bool]$SkipDependencies
        SkipMissing = [bool]$SkipMissing; DryRun = [bool]($DryRun -or $WhatIfPreference)
        HomeDirectory = $HomeDirectory; WezTermDirectory = $WezTermDirectory
        VSCodeDirectory = $VSCodeDirectory; TerminalDirectory = $TerminalDirectory; Restore = $Restore
    }
    Invoke-DotfilesInstaller @options
} finally {
    if ($temporaryRoot) {
        $resolvedTemporary = [IO.Path]::GetFullPath($temporaryRoot)
        $allowedTemporary = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
        if ($resolvedTemporary.StartsWith($allowedTemporary, [StringComparison]::OrdinalIgnoreCase) -and (Split-Path $resolvedTemporary -Leaf) -like 'dotfiles-*') {
            Remove-Item -LiteralPath $resolvedTemporary -Recurse -Force
        }
    }
}
