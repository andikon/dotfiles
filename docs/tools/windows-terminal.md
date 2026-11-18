# Windows Terminal settings

Select Windows Terminal in the installer, or run `./install.ps1 -Only windows-terminal`. The installer discovers Stable, Preview and unpackaged configuration locations independently. `-TerminalDirectory` selects an explicit settings folder.

Updates preserve the existing profile list, ordering, GUIDs, sources, hidden flags, starting directories and per-profile overrides. Default-profile selection, disabled discovery sources, custom launch menus and other settings absent from the repository are retained. These values describe the current machine and do not belong in the shared configuration.

The installer adds `-NoLogo` to the standard generated PowerShell 7 profile, preserving its executable path and other arguments. It creates that generated-profile override when absent. Alt+c selects this same profile and inherits its command, appearance and starting directory. Other profile commands and the default-profile selection are retained.

The repository owns the values it specifies in `profiles.defaults`, its named actions and shortcut keys, and its named color schemes. Defaults are updated recursively, so an existing font size or history limit survives unless the repository defines that value. Custom schemes used by personal profiles remain available; repository schemes replace existing schemes with the same name. The repository must not contain `profiles.list`, `defaultProfile` or `disabledProfileSources`.

Actions and their separate `keybindings` entries use stable IDs. Installation replaces older bindings for managed keys together with their action definitions. Unrelated custom actions and shortcuts remain available. This also repairs bindings left pointing at missing action IDs by older updates.

Existing settings may contain JSON comments and trailing commas. The installer validates and prepares every Terminal destination before moving any originals into backup. It writes normalized JSON, so comments and formatting are retained in the backup rather than in the updated file. Unreadable or invalid settings fail safely; they are never replaced with an empty profile list.

## Keyboard-first development

Install both configurations with `./install.ps1 -Only windows-terminal,powershell`. The picker runs with PowerShell 7 and Git. It searches Git checkouts and linked worktrees beneath `~/Code` and `~/projects`. Set `DOTFILES_PROJECT_ROOTS` to a semicolon-separated list to use different roots.

| Keys | Action |
| --- | --- |
| Alt+h/j/k/l | Focus left/down/up/right pane |
| Alt+Shift+h/j/k/l | Resize in that direction |
| Alt+v / Alt+s | Split right / below with PowerShell |
| Alt+z | Zoom or unzoom the active pane |
| Alt+c | New PowerShell tab |
| Alt+p / Alt+n | Previous / next tab |
| Alt+Shift+p / Alt+Shift+n | Move tab left / right |
| Alt+1Ã¢â‚¬â€œ8 / Alt+/ | Jump to a numbered tab / search tabs |
| Alt+f / Alt+w | All-project picker / search open tabs |
| Alt+x / Alt+Shift+x | Close current pane / close entire tab |
| Alt+Backspace | Return to the previous project selected by the picker |
| Ctrl+Shift+P | Command palette |

Alt+f opens the console project picker in a new tab in the current window. Esc closes that picker tab. Enter uses the tab lookup prepared while filtering to select an existing project tab, or opens a single PowerShell tab in the selected checkout, then closes the picker tab. If tab lookup is still loading, Enter opens a new tab immediately. Type to filter, use arrows or Ctrl+j/k to select, and Tab or Ctrl+[ for Normal mode with j/k, gg/G and /.

Alt+w opens Windows Terminal's native tab search within the current window. It includes project tabs and additional shell tabs. Selecting a result focuses the existing tab and preserves its panes and processes. Alt+v and Alt+s open a PowerShell split in the focused pane's reported working directory. The bundled PowerShell prompt reports the current directory after each command using Terminal shell integration, including after `cd` into a subdirectory. Alt+x closes the active pane; Alt+Shift+x closes the whole tab and its processes. Closing the last pane closes its tab, and closing the last tab closes the window.

The PowerShell profile prepares a small console executable in `%LOCALAPPDATA%/dotfiles/terminal-projects/picker.exe` using the Windows .NET Framework compiler. `Start-ProjectPicker` prepares it again after an update. Preparation and initial discovery run in the background when PowerShell starts. The shortcuts become available after that initial preparation completes. A current executable and fresh snapshot skip the background preparation process on subsequent shell launches. Setup errors are recorded in `picker-error.log` beside the executable. Corporate application-control policies must permit the locally compiled executable.

The picker uses a padded search header, aligned project/branch/path columns, a highlighted selection and a compact help bar. Narrow panes collapse the path column. The picker renders a cached snapshot first. When the snapshot is older than 60 seconds, a background PowerShell process refreshes discovery. The next input uses the refreshed results. Open tabs are read live by the native Alt+w search. `proj` retains its console picker in the current shell.

Run `pwsh -NoProfile -File tests/powershell/Test-ProjectPickerLatency.ps1` to measure executable startup, snapshot loading, first render and filter with 1,000 projects against a 200 ms budget. The same test exercises selection through the native launcher with a recording executable under the 200 ms budget. New project tabs use the same PowerShell 7 profile as Alt+c. Selection calls `wt.exe` directly; it no longer starts an intermediate PowerShell, imports modules, runs Git or compiles helpers. The lookup of existing tabs runs after the first frame on a background thread.

These automated measurements do not include Windows Terminal creating the pane or PowerShell becoming interactive. The first PowerShell prompt records actual selection-to-prompt time in `%LOCALAPPDATA%/dotfiles/terminal-projects/picker-last-launch.json` (`ReadyMilliseconds`, `BudgetMet`). This includes Terminal dispatch, shell/profile startup and prompt Git commands; it is not a screen-presentation measurement. A cold PowerShell process or a large repository can exceed 200 ms even when picker dispatch is fast. Existing-tab focus does not start a shell and does not write a prompt-startup measurement.

From PowerShell use `proj`, `proj -Active`, `proj -Refresh`, `proj -Path .`, or `proj -Last`. `proj -NewTab` adds a shell tab when the selected project is already open in this window. Each new project opens a single PowerShell tab in its checkout directory.

Project selection uses Windows UI Automation to read and select the current window's live tab controls. Tab order is read each time; reordering and closing tabs do not require stored indexes. Projects opened from this configuration have a title containing only their checkout folder name. When known checkouts share that name, selection opens a new tab rather than risking focus on the wrong checkout. Tabs opened before this change keep their old titles until reopened. Use Alt+w to find tabs you have renamed manually. The shared settings keep the tab bar visible. Corporate restrictions on UI Automation may prevent the PowerShell project command from selecting existing tabs. Native Alt+w tab search operates within Terminal itself.

## Recover profiles removed by an older installer

Older versions replaced the complete file, including the profile list. Rerunning the corrected installer preserves what is currently present; it cannot reconstruct profiles already removed by a previous run.

Look under `%LOCALAPPDATA%\dotfiles\backups\RUN\manifest.json` for entries whose `Tool` is `windows-terminal`. Each entry records the original settings in `Backup` and the correct live location in `Destination`. Stable and Preview may have different entries. A backup from a later repeat installation may already contain the reduced profile list, so inspect earlier runs too.

Close Windows Terminal, save a separate copy of its current settings, and copy the appropriate backed-up `previous` file to that entry's `Destination`. This recovers only Terminal settings. Applying the fixed installer afterwards reapplies the shared appearance/actions while keeping the recovered profiles.

The general `-Restore RUN` option restores **every configuration in that run**, not just Terminal. Use it only when you intend that broader rollback. See [backup and restore](../configuration.md#backups-and-restore).
