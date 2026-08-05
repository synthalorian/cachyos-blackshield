# ginit.fish — initialize git repo with smart .gitignore + initial commit
# Usage:
#   ginit                  → init + basic .gitignore in cwd
#   ginit --rust           → adds Rust patterns
#   ginit --node           → adds Node.js patterns
#   ginit --flutter        → adds Flutter/Dart patterns
#   ginit --unity          → adds Unity patterns
#   ginit --python         → adds Python/venv/mypy patterns
#   ginit --all            → all of the above
#   ginit --remote <url>   → adds origin + creates initial commit + pushes

function ginit --description 'init git repo with smart .gitignore + optional remote push'
    set -l stacks node rust flutter unity python
    set -l requested $argv

    if contains -- --all $requested
        set stacks node rust flutter unity python
    end

    # each flag replaces list with just that stack
    set -l final
    for flag in node rust flutter unity python
        if contains -- --$flag $requested
            set final $final $flag
        end
    end

    # if no flag given, base only
    if test (count $final) -eq 0
        set final base
    end

    # never overwrite existing .gitignore
    if test -f .gitignore
        echo "[ginit] .gitignore already exists — appending only"
    end

    # Build patterns
    set -l patterns

    switch $final
        case base
            set patterns $patterns '.DS_Store' '.local' '*~' '*.swp' '*.swo'
        case '*node*'
            set patterns $patterns 'node_modules/' '.next/' '.parcel-cache/' 'dist/' 'build/' 'coverage/' '.env' '.env.local' 'npm-debug.log*' 'yarn-debug.log*' 'yarn-error.log*' 'pnpm-debug.log*' '.vscode/' '.idea/'
        case '*rust*'
            set patterns $patterns 'target/' 'Cargo.lock' '.cargo/' '*.rlib' '*.rmeta'
        case '*flutter*'
            set patterns $patterns '.dart_tool/' 'build/' '*.app' '*.apk' '.metadata' 'ios/Pods/' 'ios/.symlinks/' 'android/.gradle/' 'android/app/build/' '.dart_tool/flutter_build'
        case '*unity*'
            set patterns $patterns '[Ll]ibrary/' '[Tt]emp/' '[Oo]bj/' '[Bb]uild/' '[Bb]uilds/' '[Uu]ser[Ss]ettings/' '*.csproj' '*.sln' '*.unityproj' '*.pidb' '*.booproj' '*.svd' '*.pdb' '*.mdb' '*.opendb' '*.VC.db' '*.pidb.meta' '.vs/' '*.log' '.cache/'
        case '*python*'
            set patterns $patterns '__pycache__/' '*.pyc' '*.pyo' '*.pyd' '.pytest_cache/' '.venv/' 'venv/' 'env/' '.env' 'dist/' 'build/' '*.egg-info/' '.mypy_cache/'
    end

    # write unique patterns
    if test (count $patterns) -gt 0
        for p in $patterns
            if not grep -qxF "$p" .gitignore 2>/dev/null
                echo "$p" >> .gitignore
            end
        end
        echo "[ginit] .gitignore updated with patterns for: $final"
    end

    # git init if needed
    if not git rev-parse --is-inside-work-tree >/dev/null 2>&1
        git init
        echo "[ginit] git init"
    end

    # remote
    if contains -- --remote $requested
        set remote_url (string replace -- '--remote' '' $requested)
        set remote_url (string trim $remote_url)
        if test -n "$remote_url"
            git remote add origin "$remote_url" 2>/dev/null || true
            echo "[ginit] remote origin -> $remote_url"
        end
    end

    # initial commit
    git add -A
    if git diff --cached --quiet
        echo "[ginit] nothing staged — is the directory empty?"
        return 0
    end
    git commit -m "chore: initial commit"
    echo "[ginit] initial commit created"

    # push
    if git remote | grep -q origin
        git branch -M main 2>/dev/null || true
        git push -u origin main 2>/dev/null || true
    end
end
