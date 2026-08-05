# Omarchy Synthwave84 Palette

Extracted from `~/.config/omarchy/themes/synthwave84/` (alacritty.toml, waybar.css, walker.css, swayosd.css).
This is the canonical color palette for both Forge Hub (CSS) and Forge CLI (Rust `theme.rs` SYNTHWAVE84).

## Core Palette

| Role | Hex | Usage |
|------|-----|-------|
| Background (deep) | `#0d0221` | Body background, sidebar |
| Background (panel) | `#180030` | Cards, elevated panels |
| Background (surface) | `#240037` | Elevated elements, alacritty bg |
| **Primary purple** | `#8f00ff` | Headers, brand, labels, borders, sidebar icons |
| Magenta | `#ff00ff` | Accent, cursor, progress bars |
| Hot pink | `#ff7edb` | Info, secondary highlights |
| Cyan | `#03edf9` | Success, tertiary accent |
| Yellow | `#f3e70f` | Warnings |
| Muted | `#614d85` | Dim text, subtle borders |
| Red | `#ff0040` | Errors, destructive actions |
| Green | `#50fa7b` | Active/online indicators |

## Design Rules

- **Purple-first, not cyan-first.** `#8f00ff` is the brand color. Cyan is secondary/accent only.
- Deep backgrounds go from `#0d0221` (darkest) → `#180030` (panels) → `#240037` (elevated).
- Glow effects use purple (`0 0 20px rgba(143,0,255,0.3)`) for headers and interactive elements.
- CRT scanlines, grid overlay, and horizon glow effects all derive from theme variables.

## Forge CLI `theme.rs` Mapping

```
SYNTHWAVE84:
  header:  #8f00ff  (purple - brand)
  accent:  #ff00ff  (magenta)
  success: #03edf9  (cyan)
  error:   #ff0040
  warning: #f3e70f
  info:    #ff7edb  (pink)
  border:  #8f00ff  (purple)
  label:   #8f00ff  (purple)
  muted:   #614d85
  text:    #e0d6eb
  dimmed:  #4a3a6a
  background: (not used by colored crate)
```

## Source Files

- `~/.config/omarchy/themes/synthwave84/alacritty.toml` — terminal colors
- `~/.config/omarchy/themes/synthwave84/waybar.css` — bar styling
- `~/.config/omarchy/themes/synthwave84/walker.css` — launcher styling
- `~/.config/omarchy/themes/synthwave84/swayosd.css` — OSD styling
