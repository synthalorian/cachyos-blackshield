---
name: gamescope-resolution-wrangling
description: "Use when forcing custom game resolutions via gamescope."
tags: [gamescope, wayland, resolution, ultrawide, unity, steam, kwin]
---

# Gamescope Resolution Wrangling

Force games to render at resolutions the display/driver won't natively offer (e.g. 2560x800
ultrawide letterbox on a 2560x1440 panel), and debug gamescope geometry on KDE Wayland.
Also covers Unity games whose launcher overrides resolution at every launch.

## When to reach for gamescope vs native modes

- Try native custom mode first ONLY on non-NVIDIA stacks. On NVIDIA proprietary + Wayland,
  the driver rejects ALL custom display modes (even standard 2560x1080):
  `kscreen-doctor output.X.addCustomMode.W.H.mHz.reduced|full` registers but applying fails
  with "The driver rejected the output configuration". Go straight to gamescope.
- Only native-mode alternative: kernel cmdline `video=<CONNECTOR>:<W>x<H>@60` (bypasses EDID
  validation, needs reboot, black-screen risk if panel won't sync).

## Working recipe (Steam launch options)

```
gamemoderun gamescope -w 2560 -h 800 -W 2560 -H 1440 -S fit -f -- %command% -screen-width 2560 -screen-height 800
```

- `-w/-h` = nested res the game sees; `-W/-H` = real output; `-S fit` = letterbox; `-f` = fullscreen.
- **`-f`, not `-b`.** Borderless (`-b`) floats as a misplaced undecorated window on KWin
  Wayland (wallpaper bleeds around the game). Fullscreen claims the output correctly.
- Known quirk: when nested width == output width (fit scale computes to 1.0), gamescope
  TOP-ALIGNS the strip instead of centering it vertically. No flag fixes it; acceptable.
- Keep trailing `-screen-width W -screen-height H` for Unity games: Unity honors the LAST
  occurrence, so appended args beat launcher-injected ones.

## gamescope's nested display (what the game can pick)

gamescope spawns its own X server (`ls /tmp/.X11-unix/`, usually `:1`):

```bash
DISPLAY=:1 xrandr    # nested res is first and '+'-marked; rest are fallbacks
```

Fallback list contains native-lookalikes (**1368x768**, 1280x800) — a user saying "it only
offers ~1366x768" is reading this list. If the game renders at a fallback res, gamescope
upscales a small buffer → floating pillarboxed island instead of a clean letterbox.

## Unity games: the launcher resolution-override loop

Config-file surgery FAILS on Unity titles with launchers (verified on Albion Online):

1. Launcher reads saved resolution (PlayerPrefs) and injects it as launch args
   (`-screen-width 1280 -screen-height 800`).
2. The game's own video settings re-assert the saved res at runtime and REWRITE PlayerPrefs.
3. prefs → launcher args → runtime → prefs. Manual prefs edits get reverted every launch.

**Fix resolution IN-GAME** (Settings → Video dropdown — the gamescope nested res appears at
the top). That writes the right value into every link of the chain at once.

### Diagnosis paths

- PlayerPrefs: `~/.config/unity3d/<Publisher>/<Game>/prefs` —
  `<pref name="Screenmanager Resolution Width" type="int">` etc.
- `Player.log` (same dir) gold lines:
  - `requesting fullscreen <W> x <H>` — what the game actually asked for
  - `Command line arguments: ... -screen-width ...` — what the launcher injected THIS session
  - `Display 0 'gamescope': <W>x<H> (primary device)` — what Unity thinks the desktop is

### Verify visually, don't ask the user to describe

`spectacle -b -n -o /tmp/shot.png` captures all monitors without focus-stealing (needs
Wayland session env — see kde-plasma-desktop-customization). Screenshot → vision loop
answers "is it centered / letterboxed / stretched" in one step.

## Pitfalls

- `pkill -f "<pattern>"` matches your own shell's command line (pattern is in it) and kills
  your session. Kill by PID or self-exclude: `pgrep -f "Albion.Onlin[e]"`.
- Unity games can ignore SIGTERM on exit — escalate to `kill -9` after one try.
- Steam `localconfig.vdf` edits get clobbered if Steam is running — use the Steam UI for
  launch options, or quit Steam fully first.
- GUI apps (systemsettings, kscreen-doctor) launched from an agent terminal core-dump
  without session env (`WAYLAND_DISPLAY`, `XDG_RUNTIME_DIR`, `DBUS_SESSION_BUS_ADDRESS`) —
  full env line in kde-plasma-desktop-customization.

## References

- `references/albion-2560x800-session.md` — full Albion 2560x800 session: failed native
  modes, gamescope flag evolution, launcher arg traces, the 1280x800 smoking gun.
