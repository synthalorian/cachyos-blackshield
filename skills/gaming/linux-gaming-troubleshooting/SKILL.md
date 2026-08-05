---
name: linux-gaming-troubleshooting
description: >-
  Diagnose why a Linux game (especially Wine/DXVK/VKD3D titles) runs differently
  than a previous session — crashes, GPU device lost, performance regression,
  launcher failures, or won't launch at all. Covers the full forensic pipeline:
  process state → logs → GPU/crash analysis → session comparison → system change detection.
---

# Linux Gaming Troubleshooting

**Trigger conditions:** User says "game isn't running like it was last night", "game keeps crashing", "performance is worse than before", "it used to work", "game won't launch", or any regression-comparison against a known-good prior session. Also triggers on GPU crash errors (`VK_ERROR_DEVICE_LOST`, `GPU Crash`) in game logs. Covers both Lutris/Wine-prefix games and Steam/Proton titles.

## Step 1 — Gather Context

Ask what "not running like it was" actually means — the symptom determines the diagnostic path:

1. **GPU crash / freeze** → Step 3 (Game.log analysis) + Step 4 (GPU diagnostics)
2. **Lower FPS / stutter** → Step 4 (GPU state) + Step 5 (session comparison)
3. **Won't launch / launcher broken** → Step 2 (process + launcher logs)
4. **Crashes at specific location/action** → Step 3 (Game.log tail) + Step 7 (memory pressure)
5. **Steam/Proton game won't launch or crashes** → Step 10 (Proton version + ProtonDB)

## Step 2 — Initial Process & System Scan

```bash
# Check if game or launcher is running
ps aux | grep -iE "starcitizen|rsi|star" | grep -v grep

# Quick system health
df -h /home          # disk space
free -h              # RAM pressure
swapon --show        # swap usage
zramctl              # zram compression (indicates memory pressure)
uptime               # system uptime — freshly booted vs days-old
```

## Step 3 — Locate Game Installation & Logs

Linux game installs typically under:
- **Lutris:** `~/Games/<game-name>/`
- **Heroic:** `~/Games/Heroic/`
- **Standalone Wine:** whatever `WINEPREFIX` points to

Key log files to check:
```
# Launch script + log (Lutris setup)
~/Games/<game>/<game>-launch.sh
~/Games/<game>/<game>-launch.log

# Launcher logs (RSI Launcher in particular)
~/Games/<game>/drive_c/users/$USER/AppData/Roaming/rsilauncher/logs/log.log

# Game engine log
~/Games/<game>/drive_c/Program Files/.../<Game>/<Game>.log
# Common names: Game.log, output_log.txt, player.log

# Log backups / rotated logs
ls ~/Games/<game>/.../logbackups/
```

## Step 4 — GPU & Vulkan Diagnostics

```bash
vulkaninfo --summary 2>/dev/null | grep -E "GPU|deviceName|driverVersion"

# GPU temperature (AMD)
cat /sys/class/drm/card*/device/hwmon/hwmon*/temp1_input 2>/dev/null | awk '{print $1/1000"°C"}'

# GPU power draw
cat /sys/class/drm/card*/device/hwmon/hwmon*/power1_average 2>/dev/null | awk '{print $1/1000000"W"}'

# DXVK/VKD3D info
grep -i "DXVK\|VKD3D\|Found device\|Vulkan" ~/Games/<game>/<game>-launch.log | head -10
```

Key patterns to watch for:
- `VK_ERROR_DEVICE_LOST` — GPU timeout, caused by memory pressure, driver bug, or overwork
- `vkQueueSubmit() failed` — the GPU didn't respond in time
- `GPU Crash Vulkan ( async ): AMD - Device Lost` — common on AMD RADV, especially new architectures (RDNA 4 / GFX1201)
- `radv is not a conformant Vulkan implementation` — harmless RADV message

## Step 5 — Crash Analysis (Game.log)

Search the game log for crash markers:

```bash
grep -i "gpu crash\|device_lost\|vkqueue\|VK_ERROR\|gpu crash\|commit\|Memory (Committed)" <Game.log>
```

Crash log typically includes a performance summary — key numbers:

```
CPU (MainThread)    : XX.X FPS (XX.X ms)|...
Memory (Committed)  : Min: XXXX MB Max XXXX MB
```

