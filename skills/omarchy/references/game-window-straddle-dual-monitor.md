# Game Window Straddles Both Monitors After DPMS Wake

## Problem

After a lock/unlock or suspend/resume cycle, a fullscreen game window launches spanning both monitors (e.g. the left half on the secondary display, right half on the primary). The resolution is correct (monitors.conf was re-applied by `hyprctl reload`), but the window position is wrong.

This happens because the game (or XWayland) remembers its window position from the last session, and the DPMS cycle corrupted the coordinate space momentarily — the game's saved `window_x` value now maps to a spot straddling both displays.

## Monitor Layout Context

Common dual-monitor layout with a primary 2K display to the right of a secondary 1080p:

```
monitor=desc:HGC CR270C demoset-1,1920x1080@180.00,0x0,1
monitor=desc:Shenzhen KTC Technology Group GMQ3225RVC ...,2560x1440@180.00,1920x0,1
```

- **Secondary (HDMI-A-3):** 0,0 → 1920×1080
- **Primary (DP-2):** 1920,0 → 4480×1440
- **Boundary:** x=1920

If a game window at x=1900 with width=2560 is positioned, it spans 1900→4460 — crossing the 1920 boundary. This is the typical straddle pattern.

## Diagnosis

```bash
# Check the game's window position (get class and title first)
hyprctl clients -j | python3 -c "
import sys, json
clients = json.load(sys.stdin)
for c in clients:
    print(f'{c[\"class\"]:30s} x={c[\"at\"][0]:5d} y={c[\"at\"][1]:3d} w={c[\"size\"][0]:4d}h={c[\"size\"][1]:3d} ws={c[\"workspace\"][\"name\"]}')
"
```

A straddling window will show `x` near 0-1920 when it should be ≥1920 for the primary monitor.

## Immediate Fix

```bash
# Move the game window to the primary monitor and center it
hyprctl dispatch movetoworkspace 1,class:^(StarCitizen)$
hyprctl dispatch centerwindow,class:^(StarCitizen)$
```

Or by title if class isn't unique:
```bash
hyprctl dispatch movetoworkspace 1,title:^(Star Citizen)$
```

## Permanent Fix: Hyprland Window Rule

Add to `~/.config/hypr/hyprland.conf` or a dedicated `windowrules.conf`:

```bash
# Force game windows to workspace 1 (primary monitor)
windowrulev2 = workspace 1, class:^(StarCitizen)$
windowrulev2 = move 1920 0, class:^(StarCitizen)$
```

The `move 1920 0` places the window at the top-left of the primary display (which starts at x=1920 in a standard layout). Adjust the x coordinate to match your monitors.conf positioning.

## Game-Specific Fixes

### Star Citizen (Proton/XWayland)

The window position is stored in the Proton prefix's user config directory. Look for `user.cfg` in the compatdata folder:

```
r_width = 2560
r_height = 1440
r_fullscreen = 1
r_fullscreenWindow = 1
```

Or use launch options in Steam:
```
-force-d3d11 -window-mode exclusive
```

### General Proton/Wine Games

Reset the game's virtual display and window position by clearing the per-game config under the Proton prefix.

## Root Cause

The `hyprctl reload` fix (from `monitor-mode-dpms-wake.md`) correctly restores the resolution. The window straddle is a **secondary symptom**: during the DPMS cycle, the compositor momentarily sees an incomplete monitor layout, and if the game window is restored during this window, its saved position is applied to a corrupted coordinate space.

The game then writes this corrupted position to its config file, persisting the straddle for future launches until manually corrected.

## Prevention

The most robust approach is a **Hyprland window rule** that explicitly anchors the game to the primary monitor's workspace. This doesn't depend on the game's saved position and survives DPMS cycles cleanly.
