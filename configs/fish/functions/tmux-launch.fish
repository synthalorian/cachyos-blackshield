# tmux-launch.fish — attach-or-create tmux session
# Usage:
#   tmux-launch            → attach/create "main"
#   tmux-launch <name>     → attach/create named session
#   tmux-launch --here     → launch in current directory instead of ~
#   tmux-launch --kill     → kill session instead

function tmux-launch --description 'Attach or create a tmux session'
    set -l target main
    set -l start_dir "$HOME"

    # parse flags
    set -l args
    for a in $argv
        switch $a
            case --here
                set start_dir (pwd)
            case --kill
                if test (count $args) -gt 0
                    set target $args[1]
                end
                tmux kill-session -t "$target" 2>/dev/null && echo "killed $target" || echo "no session $target"
                return 0
            case '-*'
                # ignore unknown flags
            case '*'
                set args $args $a
        end
    end

    if test (count $args) -gt 0
        set target $args[1]
    end

    if not command -v tmux >/dev/null 2>&1
        echo "tmux not installed"
        return 1
    end

    # if already in tmux, just switch or create
    if set -q TMUX
        tmux switch-client -t "$target" 2>/dev/null || tmux new-session -d -s "$target" -c "$start_dir"
        return $status
    end

    # try attach, fall back to create
    tmux attach -t "$target" 2>/dev/null || tmux new-session -s "$target" -c "$start_dir"
end
