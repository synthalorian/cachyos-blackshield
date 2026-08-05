# OpenShark Chompers Ghostty-Exact Palette

Source: `~/.config/ghostty/config.ghostty`
Created: 2026-07-30

## Exact Hex Map

```
background            = #0D0221
foreground            = #FF7EDB
cursor-color          = #F3E70F
cursor-text           = #0D0221
selection-background  = #8F00FF
selection-foreground  = #0D0221

palette = 0  = #0D0221   palette = 16 = #0D0221
palette = 1  = #FE4450   palette = 17 = #A32436
palette = 2  = #72F1B8   palette = 18 = #3E8F6B
palette = 3  = #F3E70F   palette = 19 = #8F8306
palette = 4  = #8F00FF   palette = 20 = #4B0080
palette = 5  = #FF00FF   palette = 21 = #800080
palette = 6  = #03EDF9   palette = 22 = #027A82
palette = 7  = #FF7EDB   palette = 23 = #A4558F
palette = 8  = #495495
palette = 9  = #FE4450
palette = 10 = #72F1B8
palette = 11 = #FEDE5D
palette = 12 = #B084EB
palette = 13 = #FF7EDB
palette = 14 = #03EDF9
palette = 15 = #FFFFFF
```

## Synthwave-84 Theme Vars (Ghostty-exact)

```css
:root {
  --bg: #0D0221;
  --bg-panel: #140535;
  --bg-elevated: #1C0B48;
  --border: #3A1F7A;
  --neon-pink: #FF7EDB;
  --neon-cyan: #03EDF9;
  --neon-purple: #8F00FF;
  --neon-yellow: #F3E70F;
  --text: #FF7EDB;
  --text-dim: #B57EDB;
  --selection-bg: #8F00FF;
  --selection-fg: #0D0221;
  --success: #72F1B8;
  --error: #FE4450;
}
```

## Notes

- `--text` defaults to neon-pink in dark theme for consistency with Ghostty foreground
- `--border` is stepped up from Ghostty base to remain visible on `--bg`
- Font family uses `3270` + `3270 SemiCondensed` when available; falls back to monospace stack
- Terminal cursor style: block + blink, cursor-color `#F3E70F`
