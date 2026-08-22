# System-Wide Font Swap Checklist (CachyOS / KDE Plasma 6)

Verified 2026-08-11 during the 3270 Nerd Font → Orbitron swap. A "default font across
the board" change on this system touches MORE stores than obvious — missing one leaves
the old family rendering in some app class.

## Every location a default font can hide

| Store | Keys / lines | Apply method |
|---|---|---|
| `~/.config/kdeglobals` `[General]` | `font`, `fixed`, `smallestReadableFont`, `menuFont`, `toolBarFont` | `kwriteconfig6 --file kdeglobals --group General --key <k> "<qfont>"` |
| `~/.config/kdeglobals` `[General]` (legacy!) | `activeFont` — a straggler KDE keeps in General, NOT covered by setting `[WM]` | same, `--key activeFont` |
| `~/.config/kdeglobals` `[WM]` | `activeFont`, `inactiveFont` (window titles) | `kwriteconfig6 --group WM` |
| `~/.config/gtk-3.0/settings.ini`, `gtk-4.0/settings.ini` | `gtk-font-name=<Family> <size>` | direct edit |
| `~/.config/xsettingsd/xsettingsd.conf` | `Gtk/FontName "<Family> <size>"` | edit, then `pkill -HUP xsettingsd` for live reload |
| `~/.config/Trolltech.conf` | `font="<qfont>"` (Qt4-era apps) | direct edit |
| dconf (GNOME-side apps, even on KDE) | `org.gnome.desktop.interface font-name`, `monospace-font-name`, `document-font-name` | `gsettings set ...` — NEVER edit `~/.config/dconf/user` blob directly |
| Alacritty | `~/.config/alacritty/alacritty.toml` `[font.normal|bold|italic|bold_italic]` | direct edit; bold should use `style = "Bold"` when a real bold face exists |
| Kitty | `~/.config/kitty/kitty.conf` `font_family` / `bold_font` / `italic_font` / `bold_italic_font` | direct edit; `auto` lets kitty resolve bold/italic itself |
| Kitty (size tuning) | `font_size` in kitty.conf — display fonts often need a size drop (e.g. Medieval Sharp: 13 → 12) | direct edit |
| Alacritty (style name match) | `[font.normal|bold|italic|bold_italic] style = "..." ` — must match the font's actual style name (Medieval Sharp uses `"Book"`, not `"Regular"`) | direct edit; verify style names with `fc-query <file.ttf> | grep style` |
| GTK SVG assets | `~/.config/gtk-3.0/assets/*.svg`, `~/.config/gtk-4.0/assets/*.svg`, `~/.config/xsettingsd/*.svg` — some embed `font-family="<Family>"` in their CSS | `sed -i 's/<OldFamily>/<NewFamily>/g' *.svg` in each assets dir |
| dconf/gsettings (GNOME-side, even on KDE) | `org.gnome.desktop.interface font-name`, `monospace-font-name` | `gsettings set org.gnome.desktop.interface font-name "<Family> <size>"` — never edit `~/.config/dconf/user` blob directly |
| Ghostty | `~/.config/ghostty/config.ghostty` `font-family` | direct edit; verify with `ghostty +validate-config` |
| Konsole | `~/.local/share/konsole/*.profile` (if any) | check with grep — absent on this system 2026-08 |

Qt font string format: `Family,pointSize,-1,5,weight,0,0,0,0,0,0,0,0,0,0,1`
(weight: 400 = Regular, 700 = Bold).

## Discovery

```bash
grep -rln '<OldFamily>' ~/.config \
  | grep -vE 'gtk-3.0/assets|chromium|mozilla|discord|dconf/user'
```
Binary hits (browser caches, sqlite, dconf blob, app binaries) are history/cache noise —
the only stores that matter are the text configs above plus dconf-via-gsettings.

## fontconfig fallback wiring (symbol/glyph coverage for unpatched fonts)

- Per-family fallback: `<alias binding="strong"><family>X</family><accept><family>Symbols Nerd Font</family></accept></alias>` — inserts Symbols AFTER X in the resolution list.
- Generic last-resort: `<alias><family>monospace</family><default>...</default></alias>`.
- Do NOT deploy nerd-fonts' shipped `10-nerd-font-symbols.conf` — its `<prefer>` aliases
  insert Symbols BEFORE the requested family and can hijack generic monospace requests.
- Verify the chain: `fc-match -s '<Family>'` — expect Family first, Symbols second, then Noto/DejaVu.

## Verification pitfalls

- `fc-match 'Family:charset=E005'` does NOT hard-filter on charset — it returns the best
  family match even when the font lacks the glyph. Useless as coverage proof.
- Coverage proof: `fc-list ':charset=E005' family` (which fonts actually have PUA glyphs).
- Instancing weights from a variable font: `fonttools varLib.instancer VF.ttf wght=<w>
  --update-name-table -o out.ttf`. Without `--update-name-table` every instance reports
  `style=Regular` and bold selection silently breaks (fc-match returns arbitrary weight).
- Visual proof without desktop access: render a specimen PNG from the actual installed
  files — `scripts/font-specimen.py` in the terminal-theming skill.

## Post-swap refresh order

1. `fc-cache -f`
2. `qdbus org.kde.KWin /KWin reconfigure` (window titles)
3. `systemctl --user restart plasma-plasmashell.service` (NOT `plasmashell --replace`)
4. `pkill -HUP xsettingsd`
5. Verify: `ps -o lstart= -p $(pgrep -x plasmashell)` is newer than your edits.
6. Already-open apps keep cached fonts until restart; full re-login = 100%.
