# -----------------------------
# Minimal Fish Config
# -----------------------------

# Environment
set -gx EDITOR nvim
set -gx VISUAL nvim
set -gx MANPAGER "nvim -c 'Man!' -o -"
set -gx TERM tmux-256color
set -gx XDG_CONFIG_HOME $HOME/.config

# Add local bin to PATH
fish_add_user_paths $HOME/.local/bin

# Key bindings (emacs-style like your zsh)
fish_default_key_bindings

bind \cp history-search-backward
bind \cn history-search-forward

# Aliases (minimal core)
alias ls "eza --long --no-user --header --icons --git --all --group-directories-first"
alias tree "eza --tree --long --icons"
alias v nvim
alias g git
alias t tmux