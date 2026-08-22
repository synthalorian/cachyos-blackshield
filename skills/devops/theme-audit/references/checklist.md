# Theme Audit Checklist — Detailed Commands

Run this when verifying that every customization layer on a CachyOS system matches the theme repo (`~/Projects/active/cachyos-blackshield/` or equivalent). Covers all layers from KDE down to browser chrome.

## 1. KDE Color Scheme (the anchor)

```bash
# Find which scheme is active
grep -oP 'ColorSchemeHash=\K[^\s]+' ~/.config/kdeglobals
# Match against repo schemes
for f in ~/Projects/active/cachyos-blackshield/configs/kde/color-schemes/*.colors; do
  hash=$(grep -oP 'ColorSchemeHash=\K[^\s]+' "$f")
  echo "$f -> $hash"
done
```

Also read the active scheme's `[Colors:Window]`, `[Colors:Selection]`, and `[General]` keys to confirm bg/fg/accent values.

## 2. KDE Look & Feel + Widget Style

```bash
kreadconfig6 --group "General" --key "LookAndFeelPackage"
kreadconfig6 --group "KDE" --key "widgetStyle"
kreadconfig6 --group "General" --key "activeFont"
kreadconfig6 --group "General" --key "font"
```

## 3. Icon + Cursor Themes

```bash
# Icon theme
kreadconfig6 --group "Icons" --key "theme"
ls ~/.local/share/icons/
ls ~/.icons/ 2>/dev/null

# Cursor theme (GTK-level)
grep gtk-cursor-theme-name ~/.config/gtk-3.0/settings.ini
grep gtk-cursor-theme-name ~/.config/gtk-4.0/settings.ini

# Check cursor files are actually installed
ls ~/.local/share/icons/<cursor-theme>/cursors/ 2>/dev/null
```

**Deployment gap to watch:** cursor themes must be installed in `~/.local/share/icons/` or `~/.icons/` with an `index.theme` — having them in the repo's `configs/icons/` is not enough. The install script must copy them into the icons dir and update the GTK/KDE cursor setting.

## 4. GTK Settings (GNOME app compatibility)

```bash
diff ~/.config/gtk-3.0/settings.ini ~/Projects/active/cachyos-blackshield/configs/kde/gtk-3.0-settings.ini
diff ~/.config/gtk-4.0/settings.ini ~/Projects/active/cachyos-blackshield/configs/kde/gtk-4.0-settings.ini
cat ~/.config/gtk-3.0/colors.css 2>/dev/null | head -20
cat ~/.config/gtk-4.0/colors.css 2>/dev/null | head -20
```

Watch for: cursor theme name mismatch, font mismatch, color scheme mismatch.

## 5. Terminal — Alacritty

```bash
diff ~/.config/alacritty/alacritty.toml ~/Projects/active/cachyos-blackshield/configs/alacritty/alacritty.toml
```

## 6. Terminal — Ghostty (if installed)

```bash
diff ~/.config/ghostty/config.ghostty ~/Projects/active/cachyos-blackshield/configs/ghostty/config.ghostty
```

## 7. Opencode TUI Theme

```bash
cat ~/.config/opencode/tui.json          # shows which theme is selected
cat ~/.config/opencode/themes/synthwave-84.json   # the actual theme file
diff ~/.config/opencode/themes/synthwave-84.json ~/Projects/active/cachyos-blackshield/configs/opencode/themes/synthwave-84.json
```

## 8. Wallpapers (KDE per-monitor + lock screen)

```bash
# Check KDE wallpaper config
grep -A5 "Image=" ~/.config/plasma-org.kde.plasma.desktop-appletsrc 2>/dev/null
grep -A5 "Image=" ~/.config/kscreenlockerrc 2>/dev/null

# Check repo wallpapers exist
find ~/Projects/active/cachyos-blackshield/wallpapers -type f | sort
```

## 9. Fastfetch

```bash
diff ~/.config/fastfetch/config.jsonc ~/Projects/active/cachyos-blackshield/configs/fastfetch/config.jsonc
diff ~/.config/fastfetch/blackshield-shield.txt ~/Projects/active/cachyos-blackshield/configs/fastfetch/blackshield-shield.txt
```

## 10. Chromium/Chrome Theme (extension-based)

Chrome themes are **Chrome extensions**, not config files. Having a `manifest.json` in the repo does NOT install it.

