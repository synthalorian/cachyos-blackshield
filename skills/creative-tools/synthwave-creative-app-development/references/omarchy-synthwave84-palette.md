# Synthwave '84 Palette — Omarchy Parity

Synthwave '84 is the default theme on synthalorian's Omarchy desktop. Every app-level theme system must have parity with this palette.

## Core Palette

| Color | Token | Hex | Usage |
|---|---|---|---|
| Background | `--sw84-bg` | `#240037` | Scaffold/screen background |
| Surface | `--sw84-surface` | `#1A002A` | Input fills, dropdown menus |
| Card | `--sw84-card` | `#2D0045` | Card backgrounds, dialog bg |
| Purple | `--sw84-purple` | `#8F00FF` | Primary accent, active border |
| Yellow | `--sw84-yellow` | `#F3E70F` | Secondary accent, warning |
| Yellow Bright | `--sw84-yellow-bright` | `#FFFF66` | Bright yellow, hover states |
| Pink | `--sw84-pink` | `#FF00FF` | Cursor, tertiary accent |
| Pink Soft | `--sw84-pink-soft` | `#FF7EDB` | Section headers, soft pink |
| Cyan | `--sw84-cyan` | `#03EDF9` | Bright cyan highlights |
| Blue | `--sw84-blue` | `#0080FF` | Blue accent, links |
| Red | `--sw84-red` | `#FF0040` | Danger, errors |
| Red Bright | `--sw84-red-bright` | `#FE5442` | Bright red for alerts |
| Text | `--sw84-text` | `#FFFFFF` | Primary text |
| Text Dim | `--sw84-text-dim` | `#B0A0C0` | Secondary text, hints |

## Omarchy Terminal Colors

These correspond to the alacritty/kitty ansi color scheme on Omarchy:

```toml
[colors.normal]
black   = "#262335"
red     = "#ff0040"
green   = "#8f00ff"
yellow  = "#f3e70f"
blue    = "#0080ff"
magenta = "#ff00ff"
cyan    = "#03edf9"
white   = "#ffffff"

[colors.bright]
black   = "#614d85"
red     = "#fe5442"
green   = "#fe5442"
yellow  = "#ffff66"
blue    = "#0080ff"
magenta = "#ff7edb"
cyan    = "#03edf9"
white   = "#ffffff"
```

## Dart Constants for App Themes

```dart
const Color sw84Background = Color(0xFF240037);
const Color sw84Surface = Color(0xFF1A002A);
const Color sw84Card = Color(0xFF2D0045);
const Color sw84Purple = Color(0xFF8F00FF);
const Color sw84Yellow = Color(0xFFF3E70F);
const Color sw84YellowBright = Color(0xFFFFFF66);
const Color sw84Pink = Color(0xFFFF00FF);
const Color sw84PinkSoft = Color(0xFFFF7EDB);
const Color sw84Cyan = Color(0xFF03EDF9);
const Color sw84Blue = Color(0xFF0080FF);
const Color sw84Red = Color(0xFFFF0040);
const Color sw84RedBright = Color(0xFFFE5442);
const Color sw84Text = Color(0xFFFFFFFF);
const Color sw84TextDim = Color(0xFFB0A0C0);
```

## CSS Variables for Web Parity

```css
[data-theme="synthwave84"] {
  --sw84-bg: #240037;
  --sw84-surface: #1A002A;
  --sw84-card: #2D0045;
  --sw84-purple: #8F00FF;
  --sw84-yellow: #F3E70F;
  --sw84-yellow-bright: #FFFF66;
  --sw84-pink: #FF00FF;
  --sw84-pink-soft: #FF7EDB;
  --sw84-cyan: #03EDF9;
  --sw84-blue: #0080FF;
  --sw84-red: #FF0040;
  --sw84-text: #FFFFFF;
  --sw84-text-dim: #B0A0C0;
}
```