---
name: linux-terminal-theming
description: "Sync Alacritty Kitty Ghostty themes on KDE."
version: 1.0.0
tags: [linux, kde, terminal, ghostty, alacritty, kitty, theming]
---

# Linux Terminal Theming

Unified theming across Alacritty, Kitty, and Ghostty on KDE, with exact
palette mirroring and emulator-specific syntax fixes.

## Canonical Synthwave '84 Palette

Use these exact values everywhere:

- Background: `#0D0221`
- Foreground: `#FF7EDB`
- Cursor: `#F3E70F` on `#0D0221`
- Selection: foreground `#0D0221`, background `#8F00FF`
- Link/URL: `#03EDF9`

16-color base:
`#0D0221`, `#FE4450`, `#72F1B8`, `#F3E70F`, `#8F00FF`, `#FF00FF`,
`#03EDF9`, `#FF7EDB`

Brights:
`#495495`, `#FE4450`, `#72F1B8`, `#FEDE5D`, `#B084EB`, `#FF7EDB`,
`#03EDF9`, `#FFFFFF`

Dim:
`#0D0221`, `#A32436`, `#3E8F6B`, `#8F8306`, `#4B0080`, `#800080`,
`#027A82`, `#A4558F`

Font: `3270 Nerd Font`, size `12`.

## Emulator Configs

### Alacritty

Path: `~/.config/alacritty/alacritty.toml`

TOML with nested tables:
```toml
[colors.primary]
background = "#0D0221"
foreground = "#FF7EDB"

[colors.normal]
black   = "#0D0221"
red     = "#FE4450"
green   = "#72F1B8"
yellow  = "#F3E70F"
blue    = "#8F00FF"
magenta = "#FF00FF"
cyan    = "#03EDF9"
white   = "#FF7EDB"

[colors.bright]
black   = "#495495"
red     = "#FE4450"
green   = "#72F1B8"
yellow  = "#FEDE5D"
blue    = "#B084EB"
magenta = "#FF7EDB"
cyan    = "#03EDF9"
white   = "#FFFFFF"
```

### Kitty

Path: `~/.config/kitty/kitty.conf`

Flat `key = value` syntax:
```text
background            #0D0221
foreground            #FF7EDB
cursor                #F3E70F
cursor_text_color     #0D0221
selection_background  #8F00FF
selection_foreground  #0D0221
color0 ... color15     # same as palette above
```

### Ghostty

Path: `~/.config/ghostty/config.ghostty`

Flat `key = value` syntax. Important:
- Use `font-style-bold = true` instead of separate bold font families.
- Use `window-decoration = false`, not `hide-window-decorations`.
- Use `scrollback-limit = 10000`, not `scrollback`.
- Use `cursor-text`, not `cursor-text-color`.
- Use `selection-background` / `selection-foreground`, not `selection-color`.
- Use `confirm-close-surface = false`, not `confirm-close`.
- Use `cursor-style-blink = true`, not `cursor-blink-interval`.
- Keybinds must have no spaces around inner `=`:
  ```text
  keybind = ctrl+==increase_font_size:1
  ```

Validate:
```bash
ghostty +validate-config
ghostty +show-config
```

## KDE Default Terminal

Set KDE's preferred terminal:
```bash
kwriteconfig6 --file ~/.config/kdeglobals --group General --key TerminalApplication com.mitchellh.ghostty.desktop
```

Also update app-specific launchers that embed a terminal choice:
- Kate external tools: `~/.config/kate/externaltools/*.ini`
- Desktop files under `~/.local/share/applications/` if they explicitly choose Konsole/Alacritty.

## KDE Color Scheme Sync

To make the terminal palette visible system-wide, create a local color scheme:
- Path: `~/.local/share/color-schemes/<Name>.colors`
- Set via `kwriteconfig6 --file ~/.config/kdeglobals --group General --key ColorScheme <Name>`
- Remove stale `ColorSchemeHash` so KDE recomputes.

## Pitfalls

- Ghostty config is strict; one bad keybind line does not prevent launch, but
  invalid lines are silently ignored and logged.
- Ghostty ships its own config parser, not TOML — do not copy Alacritty's
  nested tables into Ghostty.
- KDE color schemes are separate from terminal colors; mirroring the palette
  in `~/.local/share/color-schemes/*.colors` makes Terminal + System settings
  consistent.
- Ghostty's `+show-config` shows normalized keys; when in doubt, grep its
  output instead of guessing field names.