```bash
# Check which theme is actually active
python3 -c "
import json
with open('$HOME/.config/chromium/Default/Preferences') as f:
    d = json.load(f)
t = d.get('extensions',{}).get('theme',{})
print('Active theme:', t.get('id','none'), '|', t.get('name','none'))
"

# List installed extensions to find theme extension IDs
python3 -c "
import json, os
with open('$HOME/.config/chromium/Default/Preferences') as f:
    d = json.load(f)
for eid, ed in d.get('extensions',{}).get('settings',{}).items():
    info = d.get('extensions',{}).get('storage',{}).get('managed',{}).get(eid,{})
    name = info.get('name','?')
    print(f'  {eid}: {name} (installed={ed.get(\"installed\", False)})')
"
```

**Deployment:** to install a repo theme into Chromium:
1. Copy the theme dir (manifest.json + assets) to a temp location
2. Load as unpacked extension: `chromium --load-extension=/path/to/theme` (one-time), OR
3. Package as a `.crx` and install via Chrome Web Store or enterprise policy, OR
4. Use the `chrome.management` / `chrome.theme` API in an existing extension

The simplest path for a personal machine: copy the theme folder to `~/.local/share/chromium-themes/<name>/`, then load with `chromium --load-extension=...` and pin it. For a permanent install, use `chrome-theme.json`-based enterprise policy or pack as a CRX.

## 11. Firefox Theme (userChrome.css + userContent.css)

Firefox themes via CSS are deployed per-profile, not globally.

```bash
# Find the active profile
ls ~/.mozilla/firefox/*.default*/chrome/ 2>/dev/null

# Compare deployed vs repo
diff ~/.mozilla/firefox/*.default*/chrome/userChrome.css ~/Projects/active/cachyos-blackshield/configs/browsers/firefox/chrome/userChrome.css
diff ~/.mozilla/firefox/*.default*/chrome/userContent.css ~/Projects/active/cachyos-blackshield/configs/browsers/firefox/chrome/userContent.css
diff ~/.mozilla/firefox/*.default*/chrome/ntp_background.png ~/Projects/active/cachyos-blackshield/configs/browsers/firefox/chrome/ntp_background.png

# Verify user.js is deployed (enables legacy stylesheets)
cat ~/.mozilla/firefox/*.default*/user.js 2>/dev/null | grep legacyUserProfileCustomizations
```

**Deployment:** copy `userChrome.css`, `userContent.css`, `ntp_background.png` into `~/.mozilla/firefox/<profile>/chrome/`, and ensure `user.js` with `toolkit.legacyUserProfileCustomizations.stylesheets=true` is in the profile root. The `user.js` prefs are applied on Firefox restart.

**Watch for drift:** Firefox profile files can be edited by Firefox itself or by a previous session. Always diff against the repo source before assuming they match.

## 12. Fish Shell

```bash
diff ~/.config/fish/config.fish ~/Projects/active/cachyos-blackshield/configs/fish/config.fish
diff -r ~/.config/fish/functions/ ~/Projects/active/cachyos-blackshield/configs/fish/functions/ 2>/dev/null
```

## 13. Micro editor (if used)

```bash
diff ~/.config/micro/settings.json ~/Projects/active/cachyos-blackshield/configs/micro/settings.json 2>/dev/null
```

## 14. Plymouth + Limine (boot chain)

```bash
# Plymouth active theme
cat /etc/plymouth/plymouthd.conf
grep SetBackground /usr/share/plymouth/themes/*/pinsh-script.plymouthscript 2>/dev/null

# Limine config
cat /etc/default/limine | grep -i cmdline
cat /boot/limine.conf | grep -A5 "comment: machine-id"
```

See `system-design` skill for full Plymouth/Limine/SDDM theming recipes.

## 15. Cursor theme packages (AUR/community)

When evaluating new cursor themes from gnome-look or GitHub:
- Check PKGBUILD for install paths
- Check for `index.theme` and cursor directory structure
- Verify the theme name matches what GTK/KDE will reference
- Clone depth-1 for speed; clean up after evaluating

Example (from a real session):
```bash
git clone --depth 1 https://github.com/Grief/hand-of-evil
git clone --depth 1 https://github.com/EmperorPenguin18/SkyrimCursor
# Inspect structure, then install or discard
```

## Summary table template

After running the audit, fill in:

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
- **Font drift** — GTK may use a different font than KDE/Alacritty. Check both GTK settings.ini files.
