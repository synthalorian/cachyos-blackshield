# SWTOR on Linux via Steam/Proton — Omarchy Guide

## Status: Platinum on ProtonDB (Steam App ID: 1286830)

Tested May 2026 on Omarchy (Arch + Hyprland 0.55) with AMD GPU.

## Working Proton Version

**Proton 10.0-3** or **Proton 10.0-4** — both work. GE-Proton 9-32 did NOT work (launcher issues). Every successful ProtonDB report from 2025-2026 uses Proton 10.0-3.

Steam → SWTOR → Properties → Compatibility → Force the Proton version.

## Three Required Fixes

### Fix 1: Bink Video Crash (launcher → loading screen hang)

SWTOR's intro splash videos (Bink `.bik` format) crash Proton's media playback. The game hangs after the Lucasfilm splash or at the main intro cinematic.

**Solution:** Rename the intro videos so the game skips them:

```bash
cd "~/.steam/steam/steamapps/common/Star Wars - The Old Republic/Movies/shared"
for f in bioware_intro.bik ea_intro.bik lec_intro.bik rating_esrb.bik; do
  mv "$f" "${f}.bak"
done

cd "../en-us"  # or your language folder
mv game_intro.bik game_intro.bik.bak
```

To restore later, rename `.bak` files back.

### Fix 2: Windowed Fullscreen Only

Exclusive fullscreen crashes SWTOR under Proton after ~15 minutes (confirmed by multiple ProtonDB reporters with 96+ hours). Use **Windowed Fullscreen** in-game.

If you can't get into the game to change it, edit the config directly:
```
~/.steam/steam/steamapps/compatdata/1286830/pfx/drive_c/users/steamuser/AppData/Local/SWTOR/swtor/settings/client_settings.ini
```
Set `FullScreen = false`.

### Fix 3: Hyprland Auto-Fullscreen (0.55+ syntax)

The game launches in a small window that looks like a hang. Maximizing (Super+F) reveals it. Automate with window rules:

```hyprlang
# In ~/.config/hypr/hyprland.conf or a sourced app-rules file
windowrule = fullscreen on, match:class steam_app_1286830
windowrule = idle_inhibit fullscreen, match:class steam_app_1286830
```

This makes Hyprland fullscreen the window AND disable idle/screen sleep while playing.

## Known Issues

- **EULA/Terms of Service don't save** — you must agree every launch. Known Proton bug with the SWTOR launcher.
- **Loading screen "hang"** — if the game appears to hang, try maximizing the window first. It may be running fine in a tiny/unvisible window.
- **Gamescope alternative:** If window rules don't work, use `gamescope -W 2560 -H 1440 -f -- %command%` in Steam launch options.

## Steam Launch Options

Start minimal — don't pile on environment variables:

```
PROTON_LOG=1 %command%
```

If you hit issues:
```
PROTON_NO_FSYNC=1 PROTON_LOG=1 %command%
```

## AMD GPU Notes

Ensure Mesa Vulkan drivers are current:
```bash
sudo pacman -S mesa vulkan-radeon lib32-vulkan-radeon
```

## Sources

- ProtonDB: https://www.protondb.com/app/1286830
- Steam Community: Multiple threads on Linux Proton issues
- Tested by synth (synthalorian) on Omarchy May 2026
