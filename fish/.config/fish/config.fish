set -g fish_greeting ""

fish_add_path $HOME/.local/bin

# Environment
set -gx EDITOR nvim
set -gx VISUAL nvim
set -gx MANPAGER "nvim -c 'Man!' -o -"
set -gx TERM tmux-256color
set -gx XDG_CONFIG_HOME $HOME/.config
set -g fish_history unlimited
set -g fish_pager_color_prefix cyan
set -g fish_pager_color_completion normal
set -g fish_pager_color_description yellow

fish_default_key_bindings

# Safer and nicer ls defaults (if eza exists, use it)
if command -q eza
    alias ls "eza --group-directories-first --icons"
    alias ll "eza -lah --icons"
    alias la "eza -a --icons"
else
    alias ll "ls -lah"
    alias la "ls -A"
end

alias v nvim
alias g git
alias t tmux
alias gaa "git add ."
alias gs "git status"
alias gd "git diff --cached"
alias gc "git commit -m"
alias gca "git commit -am"
alias gp "git push"
alias gl "git pull"


function fish_prompt
    # Exit status color (red if last command failed)
    set_color normal

    if test $status -ne 0
        set_color red
    else
        set_color green
    end

    # Line 1: current working directory
    echo (prompt_pwd)

    # Line 2: prompt symbol
    set_color normal
    echo -n "> "
end
