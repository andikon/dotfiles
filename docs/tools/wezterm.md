# Native Windows workspaces

Borderless charcoal/acrylic, JetBrains Mono Nerd Font, an always-visible project/tab bar, and one live workspace per Git checkout. No WSL, fzf, fd or downloaded WezTerm plugins are required. The [dependency guide](windows-dependencies.md) lists the programs; the wizard can install selected dependencies or let you handle them yourself.

## Install

From PowerShell 7 in the dotfiles repository:

```powershell
# Install the editor, PowerShell profile/modules, WezTerm and Windows Terminal settings.
.\install.ps1

# Put the configuration beside wezterm.exe in an extracted portable distribution.
.\install.ps1 -Only wezterm -WezTermDirectory 'C:\Tools\WezTerm'

# Or install just WezTerm's config in your user configuration directory.
.\install.ps1 -Only wezterm
```

Without `-WezTermDirectory`, the destination is `$XDG_CONFIG_HOME/wezterm` if set, otherwise `%USERPROFILE%/.config/wezterm`. The installer replaces the displayed config targets completely and stores timestamped backups. It prepares the default project index during a normal installation so the first picker can open immediately. `-WhatIf` previews the installation, and `-SkipDependencies` leaves software installation to you. See [installation options](../installation.md).

Normal installation also backs up and removes `%USERPROFILE%/.wezterm.lua`. The supported stable WezTerm release `20240203-110809-5046fc22` checks that file before the config directory, so leaving an old copy there makes the new configuration appear not to apply. Portable installation leaves the separate home file untouched. See the [loading order in that release](https://github.com/wezterm/wezterm/blob/20240203-110809-5046fc22/config/src/config.rs#L959).

After switching from the legacy file, save your terminal work and fully close/reopen WezTerm so it discovers the new config location. To apply only WezTerm from this checkout:

```powershell
.\install.ps1 -Only wezterm -Yes -SkipDependencies
```

To check which file a running window uses, open WezTerm's debug overlay with Ctrl+Shift+L and evaluate `wezterm.config_file`. The normal destination should end in `.config/wezterm/wezterm.lua` unless you selected an XDG or portable location. An explicit `--config-file`, `WEZTERM_CONFIG_FILE`, or application-local portable config can select a different file.

For a fully manual portable setup, copy the contents of `config/wezterm/windows` beside `wezterm.exe`. WezTerm finds that `wezterm.lua` automatically. No files refer back to this repository. A command-line `--config-file` or `WEZTERM_CONFIG_FILE` environment override takes precedence over portable discovery.

Copy `local.lua.example` to `local.lua` to override project roots, portable executable paths, font, size or opacity. Use forward slashes in Lua paths. Full replacement backs up and resets `local.lua`; reapply deliberate local preferences after replacing, or skip this configuration. No authentication credentials belong in this file.

## Projects and worktrees

Press **Ctrl+a**, release it, then **f**. Type part of a repository, branch or path. **Enter** opens it; **Esc** cancels. **Ctrl+n/p** or arrows move through the matches.

**Ctrl+a f** opens **All projects**; **Ctrl+a w** opens **Active projects**, containing only checkouts with a running workspace. Each worktree is a separate project, and the home shell is excluded. Select **Show active projects** or **Show all projects** at the bottom to switch views. Switching reopens the native picker and resets its search text. Enter on a checkout still opens it immediately. Empty views retain a message and a view-switch entry.

Create worktrees from a shell inside your checkout using [`gwt`](powershell.md#git-worktrees), independently of WezTerm. Git discovery includes the new checkout on its next background refresh. **Ctrl+a Shift+f** requests a refresh; reopen the picker after it completes to see the new worktree.

- `●` is the current workspace; `◉` is another running workspace; `○` opens a new one.
- A first visit opens Neovim on the left, Copilot on the upper right and a PowerShell shell below it. All start in that checkout. Missing editor/agent executables leave a readable message and a usable shell.
- Returning to a workspace keeps its processes, unsaved buffers and layout. A new selection does not change the working directories of existing applications.
- Main checkouts and each worktree have separate identities based on the full checkout path. Duplicate repository/folder names are supported.
- Discovery scans `%USERPROFILE%/Code` and grouping folders up to four levels deep. Once a checkout is found, Git enumerates its worktrees, including registered paths outside `Code`. Bare repositories with worktrees are supported. Missing/prunable worktrees are omitted. Junctions/symlinks are not followed during discovery.
- Discovery does not walk the contents of a checkout or dependency/build directories. Add another `project_roots` entry for an independent repository nested inside a checkout or behind a junction.
- The picker opens immediately from an in-memory index; **Ctrl+a Shift+f** requests a background refresh and opens the current results immediately. Running workspace state is always read live. A closed workspace's next visit creates a new layout.
- The index persists in `%LOCALAPPDATA%/wezterm/project-index`, so it is ready after a restart. WezTerm refreshes stale data in the background on startup/reload or after opening the picker (default refresh age: 30 seconds). Reopen the picker to see newly indexed projects; refresh never interrupts typing in an open menu. Set `cache_dir` in `local.lua` if you need another local cache folder.
- On the first manual portable copy, or after changing roots, there may be no saved index yet. The menu still opens immediately with running workspaces and an indexing entry. Press Enter on that entry to check for the completed results. The installer preloads the default roots to avoid this first-use case.
- Workspaces stay alive while this WezTerm process is open. Closing the application ends these jobs; persistence across application exit/logoff is not configured.

The PowerShell profile installed by the full installer reports its current directory to WezTerm. New tabs/splits inherit the reported directory, falling back to the workspace root. This does not depend on the old `proj` command or its global `.curproj` file.

**Ctrl+a, then t** toggles focus mode for the current pane. From Neovim, the editor fills the tab; from Copilot, Copilot fills it; from the shell, the shell fills it. Press it again to restore the split arrangement while keeping that pane focused. Every process keeps running. This uses WezTerm's instant native pane zoom and also works in existing tabs without recreating them. **Ctrl+a z** is an alternative binding for the same action.

## Closing projects and quitting

**Ctrl+a Shift+x** closes the current project's entire workspace, including extra tabs and windows. The menu defaults to keeping it open; select **Close project and all its tabs** to confirm, or press **Esc** to cancel. Save editor buffers and finish jobs first: confirming terminates every process in that project. Other projects keep running. You return to the default workspace if it exists, otherwise another running workspace, or a fresh home shell if this was the last one. The checkout remains in the project picker; opening it again creates a fresh layout.

**Ctrl+a Shift+q** uses WezTerm's native [QuitApplication](https://wezterm.org/config/lua/keyassignment/QuitApplication.html) action. Confirm once to exit the whole application, including projects hidden in other workspaces. This avoids closing and confirming each project separately. These actions are also in **Ctrl+Shift+p**. Closing a window normally still retains WezTerm's confirmation.

## Keys

The prefix is **Ctrl+a**, matching the tmux configuration. Entries marked **Prefix** are pressed after releasing Ctrl+a. Global shortcuts work directly; resize keys apply after entering resize mode. GlazeWM can keep its global Alt bindings. **Ctrl+a Ctrl+a** sends a literal Ctrl+a to the application.

**Ctrl+a ?** opens searchable, read-only help for this configuration's shortcuts, grouped by projects, panes, tabs, actions, appearance, global shortcuts and resize mode. Enter or Esc closes help without executing an action. The bindings, help and table below share `shortcuts.tsv`; maintainers update the generated table with `python tests/wezterm/verify-shortcuts.py --write`.

<!-- shortcuts:start -->
<!-- Generated from config/wezterm/windows/shortcuts.tsv. -->

| Group | Key | Action |
| --- | --- | --- |
| Projects | `Prefix, f` | All projects |
| Projects | `Prefix, Shift+f` | Refresh discovery and show all projects |
| Projects | `Prefix, w` | Active projects |
| Projects | `Prefix, Shift+x` | Close project and all its tabs (confirm once) |
| Panes | `Prefix, h` | Focus left pane |
| Panes | `Prefix, j` | Focus pane below |
| Panes | `Prefix, k` | Focus pane above |
| Panes | `Prefix, l` | Focus right pane |
| Panes | `Prefix, v` | Split right |
| Panes | `Prefix, s` | Split below |
| Panes | `Prefix, a` | Select a numbered pane |
| Panes | `Prefix, Shift+s` | Swap with a numbered pane |
| Panes | `Prefix, z` | Focus/unfocus current pane |
| Panes | `Prefix, t` | Focus/unfocus current pane |
| Panes | `Prefix, x` | Close pane with confirmation |
| Panes | `Prefix, r` | Enter resize mode |
| Tabs | `Prefix, c` | New shell tab |
| Tabs | `Prefix, n` | Next tab |
| Tabs | `Prefix, p` | Previous tab |
| Tabs | `Prefix, 1..9` | Select tab 1 through 9 |
| Tabs | `Prefix, Shift+h` | Move tab left |
| Tabs | `Prefix, Shift+l` | Move tab right |
| Tabs | `Prefix, ,` | Rename tab |
| Actions | `Prefix, ?` | Show shortcut help |
| Actions | `Prefix, Shift+q` | Quit WezTerm and all projects (confirm once) |
| Actions | `Prefix, Shift+r` | Reload configuration |
| Actions | `Prefix, [` | Keyboard copy and scrollback mode |
| Actions | `Prefix, Ctrl+a` | Send literal Ctrl+a |
| Appearance | `Prefix, o` | Toggle acrylic/opaque background |
| Appearance | `Prefix, m` | Maximize window |
| Global | `F11` | Toggle fullscreen |
| Global | `Ctrl+Shift+p` | Open command palette |
| Global | `Ctrl+Shift+Left drag` | Move borderless window |
| Resize mode | `h` | Resize left (3 cells) |
| Resize mode | `j` | Resize down (3 cells) |
| Resize mode | `k` | Resize up (3 cells) |
| Resize mode | `l` | Resize right (3 cells) |
| Resize mode | `Enter` | Finish resizing |
| Resize mode | `Escape` | Finish resizing |

<!-- shortcuts:end -->

**Ctrl+Shift+p** opens the command palette, including project and appearance actions. **F11** toggles fullscreen. **Ctrl+Shift+drag** with the left mouse button moves the borderless window. Normal Windows window-management shortcuts still work.

Pane navigation and editor navigation are separate: use the terminal prefix for terminal panes and Neovim's window commands for editor splits. These bindings also work while Copilot or Neovim is active.

## Appearance

The default is `window_decorations = 'NONE'`, with no title bar, outer resize border or scrollbar. The compact project/tab bar stays visible even with one tab: the project and branch appear once on the left, followed by numbered tabs. The initial tab is named `Project`; renamed tabs retain their names. Reloading also removes duplicate project labels from older running tabs. A subtle line distinguishes adjacent panes. Text is opaque; the dark background is 94% opaque over Windows Acrylic. Acrylic is visible only when opacity is below `1.0` and Windows transparency effects are enabled. Set `opacity = 1.0` in `local.lua`, or use **Ctrl+a o**, for a solid background and lower compositor overhead. Status/title labels use local metadata rather than repeatedly copying the entire catalog.

The default font matches the installed `JetBrainsMonoNL Nerd Font Mono` family, with JetBrains Mono Nerd Font/JetBrains Mono fallbacks. Set `font` in `local.lua` if your font has a different family name. Use `window_decorations = 'RESIZE'` in `wezterm.lua` if you later want normal edge resizing.

## Verify without installing

```powershell
wezterm --config-file "$PWD/config/wezterm/windows/wezterm.lua" show-keys
pwsh -NoProfile -File .\config\wezterm\windows\scripts\Get-Projects.ps1
pwsh -NoProfile -File .\tests\wezterm\Verify-WezTerm.ps1
```

Add `-Runtime` to the verification script to also create disposable panes with the installed native WezTerm mux server. This uses a temporary local socket and starts test shells only; it does not launch Neovim or Copilot. The default checks need no running GUI.

To preview the actual configuration without changing your installed settings:

```powershell
wezterm --config-file "$PWD/config/wezterm/windows/wezterm.lua" start --always-new-process
```
