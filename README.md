# My dotfiles

My editor, terminal, shell, and desktop settings for Windows, macOS, Linux, and WSL. Pick the tools you use; the installer checks dependencies and lets you install or replace each configuration independently.

## Install without cloning

These commands use the published `main` branch of [andikon/dotfiles](https://github.com/andikon/dotfiles). Local changes become available remotely after they are pushed there.

**Windows — run in PowerShell:**

```powershell
$installer = Join-Path $env:TEMP 'dotfiles-install.ps1'
Invoke-WebRequest -UseBasicParsing 'https://raw.githubusercontent.com/andikon/dotfiles/main/install.ps1' -OutFile $installer
& $installer
```

**macOS, Linux, or WSL — run in your terminal:**

```sh
installer=$(mktemp)
curl -fLsS https://raw.githubusercontent.com/andikon/dotfiles/main/install.sh -o "$installer" && bash "$installer"
rm -f "$installer"
```

The wizard runs with Windows PowerShell 5.1+ or Bash 3.2+. It downloads a temporary snapshot; Git and a permanent checkout are unnecessary for the installer. You can inspect the downloaded script before executing it. Work-machine script policies still apply; use your approved company process if execution is restricted.

## What the wizard does

1. Shows which applicable tools and dependencies are installed, missing, or too old.
2. Offers to install selected dependencies, let you handle them yourself, or skip tools with missing requirements.
3. Shows configuration destinations and whether existing settings will be replaced. Select entries with arrows and Space, or use numbered prompts in a basic terminal.
4. Shows the final selection and asks you to apply it.

**Replacement is complete within the displayed target.** Stale files in a managed directory are removed, and existing settings are backed up first. VS Code settings and PowerShell modules are managed individually so unrelated files in shared folders remain available. Choosing Skip leaves that configuration untouched.

On a work PC, choose **I will handle dependencies myself**. The wizard can still configure installed tools, or stage selected configurations for software you will install later.

## What's included

| Environment | Configuration choices |
| --- | --- |
| Windows | Neovim, WezTerm workspaces, PowerShell, Windows Terminal, GlazeWM, Zebar, VS Code, IdeaVim |
| macOS | Neovim, fish, tmux, Ghostty, VS Code, IdeaVim, project shell helpers |
| Linux | Terminal/editor tools and the optional Hyprland, Waybar, Wofi, SwayNC, and CAVA desktop |
| WSL | Neovim, fish, tmux, and project shell helpers |

The WezTerm workspace configuration currently targets native Windows. macOS/Linux use Ghostty and tmux. IdeaVim's plugin and the JetBrains color scheme require a manual IDE step.

## Preview or install from a checkout

```powershell
# Preview: no configurations, backups, or packages are changed.
.\install.ps1 -DryRun

# Start the wizard; leave dependencies to the company portal.
.\install.ps1 -SkipDependencies

# Apply only an explicit selection, with timestamped backups.
.\install.ps1 -Only nvim,wezterm -Yes -SkipDependencies
```

```sh
bash install.sh --dry-run
bash install.sh --skip-dependencies
bash install.sh --only nvim,fish,tmux,shell-tools --yes --skip-dependencies
```

## Update and restore

Rerun the same installation command to pull the latest published settings and choose what to replace. Changes flow from this repository to your machine. Edit this repository and publish changes when you want them available on other machines.

Each applying run prints its backup directory. See [configuration and restoration](docs/configuration.md) for restoring a run, legacy Stow migration, and first-launch steps.

## Find your way around

- [Installation options](docs/installation.md): versions, package managers, portable apps, and custom paths.
- [Neovim workflow](docs/tools/neovim.md) and [PDF shortcut reference](docs/cheatsheets/neovim-workflow-cheatsheet.pdf).
- [Windows workspaces](docs/tools/wezterm.md), [Windows dependencies](docs/tools/windows-dependencies.md), and [Linux desktop](docs/tools/linux-desktop.md).
- [Contributing](docs/contributing.md): repository layout, adding tools, and validation.
- [Working with coding agents](docs/agent-workflow.md): planning, implementation, and review.

