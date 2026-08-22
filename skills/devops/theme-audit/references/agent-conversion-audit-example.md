# Agent-Driven Theme Conversion Audit — Worked Example (Blackshield, 2026-08-21)

## Context

OpenCode ran a full Synthwave '84 → Blackshield Mercenary conversion on the
`cachyos-blackshield` repo and left 23 modified files + 16 new file groups
untracked/uncommitted. This document records what the conversion covered, what
it missed, and the audit steps that surfaced each gap.

## Conversion scope (what OpenCode did)

### Modified in place (23 files)

- **README.md** — theme name, phase table, palette description, "Tonight's
  additions" → "The Blackshield conversion"
- **install.sh** — color vars, `say`/`ok`/`warn` colors, phase banners,
  icon/font/wallpaper copy paths, browser phase text
- **handoff-post-reboot.sh** — echo banner, limine splash paths, plymouth theme
  name, plasmalogin wallpaper path, closing line
- **configs/alacritty/alacritty.toml** — full palette swap, font 3270→Canterbury,
  size 11→13, opacity 0.92→0.94, title "synthwave"→"blackshield", cursor/
  selection/search colors
- **configs/ghostty/config.ghostty** — palette, font (Canterbury + Symbols
  fallback), size 13, cursor/selection, removed keybinds section (truncated?)
- **configs/kitty/kitty.conf** — palette, font Canterbury + symbol_map, size 13,
  cursor, selection, tab bar, borders, 16-color palette
- **configs/kde/kdeglobals** — full color scheme swap (Blackshield.colors)
- **configs/kde/kwinrc** — active/inactive colors
- **configs/kde/kcminputrc** — cursorTheme=Blackshield
- **configs/kde/gtk-3.0-settings.ini**, **gtk-4.0-settings.ini** — cursor
  Blackshield, font Canterbury 11
- **configs/fastfetch/config.jsonc** — logo source cross.txt→blackshield-shield.txt,
  colors, key colors, separator string longer by one char
- **configs/limine/limine.conf** — branding text, palette, wallpaper, term colors
- **configs/system/plasmalogin-greeter-kdeglobals** — full color scheme swap
- **configs/system/plasmalogin.conf** — wallpaper path
- **configs/opencode/tui.json** — theme "synthwave-84"→"blackshield"
- **configs/nvim/lua/plugins/colorscheme.lua** — switched from lunarvim/synthwave84
  to local `colors.blackshield` module
- **configs/browsers/firefox/chrome/userChrome.css** — full palette + var rename
  (sw84→bs), 301-line file
- **configs/browsers/firefox/chrome/userContent.css** — same treatment, 165-line
  file
- **configs/browsers/firefox/chrome/ntp_background.png** — swapped image
- **configs/plasmoids/AndromedaLauncher/contents/config/main.xml** — indicatorColor
- **configs/plasmoids/AndromedaLauncher/contents/ui/MainView.qml** — glowColor1/2
- **configs/plasmoids/AndromedaLauncher/contents/ui/UserAvatar.qml** —
  borderGradientColor1/2/3

### New file groups (16)

- `configs/nvim/colors/blackshield.lua` + `configs/nvim/lua/colors/blackshield.lua`
  (duplicate — see findings)
- `configs/kde/color-schemes/Blackshield.colors`
- `configs/kde/desktoptheme/Blackshield/` (colors, dialogs, icons, metadata.desktop,
  widgets)
- `configs/icons/Blackshield/` (cursors/, index.theme)
- `configs/icons/candidates/hand-of-evil/`
- `configs/plymouth/blackshield/` (background.png, blackshield.plymouth,
  blackshield.script, dot.png)
- `configs/limine/limine-splash-blackshield.png`
- `configs/limine/limine-splash-blackshield-1440.png`
- `configs/browsers/chromium/blackshield/` (manifest.json, ntp_background.png)
- `configs/opencode/themes/blackshield.json`
- `configs/fastfetch/blackshield-shield.txt`
- `wallpapers/blackshield/` (4 images)
- `wallpapers/blackshield-lock-login/` (2 images)
- `skills/cachyos/terminal-theming/templates/alacritty-blackshield.toml`
- `skills/cachyos/terminal-theming/templates/ghostty-blackshield.ghostty`

## Findings: what was incomplete or wrong

### 1. Duplicate nvim colorscheme module

Both `configs/nvim/colors/blackshield.lua` and `configs/nvim/lua/colors/blackshield.lua`
exist. The colorscheme.lua plugin references `vim.fn.stdpath("config")` + `colors.blackshield`,
which resolves to `lua/colors/`. The `colors/` copy is dead weight — remove it.

### 2. Orphaned old-theme directories still in repo

These were not removed — they coexist with the new Blackshield dirs:

- `configs/plymouth/synthwave84/`
- `wallpapers/synthwave/`
- `wallpapers/synthwave84-lock-login/`
- `configs/icons/Synthwave/`
- `configs/browsers/chromium/synthwave84/`

This is a copy-modify, not a replace. Decision needed: delete or keep both.

### 3. Ghostty config may be truncated

The `git diff` output for `configs/ghostty/config.ghostty` cut off after the
palette lines — the keybinds section from the original was removed and nothing
replaced it. Verify the live file has all needed keybinds; if not, restore them.

### 4. install.sh `phase_browsers()` possibly truncated

The diff output cut off mid-function at the `say` line. Read the full file to
confirm the function is complete and the Chromium manual-load step is still
documented (the old synthwave84 phase had a `docs/BROWSERS.md` reference).

### 5. Missing referenced files (fresh-install breaks)

The new `handoff-post-reboot.sh` references these paths — verify each exists
in the repo:

- `configs/limine/limine-splash-blackshield.png` ✅
- `configs/limine/limine-splash-blackshield-1440.png` ✅
- `wallpapers/blackshield-lock-login/blackshield-2560x1440.png` ✅
- `configs/plymouth/blackshield/` ✅ (dir with 4 files)

All four checked out, but this step must be repeated for any future conversion.

### 6. Browser theme deployment gap

The new `configs/browsers/chromium/blackshield/manifest.json` exists in the repo
but is **not installed** as a Chrome extension. The Firefox `userChrome.css` was
converted in the repo but the live profile still has the old Synthwave '84 version
(deployed earlier). Both need deployment verification separate from repo presence.

### 7. Old README content not fully scrubbed

The "Tonight's additions" section was replaced with "The Blackshield conversion",
but spot-check for any leftover Synthwave '84 references in tables or phase
descriptions that didn't get caught.

## Audit steps that surfaced these

1. `git diff --stat` → saw 23 modified + untracked files
2. Read each modified file's diff (full, not truncated) → caught truncation
3. `git status` → full untracked inventory
4. `test -f`/`test -d` for every path referenced by new scripts → verified
   referenced files exist
5. `diff` live vs repo for Firefox chrome, GTK settings, etc. → caught
   deployment gaps
6. `ls` each new directory → confirmed contents, caught duplicate nvim module
7. Checked for old theme dirs still present → caught orphaned directories

## Takeaways for future audits

- Always read the **full** diff of large files; don't trust truncated output.
- `git status` untracked files are as important as modified ones.
- After a palette conversion, spot-check that the same hex values appear across
  all converted configs (KDE, terminals, fastfetch, browsers).
- A conversion that changes KDE to #C1121F but leaves one terminal at #240037
  is a partial conversion, not a deliberate dual-theme choice.
- Browser themes require separate deployment verification — repo presence ≠
  installed.
