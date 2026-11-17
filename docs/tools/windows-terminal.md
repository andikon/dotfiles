# Windows Terminal settings

Select Windows Terminal in the installer, or run `./install.ps1 -Only windows-terminal`. The installer discovers Stable, Preview and unpackaged configuration locations independently. `-TerminalDirectory` selects an explicit settings folder.

Updates preserve the existing profile list, ordering, GUIDs, commands, sources, hidden flags, starting directories and per-profile overrides. Default-profile selection, disabled discovery sources, custom launch menus and other settings absent from the repository are retained. These values describe the current machine and do not belong in the shared configuration.

The repository owns the values it specifies in `profiles.defaults`, the shared actions and named color schemes. Defaults are updated recursively, so an existing font size or history limit survives unless the repository defines that value. Custom schemes used by personal profiles remain available; repository schemes replace existing schemes with the same name. The repository must not contain `profiles.list`, `defaultProfile` or `disabledProfileSources`.

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
| Alt+1–8 / Alt+/ | Jump to a numbered tab / search tabs |
| Alt+f / Alt+w | Pick from all / live projects |
| Alt+Backspace | Return to the previous project selected by the picker |
| Ctrl+Shift+P | Command palette |

Type to filter by repository, branch, or path. Use arrows or Ctrl+j/k to navigate, Enter to select, and Esc to cancel. Ctrl+[ or Tab switches to Normal mode. In Normal mode use j/k, gg/G, and / to resume typing.

From PowerShell use `proj`, `proj -Active`, `proj -Refresh`, `proj -Path .`, or `proj -Last`. `proj -NewTab` adds a shell when the selected project is already open. The first visit opens an editor and a shell. Use `proj -Layout full` for an extra Copilot pane on first open.

Project focus tracks each live Terminal window by checkout. The shared settings enable terminal titles for initial registration. The picker uses PowerShell's `Add-Type` and Windows desktop window APIs, which managed machines may restrict. If Windows declines foreground activation, use Alt+Tab to select the existing window. Closing that window ends its processes.

## Recover profiles removed by an older installer

Older versions replaced the complete file, including the profile list. Rerunning the corrected installer preserves what is currently present; it cannot reconstruct profiles already removed by a previous run.

Look under `%LOCALAPPDATA%\dotfiles\backups\RUN\manifest.json` for entries whose `Tool` is `windows-terminal`. Each entry records the original settings in `Backup` and the correct live location in `Destination`. Stable and Preview may have different entries. A backup from a later repeat installation may already contain the reduced profile list, so inspect earlier runs too.

Close Windows Terminal, save a separate copy of its current settings, and copy the appropriate backed-up `previous` file to that entry's `Destination`. This recovers only Terminal settings. Applying the fixed installer afterwards reapplies the shared appearance/actions while keeping the recovered profiles.

The general `-Restore RUN` option restores **every configuration in that run**, not just Terminal. Use it only when you intend that broader rollback. See [backup and restore](../configuration.md#backups-and-restore).
