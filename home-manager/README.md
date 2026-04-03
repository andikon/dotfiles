# Dotfiles Flake Setup

This flake uses Home Manager in an "impure" mode to symlink your dotfiles from a `.dotfiles` directory in your home folder.

## Setup Instructions

### On Your Unix Machine

1. **Clone the dotfiles repository:**
   ```bash
   cd ~
   git clone https://github.com/yourusername/dotfiles.git .dotfiles
   ```
   (or whatever your repository URL is)

2. **Edit the flake configuration:**
   - Update `flake.nix` to match your system (currently set to `x86_64-linux`)
   - Update `home-manager/home.nix` with your actual username and home directory path

3. **Build and activate with Home Manager:**
   ```bash
   cd ~/.dotfiles
   home-manager switch --flake .#user@hostname
   ```
   Replace `user@hostname` with your actual username and hostname (these must match what you configured in `flake.nix`)

## What Gets Symlinked

- `~/.tmux.conf` → `.dotfiles/dot_tmux.conf`
- `~/.config/nvim/` → `.dotfiles/dot_config/nvim/`
- `~/.config/fish/` → `.dotfiles/dot_config/fish/`
- `~/.local/bin/` → symlinks to scripts in `.dotfiles/scripts/`

## Directory Structure

```
.dotfiles/
├── flake.nix                 # Nix flake configuration
├── home-manager/
│   └── home.nix             # Home Manager configuration
├── unix_dotfiles/
│   ├── dot_tmux.conf        # → ~/.tmux.conf
│   ├── dot_config/
│   │   ├── nvim/            # → ~/.config/nvim/
│   │   └── fish/            # → ~/.config/fish/
│   └── scripts/             # → ~/.local/bin/
```

## Adding More Config Files

To add more dotfiles to be symlinked:

1. **For config directories** in `~/.config/`:
   ```nix
   xdg.configFile."your-app" = {
     source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.dotfiles/dot_config/your-app";
     recursive = true;
   };
   ```

2. **For root home files** (like `.tmux.conf`):
   ```nix
   home.file.".yourfile" = {
     source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.dotfiles/dot_yourfile";
   };
   ```

3. **For executable scripts**:
   ```nix
   home.file.".local/bin/myscript" = {
     source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.dotfiles/scripts/myscript.sh";
     executable = true;
   };
   ```

## Notes

- The `.dotfiles` directory is expected to be in your home directory on the Unix machine
- Using `mkOutOfStoreSymlink` allows you to edit files in place without triggering Home Manager rebuilds
- Make sure `~/.local/bin/` is in your `$PATH` for scripts to be accessible