Memory above 25GB commit on a 32GB system indicates serious memory pressure.

## Step 6 — Session Comparison

When the user says "ran fine last night", compare current session against backed-up logs:

```bash
# List previous sessions
ls -la <game>/logbackups/

# Extract performance from each
for log in <game>/logbackups/*.log; do
  mem=$(grep -a "Memory (Committed)" "$log" | tail -1)
  fps=$(grep -a "CPU (MainThread)" "$log" | tail -1)
  crash=$(grep -c "GPU CRASH\|VK_ERROR\|DEVICE_LOST" "$log")
  echo "$(basename "$log"): $mem | FPS: $fps | Crashes: $crash"
done
```

Look for:
- **Memory creep** — later sessions using more memory
- **FPS regression** — same game area but lower FPS
- **Pattern of crashes** — only on certain areas (hangar vs space, QT, planetary landing)

## Step 7 — System Change Detection

Check for driver/package changes that might explain a regression:

```bash
# AMD/Mesa/Vulkan driver changes
grep -i "mesa\|amdgpu\|vulkan\|radv\|linux-" /var/log/pacman.log | tail -30

# Kernel changes
uname -a
```

## Step 8 — Known Config Files to Check

```bash
# Wine/DXVK config
cat <WINEPREFIX>/dxvk.conf 2>/dev/null        # DXVK settings
cat <WINEPREFIX>/vkd3d_proton.conf 2>/dev/null # VKD3D settings

# Game config (user.cfg for CryEngine/Lumberyard games)
cat <game>/drive_c/.../<Game>/user.cfg 2>/dev/null

# Lutris runner version
ls <WINEPREFIX>/runners/
```

## Step 9 — Crash Dump Check

```bash
find <WINEPREFIX>/drive_c/users/$USER/AppData/Local/ -name "error.dmp" -o -name "*.dmp" 2>/dev/null
```

Note: crash dumps are often empty on Linux/Wine. Still worth checking.

## Step 10 — Steam/Proton Game Troubleshooting

For Steam games running via Proton (not Lutris/Wine prefix):

### Proton Version Selection

GE-Proton is NOT always better. Some games regress on bleeding-edge wine patches. Check ProtonDB first.

```bash
# List installed Proton versions
ls ~/.steam/root/compatibilitytools.d/
ls ~/.steam/steam/compatibilitytools.d/
```

