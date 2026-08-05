---
name: kde-plasma-desktop-customization
description: "KDE Plasma 6/Wayland desktop customization: per-monitor wallpapers, panel/Kickoff icons, Plasma restart, and display mapping. Triggers: KDE, Plasma, Wayland, wallpaper, monitor, panel, taskbar icon, Kickoff, Application Launcher, plasmashell."
version: 1.0.0
tags: [kde, plasma, wayland, wallpaper, panel, kickoff, taskbar, cachyos]
---

# KDE Plasma Desktop Customization

Use for Plasma 6/Wayland desktop changes on CachyOS: wallpapers across multiple monitors, panel icons, Kickoff/Application Launcher icon, and safe Plasma reloads.

## Core Rules

- Stay in `~/.config/` and user-owned paths unless the task explicitly requires system files.
- For per-monitor wallpapers, do NOT rely on `plasma-apply-wallpaperimage` — it has no monitor selector. Use the PlasmaShell scripting DBus endpoint and write each desktop containment by `screen` index.
- Before assigning images to screens, map Plasma screen indices to physical outputs with KWin support information. Example from a 2-monitor setup: KWin reported `Screen 0: Name: DP-3 Geometry: 1920,0,2560x1440` (primary) and `Screen 1: Name: HDMI-A-1 Geometry: 0,0,1920x1080` (secondary).
- For Kickoff/Application Launcher icon changes, edit the nested applet config group in `~/.config/plasma-org.kde.plasma.desktop-appletsrc`, then restart Plasma.
- Restart Plasma with `plasmashell --replace` (preferred) rather than killing it outright. In Hermes, run it via `terminal(background=true)` and kill the prior background plasmashell process first — a foreground `plasmashell --replace &` is rejected ("Foreground command uses '&' backgrounding").
- For lock/login wallpaper setup, configure files and verify paths only; do not lock the session, log out, or reboot just to preview unless the user explicitly asks.

## Quick Commands

Map screens:

```bash
qdbus6 org.kde.KWin /KWin org.kde.KWin.supportInformation | awk '/Screen|Name:|Geometry/{print}' | head -40
```

Set wallpapers per screen:

```bash
qdbus6 org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript '
var ds = desktops();
for (var i=0;i<ds.length;i++) {
  var d = ds[i];
  d.wallpaperPlugin = "org.kde.image";
  d.currentConfigGroup = ["Wallpaper", "org.kde.image", "General"];
  if (d.screen === 0) d.writeConfig("Image", "file:///path/to/primary.png");
  if (d.screen === 1) d.writeConfig("Image", "file:///path/to/secondary.png");
  d.writeConfig("FillMode", 2); // PreserveAspectCrop
}'
```

Set Kickoff icon (find the applet id first with `kickoff` in `plasma-org.kde.plasma.desktop-appletsrc`):

```bash
kwriteconfig6 --file plasma-org.kde.plasma.desktop-appletsrc \
  --group Containments --group <containmentId> --group Applets --group <appletId> \
  --group Configuration --group General \
  --key icon /absolute/path/to/icon.png
plasmashell --replace
```

Full session recipe: `references/per-monitor-wallpaper-and-kickoff-icon.md`.

## GUI apps & custom display modes (Hermes session)

- GUI apps (systemsettings, kscreen-doctor) launched from the Hermes terminal **core dump** (`createEventDispatcher` abort) without session env. Export first:
  `export WAYLAND_DISPLAY=wayland-0 XDG_RUNTIME_DIR=/run/user/1000 DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus QT_QPA_PLATFORM=wayland`
