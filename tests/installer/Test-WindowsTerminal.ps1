#Requires -Version 5.1
$ErrorActionPreference = 'Stop'
$repository = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
. (Join-Path $repository 'installer/powershell/Installer.ps1')
$fixture = Join-Path ([IO.Path]::GetTempPath()) ('dotfiles-terminal-' + [guid]::NewGuid().ToString('N'))
function Assert([bool]$Condition, [string]$Message) { if (-not $Condition) { throw $Message } }
function Resolve-TerminalAction($Config, [string]$Key) {
    $binding = @($Config.keybindings | Where-Object keys -eq $Key) | Select-Object -Last 1
    if ($binding) { return $Config.actions | Where-Object id -eq $binding.id | Select-Object -Last 1 }
    return $Config.actions | Where-Object keys -eq $Key | Select-Object -Last 1
}
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
  "keybindings": [
    {"keys":"alt+f","id":"User.newTab.oldPicker"},
    {"keys":"alt+w","id":"User.newTab.oldActivePicker"},
    {"keys":"ctrl+alt+y","id":"Personal.Help"}
  ],
  "actions": [{"id":"Personal.Help","name":"Personal help","command":"commandPalette"}],
  "profiles": {
    "defaults": {"historySize":1234,"font":{"size":15,"face":"Old font"}},
    "list": [
      {"guid":"{11111111-1111-1111-1111-111111111111}","name":"Work shell","commandline":"pwsh.exe -NoExit -Command \"Write-Host hi\"","colorScheme":"Personal scheme"},
      {"guid":"{574e775e-4f2a-5b96-ac1e-a2962a402336}","name":"PowerShell 7 work","source":"Windows.Terminal.PowershellCore","commandline":"\"C:\\Program Files\\PowerShell\\7\\pwsh.exe\" -NoExit -Command \"Write-Host ready\"","startingDirectory":"C:/work","font":{"size":16}},
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
    Assert ($installed.profiles.list.Count -eq 3) 'Windows Terminal installation erased the machine profiles.'
    Assert ($installed.defaultProfile -eq '{11111111-1111-1111-1111-111111111111}') 'Windows Terminal installation changed the default profile.'
    $before = ConvertFrom-DotfilesTerminalJson $original
    $before.profiles.list[1].commandline = '"C:\Program Files\PowerShell\7\pwsh.exe" -NoLogo -NoExit -Command "Write-Host ready"'
    Assert ((Resolve-TerminalAction $installed 'alt+c').command.profile -eq $before.profiles.list[1].guid) 'Alt+c must select the base PowerShell 7 profile.'
    Assert (-not (Resolve-TerminalAction $installed 'alt+c').command.PSObject.Properties['commandline']) 'Alt+c must inherit the profile command.'
    Assert ((ConvertTo-Json -InputObject $installed.profiles.list -Depth 30 -Compress) -eq (ConvertTo-Json -InputObject $before.profiles.list -Depth 30 -Compress)) 'Profile fields or ordering changed.'
    Assert ($installed.disabledProfileSources[0] -eq 'Windows.Terminal.Azure' -and $installed.newTabMenu[0].profile -eq $installed.defaultProfile) 'Profile discovery/menu settings changed.'
    Assert ($installed.customMetadata -eq $before.customMetadata) 'JSONC parsing corrupted a URL, quotes or comment-like string.'
    Assert ($installed.profiles.defaults.historySize -eq 1234 -and $installed.profiles.defaults.font.size -eq 15) 'Unmanaged profile defaults were lost.'
    Assert ($installed.profiles.defaults.font.face -eq 'JetBrainsMono Nerd Font' -and $installed.profiles.defaults.colorScheme -eq 'Teide Darker') 'Shared appearance settings were not applied.'
    Assert ($installed.actions.Count -gt 0 -and @($installed.schemes | Where-Object name -eq 'Personal scheme').Count -eq 1) 'Actions or a scheme used by a personal profile were lost.'
    Assert ((Resolve-TerminalAction $installed 'alt+h').command.action -eq 'moveFocus') 'Pane navigation was lost during merge.'
    Assert ((Resolve-TerminalAction $installed 'alt+f').command.action -eq 'newTab') 'Alt+f must open the console picker in a tab.'
    Assert ((Resolve-TerminalAction $installed 'alt+w').command.action -eq 'tabSearch') 'Alt+w must search live tabs.'
    Assert ((Resolve-TerminalAction $installed 'alt+x').command.action -eq 'closePane') 'The close-pane shortcut is missing.'
    Assert ((Resolve-TerminalAction $installed 'alt+shift+x').command.action -eq 'closeTab') 'The close-tab shortcut is missing.'
    Assert ((Resolve-TerminalAction $installed 'ctrl+shift+p').command.action -eq 'commandPalette') 'Migration must restore the command palette shortcut.'
    Assert ((Resolve-TerminalAction $installed 'ctrl+alt+y').id -eq 'Personal.Help') 'Unrelated custom bindings must retain their action.'
    $projectRun = New-DotfilesRun $context
    Install-DotfilesTool $context $projectRun 'powershell'
    $projectModule = Join-Path $fixture 'home/Documents/PowerShell/Modules/Dev.Projects'
    Assert (Test-Path -LiteralPath (Join-Path $projectModule 'ProjectWindows.cs')) 'The project window helper was not installed.'
    Assert (Test-Path -LiteralPath (Join-Path $projectModule 'ProjectPicker.cs')) 'The console picker was not installed.'
    Assert (Test-Path -LiteralPath (Join-Path $projectModule 'Start-ProjectPicker.ps1')) 'The picker launcher was not installed.'
    if ($PSVersionTable.PSVersion.Major -ge 7) {
        Import-Module (Join-Path $projectModule 'Dev.Projects.psm1') -Force -ErrorAction Stop
        Assert ([bool](Get-Command proj -Module Dev.Projects -ErrorAction Stop)) 'The installed project picker cannot be imported.'
        Add-Type -Path (Join-Path $projectModule 'ProjectWindows.cs') -ErrorAction Stop
        Assert ([Dotfiles.ProjectWindows]::Find('dotfiles-window-install-test', $null) -eq [IntPtr]::Zero) 'Project window lookup found an unrelated window.'
        $previousLocal = $env:LOCALAPPDATA
        $previousRoots = $env:DOTFILES_PROJECT_ROOTS
        try {
            $env:LOCALAPPDATA = Join-Path $fixture 'picker-state'
            $env:DOTFILES_PROJECT_ROOTS = $fixture
            & (Join-Path $projectModule 'Start-ProjectPicker.ps1')
            Assert ($LASTEXITCODE -eq 0) 'The installed console picker could not be prepared.'
            Assert (Test-Path (Join-Path $env:LOCALAPPDATA 'dotfiles/terminal-projects/picker.exe')) 'The installed module did not compile its console executable.'
        } finally {
            $env:LOCALAPPDATA = $previousLocal
            $env:DOTFILES_PROJECT_ROOTS = $previousRoots
        }
        Remove-Module Dev.Projects
    }
    Assert (@($installed.schemes | Where-Object name -eq 'Teide Darker').Count -eq 1 -and ($installed.schemes | Where-Object name -eq 'Teide Darker').background -eq '#171B20') 'Managed color schemes were duplicated or not updated.'
    Assert ([IO.File]::ReadAllText($run.Journal.Entries[0].Backup) -ceq $original) 'Backup did not retain the exact original JSONC bytes.'
    $secondRun = New-DotfilesRun $context
    Install-DotfilesTool $context $secondRun 'windows-terminal'
    $repeated = Get-Content -LiteralPath $settings -Raw | ConvertFrom-Json
    Assert ($repeated.profiles.list.Count -eq 3 -and $repeated.schemes.Count -eq 3) 'Repeat installation duplicated or removed profiles/schemes.'
    Assert ($repeated.profiles.list[1].commandline -ceq $installed.profiles.list[1].commandline) 'Repeat installation duplicated -NoLogo.'
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
    Assert ($legacy.profiles.list.Count -eq 2 -and $legacy.profiles.list[0].name -eq 'Legacy shell') 'Legacy profile arrays were lost.'

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
    Assert ($fresh.profiles.defaults.colorScheme -eq 'Teide Darker' -and $fresh.profiles.list.Count -eq 1 -and $fresh.profiles.list[0].commandline -eq 'pwsh.exe -NoLogo') 'Fresh install did not apply the shared defaults.'
    $details = Get-DotfilesWorkbenchConfigDetails ([pscustomobject]@{ Id='windows-terminal'; Targets=@(); Existing=$true; Ready=$true; Invalid='' })
    Assert (($details -join ' ') -match 'profiles') 'Workbench must explain profile preservation.'
    [IO.File]::WriteAllText($settings, $original)
    $beforePreview = [IO.File]::ReadAllText($settings)
    $runsBeforePreview = @(Get-ChildItem -LiteralPath (Join-Path $context.State 'backups') -Directory).Count
    & (Join-Path $repository 'install.ps1') -Only windows-terminal -Yes -SkipDependencies -HomeDirectory $context.Home -TerminalDirectory $terminal -DryRun
    Assert ([IO.File]::ReadAllText($settings) -ceq $beforePreview) 'Preview changed Terminal settings.'
    Assert (@(Get-ChildItem -LiteralPath (Join-Path $context.State 'backups') -Directory).Count -eq $runsBeforePreview) 'Preview created a backup run.'
    & (Join-Path $repository 'install.ps1') -Only windows-terminal -Yes -SkipDependencies -HomeDirectory $context.Home -TerminalDirectory $terminal
    Assert ((Get-Content -LiteralPath $settings -Raw | ConvertFrom-Json).profiles.list.Count -eq 3) 'Public installer entry point erased profiles.'
    Write-Host 'PASS: Terminal malformed-file safety, legacy profiles, independent channels, preparation atomicity and fresh install.'
} finally {
    $resolved = [IO.Path]::GetFullPath($fixture)
    $temporaryRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
    if (-not $resolved.StartsWith($temporaryRoot, [StringComparison]::OrdinalIgnoreCase) -or (Split-Path $resolved -Leaf) -notlike 'dotfiles-terminal-*') { throw 'Unexpected test cleanup path' }
    if (Test-Path -LiteralPath $resolved) { Remove-Item -LiteralPath $resolved -Recurse -Force }
}
