---
name: theme-audit
description: >
  Audit theme consistency across all CachyOS desktop layers.
version: 1.0.0
tags: [linux, cachyos, kde, plasma, theme, audit, desktop, consistency, firefox, chromium, alacritty, ghostty, opencode, fastfetch, cursor, wallpaper, gtk, kdeglobals]
---

# Theme Audit

System-wide theme consistency audit for CachyOS/KDE Plasma. When tasked with verifying that all customization layers match the theme repo, or when investigating a double-theme problem (two different themes active across different layers), run through every layer below.

## When to use

- User asks "does my system match the theme repo?" or "what themes are active?"
- User reports visual inconsistency across apps
- After running an install script, verify everything deployed correctly
- When a theme has two variants (e.g. Synthwave '84 vs Blackshield Mercenary) and you need to know which is where

## The audit layers (in priority order)

Run each check. For every layer, compare the **deployed** config against the **repo source** and note mismatches.

### 1. KDE Color Scheme (the anchor)

```bash
# Find active scheme hash
grep -oP 'ColorSchemeHash=\K[^\s]+' ~/.config/kdeglobals
# Match against repo schemes
for f in ~/Projects/active/cachyos-blackshield/configs/kde/color-schemes/*.colors; do
  hash=$(grep -oP 'ColorSchemeHash=\K[^\s]+' "$f")
  echo "$f -> $hash"
done
```

Read the active scheme's `[Colors:Window]`, `[Colors:Selection]`, `[General]` keys to confirm bg/fg/accent values.

### 2. KDE Look & Feel + Widget Style + Fonts

```bash
kreadconfig6 --group "General" --key "LookAndFeelPackage"
kreadconfig6 --group "KDE" --key "widgetStyle"
kreadconfig6 --group "General" --key "activeFont"
kreadconfig6 --group "General" --key "font"
kreadconfig6 --group "General" --key "cursor"
```

### 3. Icon + Cursor Themes

```bash
# Icon theme
kreadconfig6 --group "Icons" --key "theme"
ls ~/.local/share/icons/
ls ~/.icons/ 2>/dev/null

# Cursor (GTK-level)
grep gtk-cursor-theme-name ~/.config/gtk-3.0/settings.ini
grep gtk-cursor-theme-name ~/.config/gtk-4.0/settings.ini

# Verify cursor files are actually installed
ls ~/.local/share/icons/<cursor-theme>/cursors/ 2>/dev/null
```

**Pitfall:** cursor themes in the repo's `configs/icons/` are source files. They must be copied to `~/.local/share/icons/` or `~/.icons/` with a valid `index.theme` to be deployed. Having them in the repo alone does nothing.

### 4. GTK Settings

```bash
diff ~/.config/gtk-3.0/settings.ini ~/Projects/active/cachyos-blackshield/configs/kde/gtk-3.0-settings.ini
diff ~/.config/gtk-4.0/settings.ini ~/Projects/active/cachyos-blackshield/configs/kde/gtk-4.0-settings.ini
cat ~/.config/gtk-3.0/colors.css 2>/dev/null | head -20
cat ~/.config/gtk-4.0/colors.css 2>/dev/null | head -20
```

Watch for cursor name mismatch, font mismatch, color scheme mismatch between GTK and KDE.

### 5. Alacritty Terminal

```bash
diff ~/.config/alacritty/alacritty.toml ~/Projects/active/cachyos-blackshield/configs/alacritty/alacritty.toml
```

### 6. Ghostty Terminal (if installed)

```bash
diff ~/.config/ghostty/config.ghostty ~/Projects/active/cachyos-blackshield/configs/ghostty/config.ghostty
```

### 7. Opencode TUI Theme

```bash
cat ~/.config/opencode/tui.json
cat ~/.config/opencode/themes/synthwave-84.json
diff ~/.config/opencode/themes/synthwave-84.json ~/Projects/active/cachyos-blackshield/configs/opencode/themes/synthwave-84.json
```

### 8. KDE Wallpapers (per-monitor + lock screen)

```bash
grep -A5 "Image=" ~/.config/plasma-org.kde.plasma.desktop-appletsrc 2>/dev/null
grep -A5 "Image=" ~/.config/kscreenlockerrc 2>/dev/null
find ~/Projects/active/cachyos-blackshield/wallpapers -type f | sort
```

### 9. Fastfetch

```bash
diff ~/.config/fastfetch/config.jsonc ~/Projects/active/cachyos-blackshield/configs/fastfetch/config.jsonc
diff ~/.config/fastfetch/blackshield-shield.txt ~/Projects/active/cachyos-blackshield/configs/fastfetch/blackshield-shield.txt
```

### 10. Chromium/Chrome Theme

Chrome themes are **extensions**, not config files. A `manifest.json` in the repo does NOT mean it's installed.

```bash
# Active theme
python3 -c "
import json
with open('$HOME/.config/chromium/Default/Preferences') as f:
    d = json.load(f)
t = d.get('extensions',{}).get('theme',{})
print('Active theme:', t.get('id','none'), '|', t.get('name','none'))
"

# Installed extensions with names
python3 -c "
import json
with open('$HOME/.config/chromium/Default/Preferences') as f:
    d = json.load(f)
for eid, ed in d.get('extensions',{}).get('settings',{}).items():
    info = d.get('extensions',{}).get('storage',{}).get('managed',{}).get(eid,{})
    name = info.get('name','?')
    print(f'  {eid}: {name} (installed={ed.get(\"installed\", False)})')
"
```

**Deployment:** copy theme folder (manifest.json + assets) to `~/.local/share/chromium-themes/<name>/`, then load with `chromium --load-extension=/path/to/theme`. For permanent install, pack as CRX or use enterprise policy.

### 11. Firefox Theme (userChrome.css + userContent.css)

Deployed per-profile, not globally.

```bash
# Find active profile chrome dir
ls ~/.mozilla/firefox/*.default*/chrome/ 2>/dev/null

# Compare deployed vs repo
diff ~/.mozilla/firefox/*.default*/chrome/userChrome.css ~/Projects/active/cachyos-blackshield/configs/browsers/firefox/chrome/userChrome.css
diff ~/.mozilla/firefox/*.default*/chrome/userContent.css ~/Projects/active/cachyos-blackshield/configs/browsers/firefox/chrome/userContent.css
diff ~/.mozilla/firefox/*.default*/chrome/ntp_background.png ~/Projects/active/cachyos-blackshield/configs/browsers/firefox/chrome/ntp_background.png

# Verify user.js enables legacy stylesheets
cat ~/.mozilla/firefox/*.default*/user.js 2>/dev/null | grep legacyUserProfileCustomizations
```

**Deployment:** copy `userChrome.css`, `userContent.css`, `ntp_background.png` into `~/.mozilla/firefox/<profile>/chrome/`. Ensure `user.js` with `toolkit.legacyUserProfileCustomizations.stylesheets=true` is in the profile root. Restart Firefox for changes to apply.

**Pitfall:** Firefox profile chrome files can be edited by Firefox itself or a previous session. Always diff against the repo source.

### 12. Fish Shell

```bash
diff ~/.config/fish/config.fish ~/Projects/active/cachyos-blackshield/configs/fish/config.fish
diff -r ~/.config/fish/functions/ ~/Projects/active/cachyos-blackshield/configs/fish/functions/ 2>/dev/null
```

### 13. Micro Editor (if used)

```bash
diff ~/.config/micro/settings.json ~/Projects/active/cachyos-blackshield/configs/micro/settings.json 2>/dev/null
```

### 14. Plymouth + Limine (boot chain)

```bash
cat /etc/plymouth/plymouthd.conf
grep SetBackground /usr/share/plymouth/themes/*/*.script 2>/dev/null
cat /etc/default/limine | grep -i cmdline
```

See the `system-design` skill for full Plymouth/Limine/SDDM recipes.

### 15. Cursor Theme Evaluation

When evaluating new cursor themes from gnome-look or GitHub:
- Clone depth-1 for speed
- Check for `index.theme` and cursor directory structure
- Verify the theme name matches what GTK/KDE will reference
- Clean up after evaluating

```bash
git clone --depth 1 https://github.com/Grief/hand-of-evil
git clone --depth 1 https://github.com/EmperorPenguin18/SkyrimCursor
# Inspect, then install or discard
```

## Summary table

After auditing, fill in:

| Layer | Active | Repo source | Match? | Notes |
|-------|--------|-------------|--------|-------|
| KDE color scheme | | | | |
| KDE L&F | | | | |
| Icon theme | | | | |
| Cursor (GTK) | | | | |
| Alacritty | | | | |
| Ghostty | | | | |
| Opencode | | | | |
| Wallpaper primary | | | | |
| Wallpaper secondary | | | | |
| Lock screen | | | | |
| Fastfetch | | | | |
| Chromium theme | | | | |
| Firefox chrome | | | | |
| Firefox content | | | | |
| GTK-3.0 | | | | |
| GTK-4.0 | | | | |
| Fish | | | | |
| Micro | | | | |
| Plymouth | | | | |
| Limine | | | | |

## Common drift patterns

- **Firefox profile chrome files edited by Firefox** — always diff, don't assume.
- **Cursor themes in repo but not installed** — `configs/icons/` is source; `~/.local/share/icons/` is deployed.
- **Chrome themes as manifest.json only** — not installed until loaded as an extension.
- **GTK cursor name vs KDE cursor name** — they can differ. GTK uses `gtk-cursor-theme-name`; KDE uses the icon theme's cursor dir.
- **Font drift** — GTK may use a different font than KDE/Alacritty.
- **Two-theme problem** — one theme on KDE (Blackshield), another on terminals/Firefox (Synthwave '84). Both can coexist. Audit reveals the split.
- **Sync-direction clobbering (verified 2026-08-21):** when a diff shows live vs repo drift, decide which side is canonical BEFORE copying — grep the disputed key on BOTH sides first. In `diff A B`, `<` lines are file A; misread the direction and copy the wrong way and you destroy the good file (live opencode `blackshield.json` held the correct `blood`/`ember` values while the repo held stale `plum` — copying repo→live erased the fix and it had to be hand-restored). When in doubt, back up the target before overwriting.

## Audit-ingested agent work (when a theme overhaul agent left dirty state)

When an agent has been running a theme conversion and left modified + untracked files, the audit must go beyond pairwise diff and verify the conversion is *complete and internally consistent*. Run these checks in addition to the layers above:

### 1. Duplicate file groups
If the same logical file was written to two paths under the repo (e.g. both `configs/nvim/colors/blackshield.lua` and `configs/nvim/lua/colors/blackshield.lua`), one is dead weight. Check which path the consuming config actually references, remove the unreferenced duplicate, and note it.

### 2. Orphaned old-theme directories
A clean conversion removes the old theme's directories from the repo (e.g. `configs/plymouth/synthwave84/`, `wallpapers/synthwave/`, `configs/icons/Synthwave/`, `configs/browsers/chromium/synthwave84/`). If they still exist alongside the new theme, the agent did a copy-modify, not a replace — flag for cleanup or explicit decision to keep both.

### 3. Truncated or partial file edits
When `git diff` output cuts off mid-file (common when a file is large), re-read the live file and the repo file fully and compare section by section rather than trusting the truncated diff. Pay special attention to:
- config keybind/key lines at the end of terminal configs (often truncated)
- install.sh phase functions — a truncated `say` line is a strong signal the edit was incomplete
- handoff-post-reboot.sh deploy paths — verify every referenced file actually exists in the repo

### 4. Missing files referenced by new configs / scripts
A new theme's install.sh or handoff-post-reboot.sh will reference files that must exist in the repo for a fresh install to work. Check every path the scripts reference:
```
# Example: handoff-post-reboot.sh references these — verify they exist
configs/limine/limine-splash-blackshield.png
configs/limine/limine-splash-blackshield-1440.png
wallpapers/blackshield-lock-login/blackshield-2560x1440.png
configs/plymouth/blackshield/ (dir)
```
Missing referenced files = fresh-install break. Add them or fix the reference.

### 5. Browser theme deployment gap
A repo `configs/browsers/chromium/<theme>/manifest.json` does NOT mean the theme is installed. Same for Firefox `userChrome.css` — it must be in the live Firefox profile's `chrome/` dir, and `user.js` must enable `toolkit.legacyUserProfileCustomizations.stylesheets`. Check both repo presence AND live deployment.

### 6. Install script completeness
When an agent rewrites `install.sh` for a new theme, verify:
- every new config dir is listed in the copy phase
- every new wallpaper/cursor/theme dir is referenced
- the phase banner text matches the new theme name (not the old one)
- old theme paths are removed from the script if this is a replacement

### 7. New-file inventory
Get the full `git status` after the agent's work. New untracked files are as important as modified ones. Walk the new dirs and confirm each has the files the consuming config expects — a `blackshield/` theme dir with only `manifest.json` but no `ntp_background.png` is an incomplete artifact.

### 8. Internal palette consistency
After a palette conversion, spot-check that the same hex values appear across all converted configs. A conversion that got `#C1121F` into KDE but left `#240037` in one terminal config is a partial conversion, not a different theme choice.

## Summary table

## Process monitoring during long theme operations

When running a theme overhaul that takes a long time (30+ minutes, high CPU), use process inspection to understand what's happening:

```bash
# Check what the process is doing right now
cat /proc/<PID>/cmdline | tr '\0' ' '
cat /proc/<PID>/status | head -10
ls -la /proc/<PID>/fd | grep -v 'pipe\|socket\|anon'  # real files open
cat /proc/<PID>/stat | awk '{print "utime:", $14, "stime:", $15}'  # CPU time burned

# Check recent log activity
tail -100 ~/.local/share/opencode/log/opencode.log | grep -E "step=|evaluated|touching|editing" | tail -20
```

Watch for: which files are being touched/edited, which step the agent is on, whether it's browsing the web or doing local work.

## Ingested agent work — worked example

See [references/agent-conversion-audit-example.md](references/agent-conversion-audit-example.md) for the full Blackshield conversion audit from 2026-08-21: scope of changes, 7 findings (duplicate files, orphaned dirs, truncated edits, deployment gaps), and the step-by-step audit that surfaced each one.
