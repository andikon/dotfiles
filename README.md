# Dotfiles

Personal dotfiles repository with support for Unix systems via Nix Flakes and Home Manager.

## Repository Structure

```
.
├── flake.nix                 # Nix flake configuration
├── home-manager/
│   ├── home.nix             # Home Manager configuration for Unix systems
│   └── README.md            # Detailed Home Manager setup instructions
├── unix_dotfiles/           # Dotfiles for Unix/Linux systems (managed by Home Manager)
│   ├── dot_tmux.conf
│   ├── dot_config/          # Config files for ~/.config/
│   │   ├── nvim/
│   │   └── fish/
│   └── scripts/             # Utility scripts
├── windows_stuff/           # Windows configuration (manual setup)
└── flake.lock              # Flake dependencies lock file
```

## Quick Start

### For Unix/Linux Systems

#### Prerequisites

- NixOS or a system with Nix and Home Manager installed
- Git

#### Installation Steps

1. **Clone the repository to your home directory:**
   ```bash
   cd ~
   git clone <your-repo-url> .dotfiles
   cd .dotfiles
   ```

2. **Configure your user in `flake.nix`:**
   Open `flake.nix` and add your user configuration(s) in the `homeConfigurations` section:
   ```nix
   homeConfigurations = {
     "youruser@yourhostname" = mkHomeConfig "youruser" "yourhostname";
   };
   ```
   The username (first argument) is dynamically passed to `home.nix` and will automatically configure:
   - `username` - Your actual Unix username
   - `homeDirectory` - Your home directory path (`/home/${username}`)

   You can add multiple configurations for different users:
   ```nix
   homeConfigurations = {
     "alice@laptop" = mkHomeConfig "alice" "laptop";
     "bob@server" = mkHomeConfig "bob" "server";
   };
   ```

3. **Optionally customize other settings in `home-manager/home.nix`:**
   - `stateVersion` - Match your Home Manager version
   - `packages` - Add/remove packages you need

4. **Apply the configuration:**
   ```bash
   home-manager switch --flake .#youruser@yourhostname
   ```
   Use the same `user@hostname` identifier you defined in `flake.nix`

5. **Verify symlinks were created:**
   ```bash
   ls -la ~/.tmux.conf
   ls -la ~/.config/nvim
   ls -la ~/.local/bin/
   ```

#### What Gets Installed

When you apply this flake, Home Manager will:
- Install all configured packages (git, neovim, fish, tmux, etc.)
- Create symlinks for dotfiles from `unix_dotfiles/` to their proper locations
- Make scripts executable and accessible in your PATH

#### Adding More Dotfiles

To add more configuration files:

1. Place the file or directory in `unix_dotfiles/`
2. Add a corresponding symlink entry in `home-manager/home.nix`
3. Re-apply with `home-manager switch --flake .#youruser@yourhostname`

See `home-manager/README.md` for detailed examples.

### For Windows Systems

Windows configuration is currently **handled manually**. Configuration files and settings are stored in the `windows_stuff/` directory for reference, but must be applied manually through:

- GUI applications
- Configuration files in their respective application directories

This may be automated in the future using tools like Ansible or Windows-specific tooling.

## Home Manager Documentation

For detailed information about the Home Manager setup, symlink patterns, and how to extend the configuration, see `home-manager/README.md`.

## Notes

- The flake uses an "impure" approach with `mkOutOfStoreSymlink`, allowing you to edit dotfiles directly without triggering Home Manager rebuilds
- Dotfiles are symlinked from `~/.dotfiles/unix_dotfiles/`, keeping your system clean and configuration centralized
- All configuration is version-controlled in this repository
- Username is now dynamically configured via `flake.nix`, no hardcoding needed
