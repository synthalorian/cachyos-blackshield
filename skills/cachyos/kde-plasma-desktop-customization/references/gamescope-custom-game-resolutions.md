# Gamescope custom game resolutions on Wayland (Albion 2560x800 session, 2026-08)

Goal: run a game at a resolution the panel/driver won't do natively — 2560x800
("32:10 giga-ultrawide" letterbox) on a 2560x1440 monitor. NVIDIA + KWin Wayland
rejects ALL custom display modes (even standard 2560x1080), so gamescope is the
only no-reboot path. (Kernel `video=HDMI-A-1:2560x800@60` cmdline force remains
the untested fallback for whole-desktop custom res.)

## Final working recipe (Steam launch options)

```
gamemoderun gamescope -w 2880 -h 900 -W 2560 -H 1440 -S fit -f -O HDMI-A-1 -- %command% -screen-width 2880 -screen-height 900
```

- `-w/-h` nested res the game sees; `-W/-H` real panel; `-S fit` letterbox;
  `-f` true fullscreen; `-O` pin output connector.
- Nested 2880x900 = same 32:10 aspect, slightly larger than the panel → gamescope
  downscales to 2560x800 AND centers it (see quirk below). Bonus: supersampling.
- The trailing `-screen-width/-height` are Unity args (see below).

## Verified gamescope mechanics (gamescope 3.16, KWin 6.7, GTX 1080 Ti)

- **Centering quirk:** `-S fit` at effective scale 1.0 places the image TOP-LEFT
  (observed: full-width 2560x800 strip at y=0, 640px black below, instead of
  centered y=320–1120). Forcing scale ≠ 1 (bigger nested res, downscale to fit)
  engages centering with symmetric bars. Verified with glxgears before/after.
- **`-b` vs `-f`:** `-b` (borderless) on KWin Wayland becomes a floating
  undecorated window, misplaced, wallpaper bleeding around it. `-f` works.
- **Wrong monitor:** gamescope grabs whichever output it likes (took the 180Hz
  1080p panel in testing) — always pin `-O <connector>` from `kscreen-doctor -o`.
- **Inspect what the game can see:** gamescope's fake X server shows up in
  `ls /tmp/.X11-unix/` (e.g. `:1`); `DISPLAY=:1 xrandr` lists the exact mode set
  advertised to the game (native nested mode marked `*+`, plus fallbacks).
- GUI test loop: `gamescope ... -- glxgears` from an env-exported terminal +
  `spectacle -b -n -o /tmp/x.png` to verify geometry without the game.

## Unity-game specifics (Albion Online)

- Launch chain: Steam → gamescope → Qt launcher → real game binary. The launcher
  reads the game's saved video setting and RE-INJECTS it as
  `-screen-width/-screen-height` args (observed injecting 1280x800, later 1024x768
  after the user poked the settings UI). It also forwards user args after its own.
- Unity parses screen args last-wins, so appending `-screen-width 2880
  -screen-height 900` after `%command%` beats the launcher's injection.
- PlayerPrefs: `~/.config/unity3d/Sandbox Interactive GmbH/Albion Online Client/prefs`
  (XML-ish `<pref name=... type="int">` entries). The game rewrites these from its
  own settings manager at runtime/exit — editing them while the game runs is
  clobbered, and the game can reset them anyway. Do NOT rely on prefs edits; the
  forced cmdline args are the authority.
- The in-game resolution dropdown FILTERS exotic aspect ratios (never shows
  2560x800/2880x900; capped at 1368x768 under one nested res, 1600x900 under
  another). It's cosmetic — leave it alone, never hit Apply (Apply writes a junk
  res to prefs which the launcher re-injects next launch; still overridden by the
  appended args, but keeps the loop dirty).
- Useful log: `~/.config/unity3d/.../Player.log` — shows `Display 0 'gamescope':
  2560x800 (primary device)`, `requesting fullscreen WxH`, and the full command
  line Unity actually received (last line: `Command line arguments:`).

## Ops pitfalls from this session

- **pkill self-match:** `pkill -f "game_x64/Albion"` matches the agent's OWN
  shell (pattern appears in its command line) → kills the agent shell (exit -15).
  Use `pgrep -f "Albion.Onlin[e]"` bracket trick, or collect PIDs first and
  `kill <pid>` by number. Twice in one session — don't be third.
- GUI tools (systemsettings, kscreen-doctor, spectacle) need session env or they
  core-dump in createEventDispatcher:
  `export WAYLAND_DISPLAY=wayland-0 XDG_RUNTIME_DIR=/run/user/1000 DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus QT_QPA_PLATFORM=wayland`
- `kscreen-doctor output.HDMI-A-1.addCustomMode.2560.800.60000.reduced` registers
  a custom mode fine but applying ANY custom mode fails on NVIDIA ("The driver
  rejected the output configuration") — don't retry variants, go gamescope.
- Steam: edit launch options via the Steam UI while Steam runs; hand-editing
  `userdata/<id>/config/localconfig.vdf` under a live Steam gets clobbered on
  exit. Reading the vdf to VERIFY saved options is fine.
