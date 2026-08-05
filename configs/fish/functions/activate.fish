# activate.fish — sane replacement for conda activate / stagehand launcher
# Prevents the "Shell not supported" / "No activatable env" errors when
# hopping between conda, stagehand, and bare venvs.
#
# Usage:
#   activate                → activate the nearest stagehand venv
#   activate --conda        → activate a conda env by name
#   activate --check        → just prints what would activate; no-op

function activate --description 'Activate nearest stagehand venv or named conda env'
    # --check: dry run
    if contains -- --check $argv
        set target (__find_stagehand_venv)
        if test -n "$target"
            echo "[activate] would activate: $target"
        else
            echo "[activate] no stagehand venv found; falling to conda"
        end
        return 0
    end

    # explicit conda env
    if contains -- --conda $argv
        if test (count $argv) -lt 2
            echo "usage: activate --conda <env_name>"
            return 1
        end
        set envname $argv[2]
        if command -v conda >/dev/null 2>&1
            eval (conda shell.fish hook)
            conda activate "$envname"
            return $status
        else
            echo "[activate] conda not found; searched mamba/conda"
            return 1
        end
    end

    # default: find nearest stagehand venv (cwd-first, then parents)
    set venv_path (__find_stagehand_venv)
    if test -n "$venv_path"
        set bin_dir "$venv_path/bin"
        # Guard: don't reactivate the same venv
        if test -n "$VIRTUAL_ENV" -a "$VIRTUAL_ENV" = "$venv_path"
            echo "[activate] already in $venv_path"
            return 0
        end
        # Deactivate prior
        if set -q VIRTUAL_ENV
            set -e VIRTUAL_ENV
            if set -q _OLD_VIRTUAL_PATH
                set -gx PATH $_OLD_VIRTUAL_PATH
                set -e _OLD_VIRTUAL_PATH
            end
            if set -q _OLD_VIRTUAL_PYTHONHOME
                set -e PYTHONHOME
                set -gx _OLD_VIRTUAL_PYTHONHOME
            end
        end
        set -gx _OLD_VIRTUAL_PATH $PATH
        set -gx PATH "$bin_dir" $PATH
        set -gx VIRTUAL_ENV "$venv_path"
        set -q PYTHONHOME; and set -gx _OLD_VIRTUAL_PYTHONHOME $PYTHONHOME; set -e PYTHONHOME
        echo "[activate] activated $venv_path"
        return 0
    end

    # no stagehand venv; try conda base
    if command -v conda >/dev/null 2>&1
        echo "[activate] no stagehand venv; activating conda base"
        eval (conda shell.fish hook)
        conda activate base
        return $status
    end

    echo "[activate] nothing to activate"
    return 1
end

# internal: locate nearest stagehand-style venv
function __find_stagehand_venv --description 'Find nearest stagehand-style venv from cwd or parents'
    # Search cwd and parents for a venv layout typical of stagehand.
    # Look for the markers we expected from the spec:
    #   <dir>/.stagehand-venv/bin/python
    #   <dir>/venv/bin/python
    #   <dir>/.venv/bin/python
    set -l dirs_to_check (pwd)
    while test (count $dirs_to_check) -gt 0
        set -l d $dirs_to_check[1]
        if test -x "$d/.stagehand-venv/bin/python"
            echo "$d/.stagehand-venv"; return 0
        end
        if test -x "$d/venv/bin/python"
            echo "$d/venv"; return 0
        end
        if test -x "$d/.venv/bin/python"
            echo "$d/.venv"; return 0
        end
        set -e dirs_to_check[1]
        # parent
        if test "$d" = "/"
            break
        end
        set dirs_to_check (dirname "$d")
    end
    echo ""
end
