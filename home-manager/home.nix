{ config, pkgs, customUsername ? "user", dotfilesDir, ... }:

{
  home = {
    # Username is now configurable via customUsername parameter
    username = customUsername;
    homeDirectory = "/home/${customUsername}";
    stateVersion = "24.05"; # Match your NixOS/Home Manager version

    # Install packages you need
	packages = with pkgs; [
	  ## --- Core CLI ---
	  git
	  wget
	  curl
	  ripgrep
	  fd
	  fzf
	  tree
	  htop
	  unzip
	  zip
	  gnupg
	  jq
	  bat
	  eza
	  fish
	  tmux
	  neovim

	  ## --- Build / Dev essentials ---
	  gcc
	  gnumake
	  pkg-config
	  cmake
	  just

	  ## --- Search / navigation helpers ---
	  zoxide

	  ## --- Node / JS / TS / Angular ---
	  nodejs_25
	  typescript
	  typescript-language-server
	  vscode-langservers-extracted
	  angular-language-server
	  prettier
	  eslint

	  ## --- Lua ---
	  lua
	  lua-language-server

	  ## --- Java ---
	  openjdk-headless
	  jdt-language-server
	  gradle
	  maven

	  ## --- .NET ---
	  dotnet-sdk-wrapped
	  omnisharp-roslyn

	  ## --- General LSP tooling ---
	  nil
	  nixfmt
	];

    # Symlink .tmux.conf
    file.".tmux.conf" = {
      source = "${dotfilesDir}/unix_dotfiles/dot_tmux.conf";
    };
  };

  # Symlink config files
  xdg.configFile = {
    "nvim" = {
      source = "${dotfilesDir}/unix_dotfiles/dot_config/nvim";
      recursive = true;
    };
    "fish" = {
      source = "${dotfilesDir}/unix_dotfiles/dot_config/fish";
      recursive = true;
    };
  };

  # Symlink scripts to ~/.local/bin for PATH access
  home.file.".local/bin/container_startup_script.sh" = {
    source = "${dotfilesDir}/unix_dotfiles/scripts/container_startup_script.sh";
    executable = true;
  };

  home.file.".local/bin/create_tmux_session.sh" = {
    source = "${dotfilesDir}/unix_dotfiles/scripts/create_tmux_session.sh";
    executable = true;
  };

  home.file.".local/bin/select_tmux_session.sh" = {
    source = "${dotfilesDir}/unix_dotfiles/scripts/select_tmux_session.sh";
    executable = true;
  };

  home.file.".local/bin/init_all_projects.sh" = {
    source = "${dotfilesDir}/unix_dotfiles/scripts/init_all_projects.sh";
    executable = true;
  };

  # Program configurations (add more as needed)
  programs.home-manager.enable = true;
}
