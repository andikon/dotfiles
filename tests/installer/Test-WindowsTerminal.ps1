#Requires -Version 5.1
$ErrorActionPreference = 'Stop'
$repository = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
. (Join-Path $repository 'installer/powershell/Installer.ps1')
$fixture = Join-Path ([IO.Path]::GetTempPath()) ('dotfiles-terminal-' + [guid]::NewGuid().ToString('N'))
function Assert([bool]$Condition, [string]$Message) { if (-not $Condition) { throw $Message } }
try {
    $terminal = Join-Path $fixture 'terminal'
    New-Item -ItemType Directory -Path $terminal -Force | Out-Null
    $settings = Join-Path $terminal 'settings.json'
    $original = @'
{
  // Machine profiles must survive replacement of the shared appearance settings.
  "defaultProfile": "{11111111-1111-1111-1111-111111111111}",
  "disabledProfileSources": ["Windows.Terminal.Azure"],
  "newTabMenu": [{"type":"profile","profile":"{11111111-1111-1111-1111-111111111111}"}],
  "customMetadata": "https://example.invalid/a//b?literal=,] /* keep */ and \"quotes\"",
  "profiles": {
    "defaults": {"historySize":1234,"font":{"size":15,"face":"Old font"}},
    "list": [
      {"guid":"{11111111-1111-1111-1111-111111111111}","name":"Work shell","commandline":"pwsh.exe -NoExit -Command \"Write-Host hi\"","colorScheme":"Personal scheme"},
      /* A generated profile override still belongs to this machine. */
      {"guid":"{22222222-2222-2222-2222-222222222222}","name":"WSL","source":"Windows.Terminal.Wsl","hidden":false,"startingDirectory":"//wsl.localhost/Ubuntu/home/user",},
    ],
  },
  "schemes": [{"name":"Personal scheme","background":"#010203"},{"name":"Teide Darker","background":"#ffffff"}],
}
'@
    [IO.File]::WriteAllText($settings, $original)
    $context = New-DotfilesContext -Root $repository -HomeDirectory (Join-Path $fixture 'home') -TerminalDirectory $terminal
    $run = New-DotfilesRun $context
    Install-DotfilesTool $context $run 'windows-terminal'
    $installed = Get-Content -LiteralPath $settings -Raw | ConvertFrom-Json
    Assert ($installed.profiles.list.Count -eq 2) 'Windows Terminal installation erased the machine profiles.'
    Assert ($installed.defaultProfile -eq '{11111111-1111-1111-1111-111111111111}') 'Windows Terminal installation changed the default profile.'
    $before = ConvertFrom-DotfilesTerminalJson $original
    Assert ((ConvertTo-Json -InputObject $installed.profiles.list -Depth 30 -Compress) -eq (ConvertTo-Json -InputObject $before.profiles.list -Depth 30 -Compress)) 'Profile fields or ordering changed.'
    Assert ($installed.disabledProfileSources[0] -eq 'Windows.Terminal.Azure' -and $installed.newTabMenu[0].profile -eq $installed.defaultProfile) 'Profile discovery/menu settings changed.'
    Assert ($installed.customMetadata -eq $before.customMetadata) 'JSONC parsing corrupted a URL, quotes or comment-like string.'
    Assert ($installed.profiles.defaults.historySize -eq 1234 -and $installed.profiles.defaults.font.size -eq 15) 'Unmanaged profile defaults were lost.'
    Assert ($installed.profiles.defaults.font.face -eq 'JetBrainsMono Nerd Font' -and $installed.profiles.defaults.colorScheme -eq 'Teide Darker') 'Shared appearance settings were not applied.'
    Assert ($installed.actions.Count -gt 0 -and @($installed.schemes | Where-Object name -eq 'Personal scheme').Count -eq 1) 'Actions or a scheme used by a personal profile were lost.'
    Assert (@($installed.schemes | Where-Object name -eq 'Teide Darker').Count -eq 1 -and ($installed.schemes | Where-Object name -eq 'Teide Darker').background -eq '#171B20') 'Managed color schemes were duplicated or not updated.'
    Assert ([IO.File]::ReadAllText($run.Journal.Entries[0].Backup) -ceq $original) 'Backup did not retain the exact original JSONC bytes.'
    $secondRun = New-DotfilesRun $context
    Install-DotfilesTool $context $secondRun 'windows-terminal'
    $repeated = Get-Content -LiteralPath $settings -Raw | ConvertFrom-Json
    Assert ($repeated.profiles.list.Count -eq 2 -and $repeated.schemes.Count -eq 3) 'Repeat installation duplicated or removed profiles/schemes.'
    Restore-DotfilesRun $context $run.Directory $false
    Assert ([IO.File]::ReadAllText($settings) -ceq $original) 'Restore did not recover the exact original settings.'
    Write-Host 'PASS: Terminal JSONC profiles, discovery, defaults, menus, custom schemes, repeat install and exact restore.'

    foreach ($invalid in @('{"profiles":', '[{}]', '{"profiles":{"list":{}}}', '{"profiles":null}', '{ /* unterminated')) {
        [IO.File]::WriteAllText($settings, $invalid)
        $failedRun = New-DotfilesRun $context
        $failed = $false
        try { Install-DotfilesTool $context $failedRun 'windows-terminal' } catch { $failed = $true }
        Assert ($failed -and [IO.File]::ReadAllText($settings) -ceq $invalid) 'Invalid settings were replaced rather than rejected safely.'
        Assert ($failedRun.Journal.Entries.Count -eq 0) 'Invalid settings were moved into backup before validation.'
    }
    Assert (@(Get-ChildItem -LiteralPath $terminal -Filter '.dotfiles-stage-*' -Force).Count -eq 0) 'Failed preparation left staged files.'

    [IO.File]::WriteAllText($settings, '{"profiles":[{"name":"Legacy shell","commandline":"cmd.exe"}]}')
    $legacyRun = New-DotfilesRun $context
    Install-DotfilesTool $context $legacyRun 'windows-terminal'
    $legacy = Get-Content -LiteralPath $settings -Raw | ConvertFrom-Json
    Assert ($legacy.profiles.list.Count -eq 1 -and $legacy.profiles.list[0].name -eq 'Legacy shell') 'Legacy profile arrays were lost.'

    # Stable and Preview/unpackaged targets must each retain their own profiles.
    $preview = Join-Path $terminal 'preview'
    New-Item -ItemType Directory -Path $preview | Out-Null
    $previewSettings = Join-Path $preview 'settings.json'
    [IO.File]::WriteAllText($previewSettings, '{"profiles":{"list":[{"name":"Preview shell"}]}}')
    $context.Terminals = @($terminal, $preview)
    $channelsRun = New-DotfilesRun $context
    Install-DotfilesTool $context $channelsRun 'windows-terminal'
    Assert ((Get-Content -LiteralPath $previewSettings -Raw | ConvertFrom-Json).profiles.list[0].name -eq 'Preview shell') 'Terminal channels shared machine profiles.'
    Assert ((Get-Content -LiteralPath $settings -Raw | ConvertFrom-Json).profiles.list[0].name -eq 'Legacy shell') 'Preview settings replaced Stable profiles.'
    $stableBytes = [IO.File]::ReadAllText($settings)
    [IO.File]::WriteAllText($previewSettings, 'invalid JSON')
    $failed = $false
    try { Install-DotfilesTool $context (New-DotfilesRun $context) 'windows-terminal' } catch { $failed = $true }
    Assert ($failed -and [IO.File]::ReadAllText($settings) -ceq $stableBytes) 'A corrupt second channel partially changed the first.'
    Remove-Item -LiteralPath $settings
    $context.Terminals = @($terminal)
    Install-DotfilesTool $context (New-DotfilesRun $context) 'windows-terminal'
    $fresh = Get-Content -LiteralPath $settings -Raw | ConvertFrom-Json
    Assert ($fresh.profiles.defaults.colorScheme -eq 'Teide Darker' -and -not $fresh.profiles.PSObject.Properties['list']) 'Fresh install did not apply the shared defaults.'
    $details = Get-DotfilesWorkbenchConfigDetails ([pscustomobject]@{ Id='windows-terminal'; Targets=@(); Existing=$true; Ready=$true; Invalid='' })
    Assert (($details -join ' ') -match 'profiles') 'Workbench must explain profile preservation.'
    [IO.File]::WriteAllText($settings, $original)
    $beforePreview = [IO.File]::ReadAllText($settings)
    $runsBeforePreview = @(Get-ChildItem -LiteralPath (Join-Path $context.State 'backups') -Directory).Count
    & (Join-Path $repository 'install.ps1') -Only windows-terminal -Yes -SkipDependencies -HomeDirectory $context.Home -TerminalDirectory $terminal -DryRun
    Assert ([IO.File]::ReadAllText($settings) -ceq $beforePreview) 'Preview changed Terminal settings.'
    Assert (@(Get-ChildItem -LiteralPath (Join-Path $context.State 'backups') -Directory).Count -eq $runsBeforePreview) 'Preview created a backup run.'
    & (Join-Path $repository 'install.ps1') -Only windows-terminal -Yes -SkipDependencies -HomeDirectory $context.Home -TerminalDirectory $terminal
    Assert ((Get-Content -LiteralPath $settings -Raw | ConvertFrom-Json).profiles.list.Count -eq 2) 'Public installer entry point erased profiles.'
    Write-Host 'PASS: Terminal malformed-file safety, legacy profiles, independent channels, preparation atomicity and fresh install.'
} finally {
    $resolved = [IO.Path]::GetFullPath($fixture)
    $temporaryRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
    if (-not $resolved.StartsWith($temporaryRoot, [StringComparison]::OrdinalIgnoreCase) -or (Split-Path $resolved -Leaf) -notlike 'dotfiles-terminal-*') { throw 'Unexpected test cleanup path' }
    if (Test-Path -LiteralPath $resolved) { Remove-Item -LiteralPath $resolved -Recurse -Force }
}