**Decision order:**
1. Check ProtonDB (https://www.protondb.com/app/<APP_ID>) for which Proton version recent reporters are using
2. Try that exact version first
3. If using GE-Proton and it fails, try the matching Valve official Proton (e.g., GE-Proton 9-x → Proton 9.0-x)
4. If latest Proton fails, try one major version back (e.g., 10.0-3 fails → try 9.0-4)

### Common Proton Paths

```bash
# Steam app compat data (Wine prefix)
~/.steam/steam/steamapps/compatdata/<APP_ID>/pfx/

# Game config files (inside prefix)
~/.steam/steam/steamapps/compatdata/<APP_ID>/pfx/drive_c/users/steamuser/AppData/Local/<Game>/

# Proton logs (when launched with PROTON_LOG=1)
~/steam-<APP_ID>.log
```

### Fullscreen Issues on Wayland/Hyprland

Many Proton games crash in exclusive fullscreen under Wayland. Pattern:
- Use Windowed or Windowed Fullscreen (Borderless) mode
- If the game can't launch to change settings, edit the config file directly in the Proton prefix
- Use gamescope as a fullscreen wrapper: `gamescope -W <width> -H <height> -f -- %command%`
- Add Hyprland window rules for fullscreen + idle_inhibit (0.55+ syntax: `windowrule = fullscreen on, match:class <classname>`)

### AMD Vulkan Stack

```bash
sudo pacman -S mesa vulkan-radeon lib32-vulkan-radeon
```

### Proven Game References

- **SWTOR** (1286830): Proton 10.0-3 and 10.0-4 both work. Windowed fullscreen only (exclusive fullscreen crashes after ~15 min). Bink video (.bik) splash screens crash under Proton — rename `bioware_intro.bik`, `ea_intro.bik`, `lec_intro.bik`, `rating_esrb.bik` in `Movies/shared/` and `game_intro.bik` in `Movies/en-us/` to skip intros (add `.bak` extension). Game may appear "hung" on loading screen but is actually running in an invisible window — maximize with Super+F or add Hyprland window rules. Hyprland 0.55+ syntax: `windowrule = fullscreen on, match:class steam_app_1286830` + `windowrule = idle_inhibit fullscreen, match:class steam_app_1286830`. See `references/swtor-proton-linux.md`

## Pitfalls

- **GE-Proton is not always the answer** — bleeding-edge patches can regress specific games (e.g., SWTOR fails on GE-Proton 9-32 but works perfectly on Valve Proton 10.0-3). Always check ProtonDB for which version recent successful reports use
- **Exclusive fullscreen on Wayland** — many DX9/DX11 games crash in exclusive fullscreen under XWayland. Windowed/Borderless is the safe default
- **Empty crash dumps** — common on Linux/Wine; don't treat missing crash data as "no crash"
- **SC commit size of 25-29GB** is "normal" for Star Citizen in busy areas — but on a 32GB system it leaves only 2-3GB free, triggering GPU timeout
- **First session seems fine** — memory leak builds up; session 1 at 21GB may run fine, session 2 at 29GB crashes
- **RX 9070 XT (RDNA 4 / GFX1201)** is a very new architecture — RADV support may have quirks that manifest as GPU device lost under heavy load
- **Hardware acceleration** in browsers (Brave, Chrome) competes for GPU resources — check with `free -h` before concluding it's a game issue
- **GPU temperature** readings at idle (37°C) don't reflect peak load — need in-game monitoring
- **"Fake hang" on Hyprland** — Proton games may appear frozen on a black/loading screen but are actually running in an invisible or tiny window. Try maximizing the window (Super+F) before assuming crash. Add `fullscreen` + `idle_inhibit fullscreen` window rules to auto-fix (0.55+ syntax: `windowrule = fullscreen on, match:class <classname>`).
- **Bink video (.bik) crashes under Proton** — Games using Bink for splash screens/intro cinematics (SWTOR, many older titles) can hang when Proton's media foundation fails to decode them. Fix: rename the .bik files in the game's Movies/ directory to `.bik.bak` to skip intros. For SWTOR, rename `bioware_intro.bik`, `ea_intro.bik`, `lec_intro.bik`, `rating_esrb.bik` in `Movies/shared/`, and `game_intro.bik` in `Movies/en-us/`. If a game hangs at a specific splash screen logo, this is the likely cause.
- **DXVK 2.7.1** is most recent stable; if you find an older version, upgrading may help

## Absorbed Skills (Consolidated 2026-05-27)

- **wine-proton-display** — Wayland display mode caching fix after suspend/resume. Resume hook scripts + systemd service. Refs: `references/ascension-wow-20260514.md`, scripts/resume-hook.sh, templates/wine-resume-fix.service
- **archeage-classic-linux** — ArcheAge Classic on Linux via Wine/ProtonGE. Full install guide, WebView2 launcher troubleshooting, Proton 11 setup. Refs: `references/graphics-troubleshooting.md`, `references/launcher-troubleshooting.md`, `references/proton11-launch.md`, `references/webview2-installation.md`, `references/known-issues.md`
- **subnautica-nitrox** — Subnautica Nitrox multiplayer on Linux/Proton. DLL injection, sandbox workarounds, launcher scripting. Refs: `references/dll-sources.md`, `references/server-log-examples.md`

## References

- `references/star-citizen-rdna4-crash-pattern.md` — Star Citizen AMD RX 9070 XT GPU crash analysis, memory pressure patterns, session-by-session performance data
- `references/swtor-proton-linux.md` — SWTOR Steam/Proton setup: Proton 10.0-3, windowed fullscreen, Hyprland rules, AMD stack, known bugs
- `references/ascension-wow-20260514.md` — Ascension WoW display mode fix implementation
- `references/graphics-troubleshooting.md` — ArcheAge Classic graphical issues and fixes
- `references/launcher-troubleshooting.md` — ArcheAge Tauri v2 32/64 architecture mismatch
- `references/proton11-launch.md` — Proton 11 launch configuration for ArcheAge
- `references/webview2-installation.md` — WebView2 Runtime installation under Wine
- `references/known-issues.md` — ArcheAge known issues
- `references/dll-sources.md` — Subnautica Nitrox DLL sourcing
- `references/server-log-examples.md` — Nitrox server log patterns
