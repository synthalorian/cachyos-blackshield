# conflicts.fish — resolve common Fish-on-Wayland / multi-terminal conflicts

# kitty on KDE Wayland: force window focus behavior so Alt+Tab doesn't
# trap focus inside a kitty window.  Also fixes the "new window opens
# behind maximized window" issue common on KWin.
if test "$XDG_SESSION_TYPE" = wayland
    set -x KITTY_WAYLAND_DISABLE_LAYER_SHELL 1
    set -x KITTY_ENABLE_WAYLAND 1
end

# Ghostty on Wayland: avoid GTK layer-shell race with KWin
if test "$XDG_SESSION_TYPE" = wayland
    set -x GHOSTTY_SHELL_FISH 1
end

# Prevent fish from reading the system-wide config — we own the config
# entirely via ~/.config/fish and don't want distro interference.
if test -f /etc/fish/config.fish
    # __fish_config_dir is read-only in modern fish; set the user dir via
    # XDG_CONFIG_HOME fallback instead.
    set -q XDG_CONFIG_HOME; or set -gx XDG_CONFIG_HOME ~/.config
end

# Resolve conflicting aliases between kitty and ghostty configs.
# Both define the same common aliases; prefer kitty convention when
# kitty is the current terminal, ghostty convention otherwise.
if test "$TERM" = xterm-kitty
    alias clear='clear && echo -e "\e[3J"'  # kitty alt-screen clear
else if test "$TERM" = xterm-ghostty
    alias clear='clear && printf "\033c"'    # ghostty full reset
end
