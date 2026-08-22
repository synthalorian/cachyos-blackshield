source /usr/share/cachyos-fish-config/cachyos-config.fish

# synthwave '84 greeting
function fish_greeting
    if status is-interactive
        fastfetch
    end
end

# openode
fish_add_path /home/synth/.opencode/bin

# kimi-code
fish_add_path /home/synth/.kimi-code/bin

# Homebrew
eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv fish)"

# Default editor
set -gx EDITOR nvim
set -gx VISUAL nvim

# OpenClaw completion
test -f "/home/synth/.openclaw/completions/openclaw.fish"; and source "/home/synth/.openclaw/completions/openclaw.fish"

# Project workflows — wrappers so one command works from anywhere
function openamp
    set bin "$HOME/Projects/active/Open-Amp/linux/build/openamp"
    if test -x "$bin"
        "$bin" $argv
    else
        echo "openamp binary not found — run: cd ~/Projects/active/Open-Amp/linux && ./build.sh"
        return 1
    end
end

function open-psalm
    set bin "$HOME/Projects/faith/open-psalm/build/open-psalm"
    if test -x "$bin"
        "$bin" $argv
    else
        echo "open-psalm not found — run: cd ~/Projects/faith/open-psalm && ./install.sh"
        return 1
    end
end

function voidengine
    set bin "$HOME/Projects/active/voidengine/demo"
    if test -x "$bin"
        "$bin" $argv
    else
        echo "voidengine demo not found — run: cd ~/Projects/active/voidengine && make"
        return 1
    end
end

alias openamp-build='cd ~/Projects/active/Open-Amp/linux && ./build.sh'
alias openpsalm-build='cd ~/Projects/faith/open-psalm && mkdir -p build && cd build && cmake .. && make -j$(nproc)'
alias ve-build='cd ~/Projects/active/voidengine && make'
alias ve-vk='cd ~/Projects/active/voidengine && make run-void3d-vk'
alias ve-gl='cd ~/Projects/active/voidengine && make run-void3d'
alias ve-shmup='cd ~/Projects/active/voidengine && make run'

# Default browser (set by synthclaw 2026-08)
set -gx BROWSER /usr/bin/chromium
