---
name: cachyos-site-config
description: Site-specific config patterns for synth's CachyOS machine.
version: 1.0.0
tags: [linux, cachyos, limine, fish, boot]
---

# CachyOS Site Config Patterns

Patterns encoded from real debugging sessions on this machine.

## Limine Bootloader Theming

Canonical config: `cachyos-blackshield/configs/limine/limine.conf`. Deployed to `/boot/` via handoff script.

### Pitfalls
1. **Malformed hex kills readability:** stray prefix on `term_*` hex values (e.g. `E6240037` instead of `240037`) causes invalid-color overlay crowding branding text. Always validate 6 hex chars exactly.
2. **Splash + terminal overlay:** when `wallpaper` is set, Limine still renders terminal overlay on top. Pick `term_foreground` carefully: cyan `#03EDF9` or white `#FFFFFF` work on dark art; hot pink `#FF7EDB` usually fails.
3. **Canonical source is cachyos-blackshield:** editing `/boot/limine.conf` directly won't survive reboot. Use handoff.
4. **Kernel updates drop custom cmdline params:** `limine-entry-tool` regenerates ONE active entry on every kernel bump, silently dropping manually-added params like `drm.edid_firmware` (the SKG 2560x1080 ultrawide override) — while OTHER active entries (e.g. LTS) keep theirs. Symptom: monitor falls back to native EDID after a `pacman -Syu` kernel bump + reboot even though the param is still visible somewhere in limine.conf. Fix: re-run `~/Projects/active/this-is-the-wide/scripts/install.sh`, then reboot. Verify what the BOOTED kernel got: `grep drm.edid_firmware /proc/cmdline`.
5. **Param checks must be per-line, never any-match:** old snapshot entries AND stale active entries retain historical params forever. Any idempotency check or sed must evaluate every line containing `rootflags=subvol=/@ root=` (excluding `/@/.snapshots/`) individually. Bug hit 2026-08-11 (7.1.6→7.1.8): install.sh's old "any active line has the param → skip everything" grep saw the surviving param on the stale entry and skipped the regenerated entry the machine actually booted. Fixed in this-is-the-wide commit `5be38d4` — the script now seds every active line missing the param and is verified idempotent ("already present in all active entries").

## EDID Override (this-is-the-wide)

