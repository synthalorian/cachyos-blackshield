# SWTOR on Linux (Steam/Proton) — May 2026 Findings

## Status: Platinum on ProtonDB (App ID 1286830)

## Working Configuration

| Component | Value |
|-----------|-------|
| Proton | **10.0-3** or **10.0-4** (Valve official) |
| GPU | AMD Radeon (tested on RX 7900 XTX, RX 9070 XT, Radeon 860M) |
| GPU Driver | Mesa 25.x–26.x (vulkan-radeon) |
| Windowing | Windowed or Windowed Fullscreen ONLY |
| Kernel | 6.12–7.0 |
| Distros confirmed | CachyOS, Ubuntu 24.04, Debian 13, NixOS |

## Critical Findings

### 1. Use Proton 10.0-3 — NOT GE-Proton

GE-Proton 9-32 fails for SWTOR (launch issues). Every successful ProtonDB report as of May 2026 uses Valve's **Proton 10.0-3**. GE-Proton's bleeding-edge wine patches regress SWTOR's modified Hero Engine.

If Proton 10.0-3 isn't available, **Proton 9.0-4** is the fallback (one reporter downgraded successfully).

### 2. Exclusive Fullscreen Crashes After ~15 Minutes

Multiple reporters with 90+ hours confirm: exclusive fullscreen mode causes crashes. Use **Windowed or Windowed Fullscreen** mode only.

Config file path (in Proton prefix):
```
~/.steam/steam/steamapps/compatdata/1286830/pfx/drive_c/users/steamuser/AppData/Local/SWTOR/swtor/settings/client_settings.ini
```

Set:
```ini
[Renderer]
FullScreen = false
D3D11 = true
```

### 3. Hyprland Window Rules (0.55+ syntax)

```hyprlang
windowrule = fullscreen on, match:class steam_app_1286830
windowrule = idle_inhibit fullscreen, match:class steam_app_1286830
```

The `idle_inhibit fullscreen` rule replaces the old `immediate` — it prevents the compositor from sleeping and disables VSync while the game is fullscreen, which is essential for mouse capture (without it, the cursor escapes the game window during combat).

### 4. Gamescope Fallback

If Hyprland focus/mouse issues persist, use gamescope to isolate the game from the compositor:

```
pacman -S gamescope
```

Steam launch options:
```
gamescope -W 1920 -H 1080 -f -- %command%
```

### 5. Launch Options — Start Minimal

```
PROTON_LOG=1 %command%
```

Don't pile on environment variables until you know what's actually broken. AMD users may add later if needed:
```
DXVK_ASYNC=1 RADV_PERFTEST=gpl %command%
```

### 6. AMD Vulkan Stack

```bash
sudo pacman -S mesa vulkan-radeon lib32-vulkan-radeon
```

### 7. Known Bugs

- **EULA/Terms of Service doesn't save** between launches — must re-agree every time. Known Proton bug with SWTOR's Chromium-based launcher.
- **Launcher cache corruption** — if launcher hangs or shows blank, delete the cache in the Proton prefix and relaunch.

## Why the 64-Bit Client Matters

BioWare migrated SWTOR to a 64-bit client (~2024-2025). This eliminated the 32-bit Proton workarounds that made the game painful on Linux for years. Proton 10.x handles the 64-bit client cleanly.

## Loading Screen Hang — Troubleshooting Path

**Symptom:** Launcher works, you click Play, loading screen appears, then freezes/hangs. No crash to desktop — just a frozen loading screen.

This is the most common SWTOR-on-Linux failure mode. Multiple Steam forum reports confirm the pattern.

### Fix 1: Wipe the Wine Prefix (most likely fix)
Prefix corruption is the #1 cause, especially after game updates or switching Proton versions.
```bash
rm -rf ~/.steam/steam/steamapps/compatdata/1286830
```
Relaunch — Proton rebuilds the prefix from scratch. Re-agree to EULA, redo settings.

