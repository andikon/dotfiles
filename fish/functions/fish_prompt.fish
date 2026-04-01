function fish_prompt

    # ---------- helpers ----------

    function __truncated_path
        set path (pwd)

        # inside git repo → start from repo root
        set git_root (command git rev-parse --show-toplevel ^/dev/null)

        if test -n "$git_root"
            set repo (basename $git_root)
            set rel (string replace "$git_root/" "" $path)
            set path "$repo/$rel"
        end

        set parts (string split "/" $path)
        set count (count $parts)

        if test $count -gt 3
            set parts $parts[(math $count-2)..$count]
        end

        string join "/" $parts
    end

    function __git_info
        set branch (command git branch --show-current ^/dev/null)

        if test -z "$branch"
            return
        end

        set_color yellow
        printf "  %s" $branch

        set status (command git status --porcelain ^/dev/null)

        if test -n "$status"
            set staged   (printf "%s\n" $status | string match -r '^[AM]' | count)
            set modified (printf "%s\n" $status | string match -r '^.[MT]' | count)
            set deleted  (printf "%s\n" $status | string match -r '^.[D]' | count)

            printf " ("

            if test $staged -gt 0
                set_color green
                printf "+%s " $staged
            end

            if test $modified -gt 0
                set_color yellow
                printf "~%s " $modified
            end

            if test $deleted -gt 0
                set_color red
                printf "-%s " $deleted
            end

            set_color normal
            printf ")"
        end
    end

    # ---------- prompt ----------

    # directory
    set_color cyan
    printf "%s" (__truncated_path)

    # read-only indicator
    if not test -w .
        set_color brblack
        printf " "
    end

    # git info
    __git_info

    # newline
    printf "\n"

    # prompt arrow
    set_color green
    printf "_ "

    set_color normal
end