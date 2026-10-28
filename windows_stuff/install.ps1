#Requires -Version 5.1
# Compatibility entry point; use the repository-root install.ps1 for the wizard.
[CmdletBinding(SupportsShouldProcess)]
param(
    [string[]]$Only = @('All'),
    [string]$WezTermDirectory,
    [switch]$Yes,
    [switch]$SkipDependencies,
    [switch]$Plain,
    [string]$HomeDirectory
)
Write-Warning 'The installer moved to ../install.ps1. Existing configs now use complete replacement with timestamped backups.'
$parameters = @{ Only = $Only; WezTermDirectory = $WezTermDirectory; Yes = $Yes; SkipDependencies = $SkipDependencies; Plain = $Plain; HomeDirectory = $HomeDirectory; DryRun = [bool]$WhatIfPreference }
& (Join-Path (Split-Path $PSScriptRoot -Parent) 'install.ps1') @parameters
