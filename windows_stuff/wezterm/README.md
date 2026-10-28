# Native Windows workspaces

Borderless charcoal/acrylic, JetBrains Mono Nerd Font, a hidden tab bar, and one live workspace per Git checkout. No WSL, fzf, fd or downloaded WezTerm plugins are required. Install the programs listed in [deps.md](../deps.md) manually.

## Install

From PowerShell 7 in the dotfiles repository:

```powershell
# Install the editor, PowerShell profile/modules, WezTerm and Windows Terminal settings.
.\windows_stuff\install.ps1

# Put the configuration beside wezterm.exe in an extracted portable distribution.
.\windows_stuff\install.ps1 -Only WezTerm -WezTermDirectory 'C:\Tools\WezTerm'

# Or install just WezTerm's config in your user configuration directory.
.\windows_stuff\install.ps1 -Only WezTerm
```

`-WezTermDirectory` also works with the full install. Without it, the destination is `$XDG_CONFIG_HOME/wezterm` if set, otherwise `%USERPROFILE%/.config/wezterm`. Existing managed files get `.bak` copies. `-WhatIf` previews the installation. The installer does not install software or change execution policy.

For a fully manual portable setup, copy the contents of this folder beside `wezterm.exe`. WezTerm finds that `wezterm.lua` automatically. No files refer back to this repository. A command-line `--config-file` or `WEZTERM_CONFIG_FILE` environment override takes precedence over portable discovery.

Copy `local.lua.example` to `local.lua` to override project roots, portable executable paths, font, size or opacity. Use forward slashes in Lua paths. The installer preserves `local.lua`. No authentication credentials belong in this file.

## Projects and worktrees

Press **Ctrl+a**, release it, then **f**. Type part of a repository, branch or path. **Enter** opens it; **Esc** cancels. **Ctrl+n/p** or arrows move through the matches.

- `●` is the current workspace; `◉` is another running workspace; `○` opens a new one.
- A first visit opens Neovim on the left, Copilot on the upper right and a PowerShell shell below it. All start in that checkout. Missing editor/agent executables leave a readable message and a usable shell.
- Returning to a workspace keeps its processes, unsaved buffers and layout. A new selection does not change the working directories of existing applications.
- Main checkouts and each worktree have separate identities based on the full checkout path. Duplicate repository/folder names are supported.
- Discovery scans `%USERPROFILE%/Code` and grouping folders up to four levels deep. Once a checkout is found, Git enumerates its worktrees, including registered paths outside `Code`. Bare repositories with worktrees are supported. Missing/prunable worktrees are omitted. Junctions/symlinks are not followed during discovery.
- Discovery does not walk the contents of a checkout or dependency/build directories. Add another `project_roots` entry for an independent repository nested inside a checkout or behind a junction.
- The disk list is cached for 30 seconds; **Ctrl+a Shift+f** refreshes immediately. Running workspace state is always read live. A closed workspace's next visit creates a new layout.
- Workspaces stay alive while this WezTerm process is open. Closing the application ends these jobs; persistence across application exit/logoff is not configured.

The PowerShell profile installed by the full installer reports its current directory to WezTerm. New tabs/splits inherit the reported directory, falling back to the workspace root. This does not depend on the old `proj` command or its global `.curproj` file.

## Keys

The prefix is **Ctrl+a**, matching the tmux configuration. All keys below are pressed after releasing the prefix. GlazeWM can keep its global Alt bindings. **Ctrl+a Ctrl+a** sends a literal Ctrl+a to the application.

| Key | Action |
| --- | --- |
| `f` / `Shift+f` | Pick any project / refresh and pick |
| `w` | Pick a running workspace |
| `h j k l` | Focus left/down/up/right pane |
| `v` / `s` | Split right / below |
| `c` | New shell tab |
| `n` / `p` / `1…9` | Next / previous / numbered tab |
| `Shift+h` / `Shift+l` | Move tab left / right |
| `a` / `Shift+s` | Numbered pane selection / swap with selected pane |
| `z` | Zoom/unzoom pane |
| `r`, then `h j k l` | Resize repeatedly; Enter/Esc finishes |
| `x` | Close pane with confirmation |
| `,` | Rename tab |
| `[` | Keyboard copy/scrollback mode |
| `b` | Toggle the compact tab/workspace bar |
| `o` | Toggle nearly opaque acrylic / fully opaque background |
| `m` | Maximize the borderless window |
| `Shift+r` | Reload configuration |

**Ctrl+Shift+p** opens the command palette, including project and appearance actions. **F11** toggles fullscreen. **Ctrl+Shift+drag** with the left mouse button moves the borderless window. Normal Windows window-management shortcuts still work.

Pane navigation and editor navigation are separate: use the terminal prefix for terminal panes and Neovim's window commands for editor splits. These bindings also work while Copilot or Neovim is active.

## Appearance

The default is `window_decorations = 'NONE'`, with no title bar, outer resize border, scrollbar or persistent tab row. A subtle line distinguishes adjacent panes. Text is opaque; the dark background is 94% opaque over Windows Acrylic. Acrylic is visible only when opacity is below `1.0` and Windows transparency effects are enabled. Set `opacity = 1.0` in `local.lua`, or use the opaque toggle, for a solid background.

The default font matches the installed `JetBrainsMonoNL Nerd Font Mono` family, with JetBrains Mono Nerd Font/JetBrains Mono fallbacks. Set `font` in `local.lua` if your font has a different family name. Use `window_decorations = 'RESIZE'` in `wezterm.lua` if you later want normal edge resizing.

## Verify without installing

```powershell
wezterm --config-file "$PWD/windows_stuff/wezterm/wezterm.lua" show-keys
pwsh -NoProfile -File .\windows_stuff\wezterm\scripts\Get-Projects.ps1
pwsh -NoProfile -File .\windows_stuff\tests\Verify-WezTerm.ps1
```

Add `-Runtime` to the verification script to also create disposable panes with the installed native WezTerm mux server. This uses a temporary local socket and starts test shells only; it does not launch Neovim or Copilot. The default checks need no running GUI.

To preview the actual configuration without changing your installed settings:

```powershell
wezterm --config-file "$PWD/windows_stuff/wezterm/wezterm.lua" start --always-new-process
```