- kscreen-doctor works fine once env is set; `kscreen-doctor -o` lists outputs/modes/custom modes.
- **GTX 1080 Ti NVIDIA driver on Wayland rejects ALL custom display modes** (tested 2560x800 and even standard 2560x1080): `kscreen-doctor output.X.addCustomMode.W.H.mHz.reduced|full` registers the mode, but applying fails with "The driver rejected the output configuration". Don't burn time retrying.
- Workaround for custom game resolution: **gamescope** — Steam launch options `gamemoderun gamescope -w 2880 -h 900 -W 2560 -H 1440 -S fit -f -O HDMI-A-1 -- %command% -screen-width 2880 -screen-height 900`. Verified mechanics: `-f` not `-b` on KWin (borderless floats misplaced); pin `-O <connector>` or gamescope grabs the wrong monitor; **`-S fit` at effective scale 1.0 places the image top-left — force scale ≠ 1 (oversized nested res downscaled to fit) to get a centered symmetric letterbox**; Unity `-screen-width/-height` args are last-wins and beat launcher-injected values; in-game res dropdowns filter exotic aspects (cosmetic, don't Apply). Steam must be edited via its UI while running; editing localconfig.vdf under a live Steam gets clobbered on exit. Full pipeline + pitfalls: `references/gamescope-custom-game-resolutions.md`.
- `~/.config/kwinoutputconfig.json` `customModes` legacy schema (verified in KWin 6.7 source, outputconfigurationstore.cpp): `{"width":W,"height":H,"refreshRate":<mHz>,"flags":0}` — valid but only read at KWin startup, so live edits don't appear until re-login. Use `kscreen-doctor addCustomMode` for live injection instead.
- **EDID override WORKS on this stack** (proven 2026-08): dump `/sys/class/drm/card1-<output>/edid`, replace DTD1 (bytes 54-71) with the CVT timing for the wanted mode (build from `cvt` output; keep image-size bytes from original DTD), fix base checksum (byte 127 = `-sum(0..126) % 256`), leave extension blocks untouched, validate with `edid-decode`. Install to `/usr/lib/firmware/edid/x.bin`, add `drm.edid_firmware=<output>:edid/x.bin` to limine.conf cmdline, reboot. The mode becomes the panel's *preferred native mode* — NVIDIA accepts it, KWin auto-picks it, no gamescope needed. `video=<output>:WxH@R` cmdline does NOT work (nvidia-drm 580 ignores it; KWin stored config also re-applies at login). Full byte-level recipe: `references/nvidia-wayland-custom-modes.md`.
- **Albion Online custom-res wall**: its resolution list is HARDCODED in-game (filters exotic aspects; caps around 1366x768-1600x900) and its settings manager re-vets res mid-load, reverting exotic modes even when forced via prefs/launch args/EDID. The Qt launcher reads Unity PlayerPrefs (`~/.config/unity3d/Sandbox Interactive GmbH/Albion Online Client/prefs`, Screenmanager keys) and injects `-screen-width/-height` at spawn; the game rewrites prefs from its own list. Immutable prefs (`chattr +i`) is the only remaining lever after that — don't bother beyond it (anti-cheat risk on binary patches). Community verdict (Steam discussions, 2026): **21:9 (3440x1440) is officially supported** with wider FOV — only exotic aspects (32:9/32:10) get filtered. Sanctioned path to more width = EDID override at a 21:9 mode (e.g. 2560x1080), NOT 32:10. Windows cheaters force exotic res via windowed mode + window-resizer tools (SRWE); Linux analog = KWin window rule on the game window (untested, don't promise it).
- **Killing game/GUI processes from Hermes**: never `pkill -f "<pattern>"` when the pattern also appears in the invoking bash wrapper's own cmdline — it kills our own shell mid-command (hit twice in one session). List with `pgrep -f "patter[n]"` (bracket trick excludes self), then `kill <pid>` by exact PID.

## Lock Screen and Plasma Login

