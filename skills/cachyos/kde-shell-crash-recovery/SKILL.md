---
name: kde-shell-crash-recovery
description: >-
  Fix crashed KDE Plasma shell; find the bad applet.
tags: [kde, plasma, crash, troubleshooting, linux]
---

# KDE Shell Crash Recovery

## Trigger Conditions
- KDE taskbar/panel frozen or not rendering
- `plasmashell --replace` crashes on startup (SIGABRT, core dump)
- Panel disappears after a background event (disconnect, notification flood, etc.)
- Plasma shell restarts but keeps dying in a loop

## Step 1 — Quick Restart

```bash
plasmashell --replace &
```

If it stays up, done. If it crashes immediately, proceed to diagnosis.

## Step 2 — Diagnose the Crash

```bash
# Check journal for the crash
journalctl --since "5 min ago" --no-pager | grep -iE "plasmashell|segfault|core dump|abort|assert|QML|TypeError" | tail -20

# Check coredumps
coredumpctl list plasmashell --since "10 min ago"
```

Key signals to look for:
- `TypeError: Value is null and could not be converted to an object` — QML null access, usually a specific applet
- `PopupDialog.qml:NN: TypeError` — the brightness/applet popup dialog is the culprit
- `No QSGTexture provided from updateSampledImage()` — harmless QtQuick warning, not the crash cause
- `Trying to replace notification with id NNN which doesn't exist` — notification bug, usually harmless

## Step 3 — Identify the Crashing Applet

The journal log usually names the QML file. Map it to the applet:

| QML file | Applet |
|---|---|
| `PopupDialog.qml` (brightness) | Power/brightness applet |
| `org.kde.plasma.brightness` | Brightness widget |
| `keyboard.qml` | On-screen keyboard |
| `systray.qml` | System tray |

If the QML file isn't obvious, check the applet config:

```bash
cat ~/.config/plasma-org.kde.plasma.desktop-appletsrc | grep -A5 -B5 "plugin="
```

Look for applets that match the QML file name pattern.

## Step 4 — Disable the Crashing Applet

```bash
# Find the applet containment
cat ~/.config/plasma-org.kde.plasma.desktop-appletsrc | grep -B10 "plugin=org.kde.plasma.brightness"
```

Remove or comment out the applet block in `plasma-org.kde.plasma.desktop-appletsrc`, then restart:

```bash
plasmashell --replace &
```

**Alternative**: If you can't edit the config (shell won't start), kill the applet process if it's a separate one, or temporarily rename the config:

```bash
mv ~/.config/plasma-org.kde.plasma.desktop-appletsrc ~/.config/plasma-org.kde.plasma.desktop-appletsrc.bak
plasmashell --replace &
```

This creates a default shell without the crashing applet. You can re-add applets one at a time afterward.

## Step 5 — Restore After the Workaround

Once the shell is stable:

1. Restore the original config: `mv ~/.config/plasma-org.kde.plasma.desktop-appletsrc.bak ~/.config/plasma-org.kde.plasma.desktop-appletsrc`
2. Restart: `plasmashell --replace &`
3. Remove the problematic applet via System Settings → Panels → Configure Panel → Remove Applet
4. Or replace it with a different applet that does the same thing

## Pitfalls

- **`plasmashell --replace` crashes in a loop**: Each restart dumps a core. Stop the loop before debugging — `pkill -9 plasmashell` (use exact pattern, not `-f` with game names).
- **QML TypeError location is the crash site, not necessarily the root cause**: The brightness PopupDialog.qml:96 TypeError is triggered by a null value from the power management backend — the applet is the victim, not the villain. If disabling it doesn't fix it, check `upower` or the AC adapter state.
- **Notification bugs in logs are noise**: "Trying to replace notification with id NNN which doesn't exist" comes from apps like Discord and is not a shell crash cause. Ignore unless it appears alongside the actual crash.
- **Fresh config loses your applet layout**: Renaming the config gives you a default shell. Your applet arrangement is gone — re-add manually afterward.
- **Shell crash during an active operation**: If the crash happened during a network operation (like a WiFi reconnect), finish the network fix first — a stable network and a crash-free shell are independent concerns.
- **Wayland sessions: `DISPLAY=:0` breaks `plasmashell --replace`**: On a Wayland-only session (KWin/Wayland, no Xwayland auth in the environment), launching `plasmashell --replace` with `export DISPLAY=:0` fails with "Authorization required, but no authorization protocol specified" and the shell exits immediately. The fix: do NOT set DISPLAY — launch `plasmashell --replace` directly so it inherits the Wayland compositor's environment (WAYLAND_DISPLAY, XDG_RUNTIME_DIR, DBUS_SESSION_BUS_ADDRESS). verify: `pgrep -a plasmashell` and `loginctl show-session $(loginctl | grep $(whoami) | awk '{print $1}') | grep State`.

## Related Skills

- `linux-wifi-troubleshooting` — when the shell crash was triggered by a WiFi disconnect event
