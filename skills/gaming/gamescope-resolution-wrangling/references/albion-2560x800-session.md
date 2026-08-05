# Albion Online 2560x800 Session (2026-08-03)

Goal: "giga ultrawide" 2560x800 Albion on a 2560x1440@144 monitor (HDMI-A-1),
CachyOS + KDE Plasma 6.7 Wayland, GTX 1080 Ti (NVIDIA proprietary), gamescope 3.16.24.

## What was tried, in order

1. **Native custom mode via kwinoutputconfig.json** — injected
   `{"width":2560,"height":800,"refreshRate":60000,"flags":0}` into `customModes` for
   HDMI-A-1. Never appeared in System Settings: KWin reads the file only at startup
   (verified in KWin 6.7 source, `outputconfigurationstore.cpp` — `readLegacyCustomMode`
   confirms the schema was correct).
2. **Live injection via `kscreen-doctor output.HDMI-A-1.addCustomMode.2560.800.60000.reduced`**
   — mode registered (`Custom modes: 0: 2560x800@59.97 (reduced blanking)`), but applying
   failed: "The driver rejected the output configuration". Full blanking also rejected.
   Even standard 2560x1080 rejected → NVIDIA blocks all custom modes on this stack.
3. **gamescope `-b` (borderless)** — window floated misplaced on KWin: game anchored
   upper-left, wallpaper bleeding below, offset black column. Abandoned for `-f`.
4. **gamescope `-f` (fullscreen)** — full-width 2560x800 strip but TOP-ALIGNED (y=0,
   ~640px black bar below) instead of centered (should be y=320–1120, symmetric 320px
   bars). Fit scale computes to 1.0 (2560==2560) and gamescope places at origin.
5. **2x nested trick** (`-w 5120 -h 1600`, intended to force downscale+center) — vkcube
   test crashed at WSI ("Failed to get Wayland objects", exit -11); log showed
   `edid: Patching res 800x1280 -> 3840x1600`. Inconclusive, not retried.

## The resolution fight (root cause chain)

Symptoms along the way: prefs rewritten to 1280x800 after being hand-set to 2560x800;
game settings reportedly offering only "1366x768" (actually **1368x768** from gamescope's
RandR fallback list); final render a ~1280-wide pillarboxed island.

Smoking gun in `~/.config/unity3d/Sandbox Interactive GmbH/Albion Online Client/Player.log`:

```
requesting fullscreen 1280 x 800 at 0/1 Hz
Command line arguments: ... "-screen-fullscreen 1" +fullscreen -screen-width 1280 -screen-height 800 +steam -force-vulkan +server loginserver.live.albion.zone:5055 ...
Display 0 'gamescope': 2560x800 (primary device).
```

The Albion Qt launcher reads the saved resolution and re-injects it as Unity args every
launch; Albion's video settings re-assert and rewrite PlayerPrefs. Manual prefs edits are
reverted. Resolution had to be changed IN-GAME (Settings → Video → 2560x800 top of
dropdown) so the whole chain (prefs → launcher args → runtime) agrees.

Final working launch options (user's, incl. prior Albion flags):

```
gamemoderun gamescope -w 2560 -h 800 -W 2560 -H 1440 -S fit -f -- %command% -screen-width 2560 -screen-height 800
```

(+ Albion's own `+server loginserver.live.albion.zone:5055 +serverenvironment live` were
already applied by the launcher/launch options separately.)

## Session-side incidents

- `pkill -TERM -f "game_x64/Albion-Online"` killed the agent's own shell (pattern matched
  its own command line). Killed game by PID instead; game ignored SIGTERM, needed -9.
- `kscreen-doctor` and `systemsettings` core-dumped until session env was exported
  (createEventDispatcher abort — missing WAYLAND_DISPLAY etc.).
- Steam was running the whole time → all launch-option changes went through the Steam UI,
  not localconfig.vdf.
