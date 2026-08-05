# ls.fish — eza wrapper with git-aware icons
# Wraps eza with a sane default and falls back to ls for git status.
# Usage: ls [eza flags]

function ls --description 'eza-based ls with git-aware shortcuts'
    if not command -v eza >/dev/null 2>&1
        command ls $argv
        return $status
    end

    # git-aware alias: `l` = long + git + icons
    if test "$argv" = "-l"
        eza --long --git --icons=automatic
        return $status
    end
    if test "$argv" = "-la"
        eza --long --all --git --icons=automatic
        return $status
    end
    if test "$argv" = "-lt"
        eza --long --tree --git --icons=automatic
        return $status
    end
    if test "$argv" = "-lta"
        eza --long --tree --all --git --icons=automatic
        return $status
    end

    # passthrough
    eza $argv
end