- KDE lock screen wallpaper: write `~/.config/kscreenlockerrc` with nested groups `Greeter → Wallpaper → org.kde.image → General`, keys `Image=file:///...` and `FillMode=2`.
- Detect the login manager with `systemctl status display-manager --no-pager` before choosing config paths. Plasma 6.7 on CachyOS uses `plasmalogin.service` (Plasma Login Manager), NOT SDDM — `pacman -Q sddm` returns nothing even when `/usr/share/sddm/themes/` still exists on disk. SDDM `theme.conf.user` edits (e.g. `font=`) are dead config.
- The plasmalogin greeter is a mini Plasma/Wayland session running as user `plasmalogin` (home `/var/lib/plasmalogin`). It reads its look from the greeter user's own KDE config:
  - **Wallpaper:** `/etc/plasmalogin.conf` + files under `/var/lib/plasmalogin/wallpapers/` (owned `plasmalogin:plasmalogin`). See `references/plasma-login-wallpaper.md`.
  - **Fonts/colors:** `/var/lib/plasmalogin/.config/kdeglobals` `[General]` font keys — write with `kwriteconfig6 --file <abs path>` (merges, safe). Greeter fonts must be system-wide (`/usr/local/share/fonts`, world-readable); the plasmalogin user cannot read `~/.local/share/fonts`. Verify with `sudo -u plasmalogin fc-match "<family>"`. Full recipe: `references/plasma-login-greeter-fonts.md`.
- GUI alternative: System Settings → Login Screen (Plasma Login Manager) → "Apply Plasma Settings" syncs the user's fonts/colors/wallpaper to the greeter account.

## Multi-GPU on Wayland + NVIDIA PRIME

On a hybrid Intel + NVIDIA box under KWin/Wayland, a monitor wired through the motherboard iGPU but rendered via NVIDIA causes a **per-frame GPU-to-GPU composition copy**. The symptom is exactly what you'd expect: positions desync between game state and rendered frame, producing player teleport/freeze while movement packets are actually reaching the server.

Fast diagnosis:
- Player position in-game freezes or snaps while inputs continue to register server-side.
- `nvidia-smi` shows strong GPU utilization, but `KWin Wayland` also shows abnormally high CPU.
- `ii`/inotify or frame presentation counters show stalls mid-frame.
- `Player.log` or equivalent shows `Could not fetch DPI` warnings for multiple outputs — a tell that KWin is splitting presentation across GPUs.

Fix priority:
1. Physically route the game monitor into the NVIDIA card. Single-GPU only.
2. If the monitor must stay on iGPU, drop NVIDIA render offload for that app; use iGPU windowing instead.
3. As a network-stability complement while you're in there, ensure only one default route exists for gaming traffic. On multi-homed machines, `ip route` may show both Ethernet and Wi-Fi default routes. Drop the Wi-Fi default so game traffic never races and reresolves: `sudo ip route del default via <gw> dev wlan0`.
4. For Albion specifically, permanent Steam launch options prevent the broken QtWeb launcher from spawning extra Chromium processes that bleed CPU/IO: `-no-browser -no-launcher +server loginserver.live.albion.zone:5055 +serverenvironment live`. Save via the actual `userdata/<steamid>/config/localconfig.vdf` `[UserLocalConfigStore][Software][Valve][Steam][apps][<appid>] LaunchOptions` — do not edit the app's compatdata.

## Plasma/KWin perf follow-ups after GPU swap
- Drop `qt.qpa.plugin` or any manual `QT_OPENGL` fallback hacks; let KWin handle presentation on the single active GPU.
- Confirm meaningful GPU memory stays under the single card (`nvidia-smi`) and `KWin Wayland` steady-state memory falls back to single-digit MiB.
- If fullscreen stutters persist, tune NVIDIA-specific compositor settings in KWin rather than trying Proton/Steam flags — native Linux titles do their own page-flip.

## Seeing the user's screen

