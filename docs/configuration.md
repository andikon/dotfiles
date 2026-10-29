# Configuration, updates, and restoration

## Replacement ownership

The installer copies the selected repository snapshot to each displayed destination. It owns whole dedicated directories, including Neovim, fish, WezTerm's normal config directory, Ghostty, Zebar, and Linux desktop configurations. Files absent from the repository disappear from these directories after replacement.

Shared directories use individual targets: VS Code's `settings.json` and `keybindings.json`, Windows Terminal's `settings.json`, the PowerShell profile and each `Dev.*` module, IdeaVim's `.ideavimrc`, and individual shell scripts. The installer never replaces your whole home, Documents, VS Code User, PowerShell Modules, portable application, or `.local/bin` directory.

**Windows Terminal is a settings-update exception:** its machine-specific profile list, default-profile selection, discovery settings, launch menus and other unmanaged settings are retained. Repository settings override shared appearance/defaults and actions; personal color schemes are retained unless the repository defines the same scheme name. The original file is backed up byte-for-byte before the prepared update is installed. JSON comments and trailing commas are accepted; comments/formatting are normalized in the installed file. Invalid settings abort that tool before replacing any of its destinations. Stable, Preview and unpackaged installations are handled independently. See the [Terminal guide](tools/windows-terminal.md) for recovery from older installers.

Portable WezTerm owns its named config files and `scripts` directory. Unknown application files outside that set are left alone. Its local override file is included in replacement: back it up, replace, or skip the WezTerm configuration.

Normal WezTerm installation additionally owns removal of the legacy `~/.wezterm.lua` file so it cannot shadow the installed directory. That file goes into the same restorable backup run. A portable installation leaves the separate home configuration untouched.

## Backups and restore

Each applying run creates a journal and moves previous targets into a timestamped backup directory. Moving preserves top-level symlinks and junctions without changing their source. A failure rolls back changes for the affected tool; successfully applied independent tools stay installed.

| Platform | Default backup location |
| --- | --- |
| Windows | `%LOCALAPPDATA%\dotfiles\backups\RUN` |
| macOS / Linux / WSL | `${XDG_STATE_HOME:-~/.local/state}/dotfiles/backups/RUN` |

The installer prints the exact run path. Restore it with:

```powershell
.\install.ps1 -Restore 'C:\Users\you\AppData\Local\dotfiles\backups\RUN' -DryRun
.\install.ps1 -Restore 'C:\Users\you\AppData\Local\dotfiles\backups\RUN'
```

```sh
bash install.sh --restore "$HOME/.local/state/dotfiles/backups/RUN" --dry-run
bash install.sh --restore "$HOME/.local/state/dotfiles/backups/RUN"
```

Use the same `-HomeDirectory` / `--home` and explicit destination options used for the installation. An external portable WezTerm destination must be supplied again when restoring it. A restored original is moved back to its destination. The configuration displaced by restoration is saved as `replaced-on-restore` inside that target's backup entry. Repeating a completed restore does nothing.

Restoring a target that was originally absent removes the installed target and saves it in the backup entry. Empty parent directories created by installation may remain. Backups are retained until you choose to delete them; close affected applications before replacing or restoring their configuration.

## Moving from Stow

The old `stow nvim fish tmux` layout has been retired. The wizard detects an existing configuration link at its destination and moves that link into the backup before copying the new config. The old checkout stays intact. Restore the run to restore its links, provided their original source paths still exist.

No installed configuration depends on the temporary download directory or on keeping this repository cloned. Downloaded Neovim plugins and caches use the application's normal data directories.

## First launch

- **Neovim:** let Lazy install plugins, then use `:Lazy restore` for the tracked lockfile revisions and `:checkhealth dotfiles`. Git, curl 8+, ripgrep, and Neovim 0.12+ are required. Java, Node.js, parser build tools, and account authentication are described in the [Neovim guide](tools/neovim.md).
- **PowerShell:** reopen PowerShell 7. The profile imports the repository's `Dev.*` modules. Docker commands require Docker separately; project helpers look under `~/projects`.
- **WezTerm:** reopen or reload, then press Ctrl+a followed by f. Its project scanner defaults to `~/Code`. A replacement resets `local.lua`; reapply deliberate machine-specific preferences afterwards. See the [workspace guide](tools/wezterm.md).
- **fish/tmux:** launch fish or tmux explicitly. The installer does not change your login shell. Add `~/.local/bin` to PATH when using the helper scripts from another shell. The tmux session picker needs `fzf` and the selected shell helpers.
- **VS Code:** reload the window. Optional extension installation is a separate wizard choice. Settings Sync may later change local settings if enabled.
- **IdeaVim:** install/enable the IdeaVim plugin in your IDE. Import `config/idea/common/teide_dark.icls` through the IDE's color-scheme settings if desired; the installer does not guess an IDE version's theme directory.
- **Windows Terminal:** reopen it. Shared appearance/defaults and actions are updated while the machine's profiles and default selection are retained. Generated profiles remain managed by Windows Terminal.
- **GlazeWM/Zebar:** restart or reload them manually. This config launches Zebar from GlazeWM. Widget compatibility depends on the installed Zebar version.
- **Hyprland:** review the [desktop guide](tools/linux-desktop.md) before selecting it on a new machine.

## Keeping machines in sync

Edit the files under `config/`, validate the affected tool, and commit/push through your normal workflow. Run the bootstrap command on another machine and select configurations to update. There is no background scheduler or automatic upload of local settings.

Machine-specific overrides live only until the next full replacement unless stored outside a managed target and explicitly loaded by the application. Credentials, authentication tokens, histories, and runtime caches belong outside this repository.
