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
    set_color brblack
    printf "%s " (date "+%H:%M")

    set_color cyan
    printf "%s" (prompt_pwd)

    git rev-parse --is-inside-work-tree >/dev/null 2>&1; and begin
        set_color yellow
        printf " [%s]" (git branch --show-current)
    end

    set_color green
    printf " ❯ "
    set_color normal
end