- Capture the full desktop non-interactively (no GUI prompt, no focus steal): `spectacle -b -n -o /tmp/shot.png`. Multi-monitor setups produce one wide image (e.g. 4480x1440 for 2560+1920 side-by-side).
- If vision tooling is unavailable, analyze the PNG directly with PIL/numpy: coarse brightness grids locate dark terminal windows, and exact-hex color masks (e.g. fastfetch's `#FF00FF`/`#03EDF9`) measure where art vs text actually renders. Synthwave wallpapers pollute global color scans — find dark window rectangles first, then crop.
- When the task is cropping/compositing a SUBJECT from artwork (e.g. an icon from the lock-screen helmet), do not trust brightness alone: the brightest dome is usually the striped outrun sun, and dark subjects (black armor) need a stddev structure map. Verify the composition first with `session_search` on the image's origin session. Full workflow (ASCII mapping, background-subtraction cutout, gamma-lift, halo composite): `references/blind-image-cutout-and-compositing.md`.

## Icon swap pitfalls

- When replacing a Kickoff/panel icon, write the new image under a NEW filename and point the config at it. Overwriting the same path can leave Plasma serving the cached pixmap even after `plasmashell --replace`.

## Synthwave '84 deep-purple stewardship

Window chrome should use deep purple `#240037`, not `#0D0221`. If `kwriteconfig6` writes `#0D0221` to any Plasma/kwin color key, it will look wrong next to Kitty/Ghostty/OpenShark. Fix path: `references/synthwave84-deep-purple-drift.md`.

## Installing a locally-built app (freedesktop + icon association)

Reusable script: `templates/install-local-app.sh`.

Install layout (all user-owned, no sudo):
- Binary + data: `~/.local/share/<appname>/`
- Entry: `~/.local/share/applications/<appname>.desktop` (validate with `desktop-file-validate`)
- Icon: `~/.local/share/icons/hicolor/<size>/apps/<appname>.png` — the `Icon=` key references the basename, no path/extension
- Refresh: `update-desktop-database ~/.local/share/applications`, `kbuildsycoca6 --noincremental`, then `plasmashell --replace`

Icon association — how Plasma matches a running window to the .desktop entry:
- **Wayland-native apps:** desktop file name (minus .desktop) must equal the window's `app_id` (usually reverse-DNS).
- **SDL2/Odin games on Wayland (sdl2-compat → SDL3):** the app_id comes from SDL3's `SDL_APP_ID` hint. Setting it via SDL2's `SDL.SetHint("SDL_APP_ID", ...)` in code DOES propagate through sdl2-compat if called before `SDL.Init` (verified CachyOS). Fallback that always works: `Exec=env SDL_APP_ID=<desktop-id> ...` in the .desktop file. Without it, app_id won't match the desktop file → generic blank taskbar icon.
- **Reading a Wayland window's real app_id:** `xprop` only sees XWayland clients. Use a throwaway KWin script: JS iterating `workspace.windowList()` printing `w.resourceClass` / `w.desktopFileName`, load with `qdbus6 org.kde.KWin /Scripting org.kde.kwin.Scripting.loadScript /tmp/x.js <id>` + `.start`; output lands in `journalctl --user -b`. `desktopFileName` non-empty = KWin matched the window to its .desktop entry (verifies the whole association chain even when a fullscreen game hides the panel). Scripts run once — unload/reload to re-run. Note: `plasmashell --replace` can kill running SDL game windows; relaunch them after restarting Plasma.
- **X11/XWayland apps (JUCE 8 has NO Wayland backend — always XWayland):** matching is via `WM_CLASS` against the desktop file's `StartupWMClass=` key. JUCE sets WM_CLASS to the binary name, spaces included (e.g. `"Open Synth", "Open Synth"`), so write `StartupWMClass=Open Synth` — case-sensitive, keep the space.
- Diagnose: `xprop -root _NET_CLIENT_LIST` → `xprop -id <winid> WM_CLASS _NET_WM_NAME` (works for XWayland windows on a Wayland session).
- A window launched directly by path still associates via WM_CLASS/StartupWMClass — but only after ksycoca + plasmashell have refreshed since the desktop file was written.

Blank-icon differential diagnosis:
- **Blank tile in the SYSTEM TRAY (speaker/bell area):** that's a StatusNotifier item, not the taskbar — the app itself registered a tray icon with no image. Taskbar fixes won't touch it. JUCE apps don't create tray icons by default, so verify WHICH app the tile belongs to (hover tooltip) before assuming it's yours.
- **Blank tile in the taskbar:** WM_CLASS/StartupWMClass mismatch, icon basename missing from hicolor, or stale plasmashell association (restart plasmashell).
- **Pinned launcher showing old/no icon:** Plasma caches the icon at pin time — unpin and re-pin after fixing the desktop file.