### Fix 2: Force Windowed Mode Before Launch
If the hang is actually the exclusive fullscreen crash happening silently, force windowed mode in the config file BEFORE launching:
```
~/.steam/steam/steam/steamapps/compatdata/1286830/pfx/drive_c/users/steamuser/AppData/Local/SWTOR/swtor/settings/client_settings.ini
```
```ini
[Renderer]
FullScreen = false
D3D11 = true
```

### Fix 3: Try Proton 10.0-3 Instead of 10.0-4
Every successful ProtonDB report uses **10.0-3**. Newer is NOT better with Proton — 10.0-4 may introduce regressions. If 10.0-3 isn't in the dropdown, try **9.0-4** as fallback (confirmed working by one ProtonDB reporter).

### Fix 4: Launch Arguments (escalation order)
```
PROTON_LOG=1 PROTON_NO_FSYNC=1 %command%
```
If still hangs:
```
PROTON_LOG=1 PROTON_NO_FSYNC=1 PROTON_NO_ESYNC=1 %command%
```
`PROTON_NO_FSYNC=1` disables fast sync — a known crash trigger for some Proton games.

### Fix 5: Gamescope (bypasses Wayland/Hyprland entirely)
```bash
pacman -S gamescope
```
Launch options: `gamescope -W 1920 -H 1080 -f -- %command%`

### Debugging: Read the Proton Log
After a hang with `PROTON_LOG=1`:
```bash
cat ~/steam-1286830.log
```
This tells you exactly where it died — DXVK init, shader compile, fullscreen transition, etc.

### Community Reports of This Issue
- Steam forum "Game no longer functions via Proton on linux" (May 2025) — identical symptom: loading screen before character select freezes on GE-Proton and Proton Experimental
- Steam forum "Anyone else having issues in Linux?" (Mar 2025) — loading screen never loads after updates, using Proton-Experimental
- Steam forum "New update stuck on loading screen" (Dec 2023) — memory leak identified as cause

## Bink Video (.bik) Crashes — Splash Screen Hang Fix

**Symptom:** Game hangs/freezes immediately after the Lucasfilm splash screen, or after clicking Play when the intro cinematic tries to play. The hang is caused by Proton's media foundation failing to decode Bink video files.

**Fix:** Rename the intro video files so the game skips them. Located at:
```
# Shared splash videos
~/.steam/steam/steamapps/common/Star Wars - The Old Republic/Movies/shared/
  bioware_intro.bik
  ea_intro.bik
  lec_intro.bik
  rating_esrb.bik

# Main intro cinematic
~/.steam/steam/steamapps/common/Star Wars - The Old Republic/Movies/en-us/
  game_intro.bik
```

```bash
cd "~/.steam/steam/steamapps/common/Star Wars - The Old Republic/Movies/shared"
for f in bioware_intro.bik ea_intro.bik lec_intro.bik rating_esrb.bik; do
  mv "$f" "${f}.bak"
done

cd "../en-us"
mv game_intro.bik game_intro.bik.bak
```

To restore: rename `.bak` files back to original names.

**Progression observed:** Game may crash at first splash (Lucasfilm) → skip those → crashes at BioWare logo → skip those → crashes at main intro cinematic. Each .bik rename advances past one crash point. After renaming all intros, game loads to character select.

## Hyprland "Fake Hang" — Window Visibility Issue

**Symptom:** Game appears to hang on a loading screen or black screen, but is actually running fine in a window that's invisible or rendering at wrong dimensions on Hyprland.

**Fix:** Press your maximize/fullscreen keybind (e.g., Super+F in Omarchy) to force the window to fill the screen. The game was running the whole time — it just wasn't visible.

**Prevention:** Add window rules to Hyprland config so the game auto-fullscreens on launch (0.55+ syntax):
```hyprlang
windowrule = fullscreen on, match:class steam_app_1286830
windowrule = idle_inhibit fullscreen, match:class steam_app_1286830
```

This pattern likely applies to other Proton games on Hyprland — if a game "hangs" on a loading or black screen, try maximizing the window before assuming it's crashed.

## Provenance

ProtonDB reports (May 2026), Steam community forums, tested configurations across AMD GPUs on Arch-based distros with Hyprland. Bink video fix and fake-hang diagnosis confirmed May 2026 on Omarchy (Arch + Hyprland).
