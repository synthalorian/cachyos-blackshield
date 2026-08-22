# Chromium Extension-Theme Precedence (recurring failure)

## Symptom
Chromium renders stock/default (white Google NTP, light frame, "Customize Chromium" banner) even though `browser.theme.theme_id` and all `browser.theme.colors` in `~/.config/chromium/Default/Preferences` are correctly set to the custom theme.

## Root cause
`extensions.theme` in Preferences takes precedence over `browser.theme`. Two observed forms:

1. `{"id": "<extension-id>"}` — an installed theme extension wins outright over `browser.theme`.
2. `{"system_theme": 2}` — "use system theme" mode; silently overrides `browser.theme.colors`.

A third resurrection vector: a theme extension removed from disk can leave a stale entry in `extensions.settings.<id>` that re-registers the theme on next launch. Observed with the old synthwave84 theme id `jldjkdpijjmjblabpffijofppkalmkdd` returning after deletion.

## Fix recipe (do ALL steps, in order)

1. **Kill Chromium fully** — `pkill -TERM chromium`, confirm with `pgrep`. Chromium overwrites Preferences on exit, so editing while it runs loses your changes.
2. **Edit Preferences:**
   - Delete `extensions.theme` entirely.
   - Delete the stale `extensions.settings.<theme-ext-id>` entry.
   - Set `browser.theme.theme_id = "<your-theme-id>"` and `browser.theme.follows_system_colors = false`.
3. **Purge on-disk leftovers:** `rm -rf ~/.config/chromium-themes/<old-theme>/` and `~/.config/chromium/Default/Extensions/<old-id>/`.
4. **Relaunch** with the GUI session env (see below).
5. **Verify after relaunch** — re-read Preferences and confirm `extensions.theme` did not return. Chromium can re-add `system_theme` on some launches; if it does, repeat step 2.

## GUI relaunch env (Wayland/KDE)
Terminal-launched GUI apps fail with "no DISPLAY" unless you export the session env harvested from the running shell:

```bash
export DISPLAY=:0 WAYLAND_DISPLAY=wayland-0 \
  DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus \
  XAUTHORITY=$(cat /proc/$(pgrep -x plasmashell | head -1)/environ | tr '\0' '\n' | grep ^XAUTHORITY= | cut -d= -f2-)
chromium &
```

## History
- 2026-08-21: fixed twice in one day. First removal of `extensions.theme` + synthwave84 dir didn't stick because the `extensions.settings` entry resurrected it. Second pass removed the settings entry too. User explicitly asked to "apply the same fix we used" — captured here so it's not tribal knowledge.
