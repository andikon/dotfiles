# Environment
set -gx EDITOR nvim
set -gx VISUAL nvim
set -gx MANPAGER "nvim -c 'Man!' -o -"
set -gx TERM tmux-256color
set -gx XDG_CONFIG_HOME $HOME/.config

# Add local bin to PATH
fish_add_path $HOME/.local/bin

fish_default_key_bindings

alias v nvim
alias g git
alias t tmux