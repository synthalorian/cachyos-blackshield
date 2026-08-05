# Gaming Idle Inhibit on Hyprland

## Problem

Proton/Wine games using Vulkan (Star Citizen, DX12-through-VKD3D games, etc.) crash when the desktop screensaver, screen locker, or DPMS turns off the display. The Vulkan device context is lost when the compositor takes over the display, and most game engines handle this by... crashing.

The crash chain:
1. hypridle timeout fires
2. Screensaver launches (org.omarchy.screensaver)
3. hyprlock activates after timeout
4. DPMS powers off displays
5. Game's Vulkan context is invalidated
6. Game segfaults or hangs

## Solution: Idle Inhibit Wrapper

The simplest and most reliable fix is a shell wrapper that tells Hyprland to **inhibit idle** while the game (or its launcher) is running.

### Generic Template

```bash
#!/usr/bin/env bash
#
# <Game Name> — Idle Inhibit Wrapper
# Prevents screensaver/lock/DPMS from triggering while the game runs.
#

cleanup() {
  hyprctl dispatch hypridle uninhibit 2>/dev/null || true
}

trap cleanup EXIT INT TERM

# Block idle
hyprctl dispatch hypridle inhibit 2>/dev/null || true

# Launch the game (with optional gamemoderun for performance)
exec gamemoderun "/path/to/game/launcher.sh" "$@"
```

Place this next to your game launcher, make it executable (`chmod +x`), and create a desktop entry pointing to it.

### How It Works

- `hyprctl dispatch hypridle inhibit` — tells hypridle to pause all idle timeouts. The screensaver won't fire, hyprlock won't activate, DPMS won't trigger.
- The `trap cleanup EXIT` — ensures `uninhibit` runs when the wrapper exits (whether normally, by interrupt, or by termination).
- `exec gamemoderun ...` — replaces the shell process with the game launcher under gamemode (CPU governor, I/O niceness, GPU scheduler). Optional but recommended.

### Verification

```bash
# Check inhibit status (look for "inhibited" in output)
hyprctl hypridle

# During gameplay, verify idle is blocked:
# — Wait past your normal idle timeout (e.g. 2.5m for screensaver)
# — Screensaver should NOT fire
# — hyprlock should NOT activate
```

### Cleanup

The `uninhibit` fires automatically when the wrapper exits. If you need to manually restore idle:

```bash
hyprctl dispatch hypridle uninhibit
```

## Gamescope Caveat

Gamescope is often recommended for this problem, but **it does not work with launcher-wrapper games** (RSI Launcher, EA App, Ubisoft Connect, Battle.net, etc.).

**Why:** Gamescope runs the process you give it in an isolated compositor. The launcher runs fine, but when it spawns the actual game binary as a child process, the child doesn't properly inherit the gamescope session. Result: black screen on game launch, then crash.

**Use cases that DO work with gamescope:**
- Steam native games (set `gamescope %command%` in launch options)
- Standalone game binaries
- Games that are launched directly (no intermediary launcher)

**Use cases that need idle-inhibit instead:**
- Any game with a separate launcher process
- Star Citizen (RSI Launcher)
- EA App / Ubisoft Connect / Battle.net games

## Star Citizen Specific Setup

Star Citizen uses the LUG helper with a custom Wine runner. The launcher is at `~/Games/star-citizen/sc-launch.sh`.

**Desktop entry (the one that shows in Walker):**
```
~/.local/share/applications/starcitizen.exe.desktop
Name=Star Citizen
Icon=starcitizen
Exec="/home/synth/Games/star-citizen/sc-launch.sh"
```

### Pitfall: Persistent Launcher Processes

The RSI Launcher doesn't exit when the game exits — it stays in the system tray. This breaks a naive idle-inhibit wrapper that uses `exec` + `trap cleanup EXIT`:

```bash
#!/bin/bash
trap cleanup EXIT
hyprctl dispatch hypridle inhibit
exec gamemoderun ./sc-launch.sh   # <-- never returns
```

Because `exec` waits for the RSI Launcher to fully exit, **idle stays inhibited forever** until the user manually runs `hyprctl dispatch hypridle uninhibit` or force-kills the launcher.

**For this reason, no working idle-inhibit wrapper has been successful with Star Citizen via the LUG runner.** The original launch script without inhibit is the current stable approach. The crash-on-screensaver issue for Star Citizen specifically remains unresolved with this method.

### Killing Hung Wine Processes

Wine processes (`rsi launcher.exe`, `starcitizen.exe`) don't always die to `pkill -f <name>` — the process names as seen by the system don't always match what you expect.

**Reliable kill sequence:**
```bash
# 1. Find PIDs
hyprctl clients -j | python3 -c "import sys,json;clients=json.load(sys.stdin);[print(c['pid'], c['class'], c['title'][:40]) for c in clients if 'launcher' in c['class'].lower() or 'citizen' in c['class'].lower()]"

# 2. Kill by PID
kill -9 <pid1> <pid2>

# 3. Kill Wine server
~/Games/star-citizen/runners/<runner>/bin/wineserver -k

# 4. Verify
pgrep -a -f "rsi\|starcitizen\|sc-launch" | grep -v pgrep || echo "clean"
```

## Related

- `monitor-mode-dpms-wake.md` — companion fix for monitor resolution after lock/unlock
- `~/.config/hypr/hypridle.conf` — idle timing and lock/screensaver triggers
- `hyprctl dispatch hypridle` — command reference for inhibit/uninhibit

## Session Notes (2026-05-15)

- **Game:** Star Citizen via LUG Wine runner (lug-wine-tkg-git-11.8-1)
- **Attempted:** Gamescope wrapper — launcher renders, game spawns as child process, black screen + crash. Gamescope cannot handle launcher-wrapper games.
- **Attempted:** Idle-inhibit + gamemode wrapper — `exec` never returns because RSI Launcher persists in system tray. Idle stays inhibited forever. No working inhibit wrapper for Star Citizen via LUG.
- **Result:** Reverted to original LUG launch script. Single clean desktop entry (`starcitizen.exe.desktop`, `Name=Star Citizen`, `Icon=starcitizen`).
- **Lesson:** Gamescope is not viable for launcher-wrapper games. Idle-inhibit is the right concept but needs a lifecycle-aware approach for persistent launchers (e.g. background the launcher, poll for game PID, wait for game exit, then uninhibit).