Forged EDID `skg-2560x1080.bin` lives in `~/Projects/active/this-is-the-wide/edid/`, installed to `/usr/lib/firmware/edid/` and wired via kernel param `drm.edid_firmware=HDMI-A-1:edid/skg-2560x1080.bin` on the active Limine entries. Re-apply after kernel updates (pitfall #4). Verify after boot: `edid-decode /sys/class/drm/card1-HDMI-A-1/edid | grep 'DTD 1'` should show 2560x1080 as preferred. `scripts/revert.sh` in that repo removes it.

### Verified Synthwave '84 Config
```
term_palette: 240037;FE4450;72F1B8;F3E70F;8F00FF;FF00FF;03EDF9;FF7EDB
term_background: 240037
term_foreground: 03EDF9
interface_branding_colour: FFFFFF
interface_help_colour: B084EB
wallpaper: boot():/limine-splash-synthwave.png
```

## Multi-monitor: cua-driver only sees the primary display

This box runs TWO monitors: HDMI-A-1 (primary) and HDMI-A-2 (secondary, where
Discord/Hermes/Firefox/Chromium windows usually live). cua-driver's
`list_windows` / `capture` enumerate ONLY primary-display windows — windows on
HDMI-A-2 return "no on-screen window matched" even when alive and unminimized.
Verified diagnostic when computer_use can't find a window: KWin scripting via
qdbus6 (`references/kwin-window-enumeration.md`) — `workspace.windowList()`
reports every window with resourceClass, caption, frameGeometry, output name.

## cua-driver on pure Wayland: enable the experimental backend

Symptom: every `computer_use` capture returns 0x0 with an empty element list and
`list_windows` shows nothing, on any app. `hermes computer-use doctor` reports
`ax_capability: X11 is not reachable` + `wayland_backend: experimental backend is opt-in`.
Fix (applied 2026-08-11): drop-in `~/.config/systemd/user/hermes-gateway.service.d/wayland-cua.conf`
with `Environment="CUA_DRIVER_RS_ENABLE_WAYLAND=1"`, then `daemon-reload` + restart
`hermes-gateway`. NOTE: restarting the gateway kills the running agent session —
hand the restart command to the user, don't fire it mid-conversation. Wayland capture
uses PipeWire/screen-copy (ScreenCast family), NOT the portal Screenshot interface —
so it is unaffected by the portal muzzle below.

## xdg-desktop-portal Screenshot muzzle (Spectacle popping at login)

Symptom: Spectacle's interactive capture window opens at every login with no keypress,
user has to cancel it. Cause (verified 2026-08-11): a background app — Discord, via its
game-detection/Clips subsystem probing screen capture at startup — calls the portal
`org.freedesktop.portal.Screenshot` API, and xdg-desktop-portal-kde answers Screenshot
requests by LAUNCHING Spectacle interactively. Journal tell: `Starting Spectacle
screenshot capture utility...` seconds after Discord/portal start. (Albion Companion
and KDE Connect were checked and exonerated; dbus eavesdropping is disabled on
dbus-broker so caller tracing via dbus-monitor doesn't work — correlate by timing.)

Fix: `~/.config/xdg-desktop-portal/portals.conf`:

```
[preferred]
default=kde;gtk
org.freedesktop.impl.portal.Screenshot=none
```

then `systemctl --user restart xdg-desktop-portal` (the -kde backend is D-Bus-activated
on demand — there is no persistent `xdg-desktop-portal-kde.service` to restart).
Smoke test: `busctl --user --timeout=5 call org.freedesktop.portal.Desktop
/org/freedesktop/portal/desktop org.freedesktop.portal.Screenshot Screenshot 'sa{sv}' '' 0`
must fail with `No such interface` and pop nothing. Spectacle via Print key / app menu
still works (direct launch, not portal). ScreenCast (Discord screenshare, OBS) is a
separate interface — untouched. Side effect: rare legitimate portal-screenshot callers
error out; revert = delete the conf + restart xdg-desktop-portal.

## Fish Function Library

Single-file-per-function in `~/.config/fish/functions/`. Handoff syncs from `cachyos-blackshield/configs/fish/functions/`.

**Edit workflow:** edit `.fish` in cachyos-blackshield, run handoff script. Never edit only in `~/.config/fish/functions/` — reboot clobbers it.

### Fish Quirks (this machine)
1. `alias ~='cd ~'` crashes on source — `~` conflicts with expansion token. Remove it.
2. `__fish_config_dir` is read-only in modern fish; use `XDG_CONFIG_HOME` instead.
3. Function names must be valid identifier tokens. `function ~` fails at source.
4. functions must be self-contained; don't assume another function file was sourced first.

## Browser Themes (configs/browsers/)

Firefox (userChrome/userContent/user.js per profile) + Chromium (unpacked theme at
`~/.config/chromium-themes/synthwave84`, manual Load unpacked — CLI installs blocked).
Deployed by install.sh `browsers` phase. Key pitfalls: Firefox 150+ headless never
seeds a profile (only `--headless -profile <tmp>` materializes installs.ini), and
installs.ini's install-hash Default beats profiles.ini `Default=1`. Full recipes +
CDP automation for chrome://extensions: [references/browser-themes.md](references/browser-themes.md).

## Handoff Script

Path: `~/Projects/active/handoff-post-reboot.sh`
Run: `sudo -E bash ~/Projects/active/handoff-post-reboot.sh` (`-E` preserves `$HOME=/home/synth`; plain `sudo bash` expands `~` to `/root`)

Sections: CPU governor, zram, Limine, Plymouth+plasmalogin, Fish functions, user services.

## Network Priority (synthesis)

- Onboard ethernet `enp0s31f6` = "Wired connection 1": `autoconnect=yes`, `autoconnect-priority=0`, route metric 100.
- Pixel USB tether = NM profile "USB Tether Priority": `match.driver=cdc_ncm,rndis_host,cdc_ether`, `autoconnect-priority=100`, route metric 50 so the phone wins when plugged in.
- Dead RTL8822BE WiFi stays buried: driver blacklist + udev bus-remove + `pcie_aspm=off`; keep `The Grid` at `autoconnect=no` and WiFi radio off to avoid pointless wireless retries.
- **USB tether dies after every pacman kernel upgrade until reboot:** the upgrade removes the RUNNING kernel's `/lib/modules/<ver>` tree, so `rndis_host` can't load (`modprobe rndis_host` → `FATAL: Module rndis_host not found`). Diagnostic signature (2026-08-11): phone enumerates as `18d1:4eec` (MTP), flips to `18d1:4ee7` (tether) for ~2s, then drops back to 4eec — no usb0 interface, no rndis/cdc modules in lsmod. Confirm with `uname -r` vs `pacman -Q linux-cachyos` vs `ls /lib/modules/`. Only fix: reboot into the new kernel. NM profiles need no changes; the tether self-heals once the module can load again.
