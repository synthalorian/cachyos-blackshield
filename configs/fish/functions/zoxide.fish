# zoxide.fish — smart directory jumper
# Wraps zoxide. Falls back gracefully if zoxide isn't installed.
# Usage:
#   z <query>          → jump to highest-ranked match
#   z --add <path>     → add to db
#   z --query <query>  → print matches without jumping

function z --description 'Smart directory jumper (zoxide / autojump fallback)'
    if command -v zoxide >/dev/null 2>&1
        zoxide $argv
        return $status
    end
    if command -v autojump >/dev/null 2>&1
        if test (count $argv) -eq 0
            autojump --stat
            return $status
        end
        autojump $argv
        return $status
    end
    echo "zoxide/autojump not installed. Install zoxide for smart jumps."
    return 1
end
