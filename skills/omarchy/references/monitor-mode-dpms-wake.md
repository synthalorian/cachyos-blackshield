# Monitor Mode Restoration After DPMS Wake

## Problem

When using Omarchy with Hyprland + hypridle, the lock screen turns off displays via `hyprctl dispatch dpms off`. After unlocking, `omarchy-system-wake` runs `hyprctl dispatch dpms on`. However, **DPMS on does not guarantee the monitor returns to its configured mode** from `monitors.conf` — the monitor may wake in a fallback mode (often 1920×1080 or 640×480).

This causes:
- Primary monitor briefly black on lock (expected)
- After unlock, monitor returns but in wrong resolution/refresh rate
- XWayland games (Wine/Proton) see incorrect available resolutions
- 2K/1440p/ultrawide modes missing from in-game settings

## Diagnosis

```bash
# 1. Check current monitor modes
hyprctl monitors -j | jq '.[] | {name, width, height, refreshRate, dpmsStatus}'

# 2. Lock the computer, wait for DPMS off, then unlock
# 3. Re-check monitor output — note if resolution/refresh changed

# 4. Inspect omarchy-system-wake (the wake script after lock/unlock or resume)
cat $(which omarchy-system-wake)

# 5. Check monitors.conf for expected mode
cat ~/.config/hypr/monitors.conf
```

Expected symptom: `dpmsStatus: 1` (on) but `width×height@refreshRate` differs from monitors.conf.

## Fix

**Patch `omarchy-system-wake` to reload Hyprland config after DPMS on:**

```bash
# Edit the script (NEVER edit files in ~/.local/share/omarchy/ directly — this is user space)
sudo nano $(which omarchy-system-wake)
```

Add at the end:

```bash
# Monitor mode restoration after DPMS wake:
# dpms on doesn't guarantee the monitor returns to its configured mode.
# Reload Hyprland config to re-apply monitors.conf (restores 2K@180Hz, etc)
sleep 0.5
hyprctl reload >/dev/null 2>&1 || true
```

The script should look like:

```bash
#!/bin/bash

omarchy-brightness-display on
omarchy-brightness-keyboard restore

sleep 0.5
hyprctl reload >/dev/null 2>&1 || true
```

Ensure it's executable:

```bash
chmod +x $(which omarchy-system-wake)
```

## Why This Works

`hyprctl reload` re-parses Hyprland configuration, including `monitors.conf`. This explicitly re-assigns the configured resolution and refresh rate to each monitor, overriding whatever fallback mode the monitor settled into after DPMS wake.

The 0.5s delay gives the display time to fully power on before Hyprland re-applies the mode, preventing flicker or mode-set failures.

## Scope

This fix covers:
- Lock → unlock cycle (hypridle → omarchy-system-lock → omarchy-system-wake)
- Resume from suspend (`after_sleep_cmd` in hypridle.conf already calls `omarchy-system-wake`)
- Any manual DPMS off/on that doesn't go through the omarchy wake script

If you use a custom DPMS wake path (different script), apply the same pattern there.

## Related Files

- `~/.config/hypr/hypridle.conf` — idle/lock timing and commands
- `~/.config/hypr/monitors.conf` — monitor modes and positions
- `~/.local/share/omarchy/bin/omarchy-system-wake` — wake handler (patched)
- `~/.local/share/omarchy/bin/omarchy-system-lock` — lock handler (calls brightness off → dpms off)

## Session Notes (2026-05-14)

- **Hardware:** Primary monitor DP-2 (Shenzhen KTC GMQ3225RVC) at 2560×1440@180Hz, secondary HDMI-A-3 (HGC CR270C) at 1920×1080@180Hz
- **Game:** Ascension WoW (XWayland/Proton) failed to detect 2560×1440 after lock/unlock
- **Fix:** Added `sleep 0.5 && hyprctl reload` to `omarchy-system-wake`
- **Result:** 2K resolution now persists through lock cycle; game detects it correctly

## Session Notes (2026-05-15)

- **Symptom:** After lock/sleep, primary monitor wakes at fallback resolution; game fails to detect native 2560×1440
- **Fix applied:** Patched `~/.local/share/omarchy/bin/omarchy-system-wake` to add `sleep 0.5 && hyprctl reload` after brightness restoration
- **Immediate recovery:** `hyprctl reload` restores correct mode without reboot
- **Note:** `~/.local/share/omarchy/bin/omarchy-system-wake` is the source script (NOT in user config space), but patching it is safe since it's the authoritative wake handler for the omarchy system

## Session Notes (2026-05-15) — Window Straddle

- **Symptom:** Resolution restored correctly after DPMS wake, but Star Citizen (Proton/XWayland) launched with window spanning both monitors (x ≈ 1900, straddling the 1920 boundary)
- **Secondary problem:** After `hyprctl reload` restores resolution, the game's saved window position from the corrupted DPMS cycle persists in its config
- **Root cause:** During the DPMS cycle, the monitor layout coordinate space is momentarily inconsistent; the game writes the corrupted position to its config
- **Fix:** Hyprland window rule (`windowrulev2 = workspace 1, class:^(StarCitizen)$`) as the most robust solution — survives DPMS cycles regardless of saved positions
- **Alternative:** Clear the game's per-app window position config under the Proton wineprefix
- **Reference doc:** `references/game-window-straddle-dual-monitor.md` created under the omarchy skill
