# Installation reference

Use the commands in the [README](../README.md) for an interactive installation. Start a downloaded script as a file so the wizard retains terminal input. The entry scripts download one immutable GitHub snapshot, run it from a temporary directory, and clean that snapshot up afterwards.

## Requirements

| Platform | Installer runtime | Remote bootstrap tools |
| --- | --- | --- |
| Windows | Windows PowerShell 5.1+ or PowerShell 7+ | Built-in web requests and ZIP extraction |
| macOS | Bash 3.2+ | curl and tar |
| Linux / WSL | Bash 3.2+ | curl and tar |

The terminal interface has no framework dependency. Color is optional; Bash honors `NO_COLOR`. Arrows and Space work in interactive terminals, and numbered selection works when input is redirected. Set `DOTFILES_NO_TUI=1` to force numbered prompts. Press Esc or enter `cancel` in a selection menu to stop; enter `none` to skip all its entries.

Dependency installation happens only after choosing that option in the wizard and selecting the software. `-Yes` / `--yes` applies an explicit configuration list and **never installs software automatically**. Missing requirements leave configurations unchecked by default, but they can be selected for staging. `-SkipMissing` / `--skip-missing` excludes them entirely. Optional dependencies do not block a configuration.

## Command options

| Purpose | PowerShell | Bash |
| --- | --- | --- |
| Limit the tools | `-Only nvim,wezterm` | `--only nvim,tmux` |
| Apply the explicit list | `-Yes` | `--yes` |
| Manage software yourself | `-SkipDependencies` | `--skip-dependencies` |
| Skip missing requirements | `-SkipMissing` | `--skip-missing` |
| Preview only | `-DryRun` or `-WhatIf` | `--dry-run` |
| Stage into another home | `-HomeDirectory C:\Temp\dotfiles-home` | `--home /tmp/dotfiles-home` |
| Restore a backup run | `-Restore PATH` | `--restore PATH` |
| Download a snapshot from a checkout | `-Remote` | `--remote` |
| Select a remote revision | `-Ref v1.0.0` | `--ref v1.0.0` |
| Select a fork | `-Repository owner/repo` | `--repository owner/repo` |

Tool IDs are in [the tool catalog](../catalog/tools.tsv). Bash accepts the exact lowercase IDs. PowerShell additionally accepts the old `Neovim` and `WindowsTerminal` names. `windows_stuff/install.ps1` forwards old commands into the new wizard; its replacement behavior follows the new installer.

`-HomeDirectory` / `--home` stages settings under the supplied home and ignores the current user's XDG and application path overrides. It still detects available software, but skips WezTerm index warming. This is useful for evaluating the setup without touching active settings. Explicit destination flags still override staged paths.

## Pin a version

After downloading an entry script, choose a tag, branch, or commit:

```powershell
& $installer -Ref 'your-tag-or-commit' -Only nvim
```

```sh
bash "$installer" --ref your-tag-or-commit --only nvim
```

For a fully pinned bootstrap, replace `main` in the README's raw script URL with the same commit or tag as well. A local checkout uses its files unless `-Remote` / `--remote` is supplied.

## Package installation

The shared [package catalog](../catalog/packages.tsv) maps dependencies to available package managers. A dash means manual installation. The installer does not install a package manager or add third-party repositories.

- **Windows:** WinGet installs in user scope. If an installer needs machine scope or your company blocks it, use your company portal or approved installation process.
- **macOS:** Homebrew, if already present. Homebrew casks include applications and the optional Nerd Font.
- **Debian / Ubuntu / WSL:** APT. Refresh package metadata with your normal system-maintenance process if necessary.
- **Fedora:** DNF, using configured repositories.
- **Arch:** Pacman, using configured repositories. Keep the system updated normally before installing packages.

Package availability and versions depend on your repositories. After an install attempt, the wizard checks requirements again. A package manager may supply a Neovim version older than this config's 0.12 requirement or a tree-sitter CLI older than 0.26.1; these remain marked incompatible. Use an approved upstream installation if needed.

Java versions are project-specific, and coding agent CLIs require account setup. These receive manual guidance. Optional VS Code extensions are a separate selection in the dependency menu; installing settings alone leaves installed extensions unchanged.

## Windows destinations

```powershell
# Portable WezTerm: directory must already contain wezterm.exe.
.\install.ps1 -Only wezterm -WezTermDirectory 'C:\Tools\WezTerm'

# Alternative VS Code profile or portable User directory.
.\install.ps1 -Only vscode -VSCodeDirectory 'C:\Tools\Code\data\user-data\User'

# Explicit unpackaged Windows Terminal settings directory.
.\install.ps1 -Only windows-terminal -TerminalDirectory 'C:\Tools\Terminal\settings'
```

Installed Windows Terminal stable, preview, and unpackaged configuration directories are detected separately; all discovered targets appear in the review. PowerShell 7's profile path is queried from that shell to account for redirected Documents folders. These profiles target PowerShell 7, even when Windows PowerShell 5.1 launches the wizard.

`XDG_CONFIG_HOME`, `NVIM_APPNAME`, `VSCODE_PORTABLE`, and `GLAZEWM_CONFIG_PATH` are honored where applicable. A portable WezTerm directory owns the listed Lua config files and its `scripts` directory; executables and libraries remain untouched. Its `local.lua` is backed up and removed during replacement.

If you launch an application with an explicit configuration-file argument, select its destination explicitly where supported or copy the appropriate config manually. Executable detection cannot infer arbitrary launcher arguments.

## macOS, Linux, and WSL destinations

Neovim, fish, and Linux desktop tools use `XDG_CONFIG_HOME` when set. Neovim also honors `NVIM_APPNAME`. tmux uses `~/.tmux.conf`; helpers install individually under `~/.local/bin`.

Ghostty uses the native Application Support directory on macOS. Selecting replacement also backs up/removes the two conflicting XDG config filenames because Ghostty can load both locations. Linux uses the XDG Ghostty directory. The bundled legacy filename `config` works across Ghostty versions.

VS Code uses the native macOS User directory or the XDG Linux User directory. Set `--vscode-dir PATH` for another profile. Set `VSCODE_PORTABLE` for a Linux portable installation. GUI apps are also detected under `/Applications` on macOS when their commands are absent from PATH.

Optional extension installation uses the detected VS Code CLI's active/default user-data location. For a custom profile with separate extension storage, install extensions with that profile's CLI arguments manually.

WSL is treated as a terminal environment. A Windows `code` shim inside WSL is not treated as a native Linux VS Code installation. Desktop configurations are available only in native Linux, and are unchecked by default in headless sessions.

## Interrupted or concurrent runs

The installer holds a per-user lock during configuration changes and restoration. PowerShell locks are released automatically when the process exits. Bash uses a lock directory; after an interrupted run, verify no installer is running before removing the reported `installer.lock` directory. Then restore the printed backup run to recover any interrupted change.

Configuration targets with a symlink or junction in an ancestor are refused to keep replacements at the displayed physical location. A link at the target itself is supported and backed up as a link. If an existing directory cannot move to the backup volume, the tool reports a failure and leaves or restores its existing settings.
