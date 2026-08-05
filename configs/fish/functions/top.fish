# top.fish — system monitor wrapper
# Picks the best available monitor:
#   bottom > btop > htop > top
# Usage:
#   top              → launches preferred monitor
#   top --btop       → force btop
#   top --bottom     → force bottom
#   top --htop       → force htop

function top --description 'Launch best available system monitor'
    set -l preferred top

    if contains -- --btop $argv
        set preferred btop
    else if contains -- --bottom $argv
        set preferred bottom
    else if contains -- --htop $argv
        set preferred htop
    else
        # auto-detect
        if command -v bottom >/dev/null 2>&1
            set preferred bottom
        else if command -v btop >/dev/null 2>&1
            set preferred btop
        else if command -v htop >/dev/null 2>&1
            set preferred htop
        end
    end

    if not command -v $preferred >/dev/null 2>&1
        echo "No monitor found (seeded: bottom, btop, htop, top)"
        return 1
    end

    $preferred $argv
end
