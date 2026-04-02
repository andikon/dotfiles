# Chezmoi Linux Dotfiles

This repo uses [Chezmoi](https://www.chezmoi.io/) to manage Linux dotfiles.

## Installation

### 1. Install chezmoi (if not already installed)
```bash
sh -c "$(curl -fsLS get.chezmoi.io)"
```

### 2. Initialize and apply
```bash
chezmoi init --apply https://github.com/YOUR_USERNAME/dotfiles.git
```

Or if you already have it cloned:
```bash
cd ~/projects/dotfiles
chezmoi init --apply --source-path . .
```

## What's managed

Linux configurations for:
- **Fish shell** (~/.config/fish)
  - config.fish
  - functions
  - Automatically adds ~/.local/bin to PATH
- **Neovim** (~/.config/nvim)
  - init.lua
  - lua configuration
  - plugins
- **Tmux** (~/.tmux.conf)
- **Scripts** (~/.local/bin)
  - All scripts are copied to ~/.local/bin and made executable
  - They're automatically added to PATH via fish config

## Structure

```
dotfiles/
├── dot_config/
│   ├── fish/
│   │   ├── config.fish
│   │   └── functions/
│   └── nvim/
│       ├── init.lua
│       └── lua/
├── dot_local/
│   └── bin/
│       └── (all scripts)
└── dot_tmux.conf
```

The `dot_` prefix in chezmoi maps to `.` in your home directory:
- `dot_config` → `~/.config`
- `dot_local` → `~/.local`
- `dot_tmux.conf` → `~/.tmux.conf`

## Usage

After initial setup, to pull updates:
```bash
chezmoi update
```

To see what changes would be applied:
```bash
chezmoi diff
```

## Notes

- Windows-specific configs (glazewm, windows_terminal, vscode, etc.) are not included in the chezmoi source
- Scripts in ~/.local/bin are automatically executable on Linux
- All dotfiles are tracked in git for version control
