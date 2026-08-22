# Medieval-Style Font Alternatives — Readability Comparison

Condensed research from 2026-08-22 session. User wanted a readable replacement
for Canterbury (blackletter/Old English) across the whole desktop. This file
captures the candidate set, readability verdicts, and deployment notes.

## Canterbury — the baseline problem

Canterbury is a blackletter/Old English decorative font. Vision-analyzed specimen
confirmed:

- **Tight vertical spacing** — dense "woven" texture, stems close together
- **Tiny counters** — internal openings in letters like `e`, `a`, `s` are small
- **Thin hairlines + sharp pointed terminals** — degrades fast on dark backgrounds
- **Ambiguous letterforms at small sizes:** `u`/`v`/`n`, `a`/`h`, `c`/`e`
- **Ornate capitals** — decorative swashes make recognition depend on seeing the
  whole word; `C`/`A`/`T`/`E`/`R` blur together in all-caps
- **Stylized digits** — old-fashioned, not optimized for quick scanning
- **Same TTF for regular and bold** — `fc-query` shows `Canterbury.ttf` for both;
  bold is synthetic

**Verdict:** excellent for titles/logos/certificates at 48pt+. Poor for daily
reading at 11pt on a dark desktop — exactly the problem the user reported.

## Candidate fonts evaluated (all installed/available)

### DejaVu Serif (already installed)

- **Style:** Utilitarian screen serif, large x-height, open apertures, sturdy
  serifs, moderate stroke contrast
- **Readability:** Excellent at 9–12pt. Designed for screen legibility.
- **Medieval feel:** None — it's a functional serif, not evocative
- **Weights:** Real regular + bold (separate TTFs)
- **Best for:** System-wide default where readability is the only goal

### Liberation Serif (already installed)

- **Style:** Times New Roman-compatible transitional/old-style serif, metric-compatible
- **Readability:** Excellent — workhorse document font, large x-height, open counters
- **Medieval feel:** "Old and formal" connotation but not medieval specifically
- **Weights:** Real regular + bold
- **Best for:** Classic "serious" look without blackletter illegibility

### Noto Serif (already installed)

- **Style:** Neutral bookish serif, moderate contrast, broad script coverage
- **Readability:** Very good — clean, consistent, sturdy at small sizes
- **Medieval feel:** None — sober, practical, global
- **Weights:** Real regular + bold
- **Best for:** Safe readable serif where aesthetics are secondary

### Cormorant (just installed via `ttf-cormorant`)

- **Style:** Elegant high-contrast display serif, Renaissance/roman with medieval
  aura — sharp tapered terminals, hairline horizontals, thick verticals, calligraphic
  rhythm, classical inscriptional capitals
- **Readability:** Good at headlines and short text. Poor at small sizes — hairlines
  fade on dark backgrounds, thin strokes disappear. **Not for body text or 11pt terminals.**
- **Medieval feel:** Yes — elegant antique aura, more Renaissance than Gothic
- **Weights:** Full variable-weight family (Regular, Medium, SemiBold, Bold, Light,
  Italic variants — separate TTFs for each)
- **Best for:** Titles, headers, pull quotes, ceremonial UI labels at 12pt+
- **Installed faces:** `/usr/share/fonts/TTF/Cormorant-*.ttf` — 40+ faces

### Cormorant Garamond (installed as part of ttf-cormorant)

- **Style:** Tamed sibling of Cormorant — slightly more robust, Garamond-flavored,
  old-style serif with high contrast but less extreme than Cormorant proper
- **Readability:** Better than Cormorant at text sizes, still a display face. Old-style
  figures (text numerals). Still fades at very small sizes on dark backgrounds.
- **Medieval feel:** Yes — classical Garalde elegance, manuscript-adjacent
- **Weights:** Full variable-weight family (Regular, SemiBold, Bold, Medium, Light,
  Italic variants)
- **Best for:** The middle ground — more readable than Cormorant, still elegant.
  Good compromise for "medieval feel but readable"

### AUR packages (not installed this session)

- **`ttf-medievalsharp`** (AUR, 4 votes, 0.0006 popularity) — Gothic letters,
  designed to be more readable than pure blackletter. Moderate readability — better
  than Canterbury but still decorative. Would need AUR install.
- **`ttf-unifraktur`** (AUR, 10 votes, 0.002 popularity) — Fraktur fonts. Still
  blackletter. Still not for body text. Only if the user specifically wants Fraktur.

## Recommendation

For "medieval feel but actually readable across the board":

**Primary recommendation: Cormorant Garamond** — best balance of medieval-adjacent
elegance and real readability. Already installed via `ttf-cormorant`. Works at
12pt+ for display and UI labels. For body text and fine print at 11pt, pair with
a screen serif.

**Split approach (most robust):**
- Cormorant Garamond for titles, headings, display, ceremonial UI
- DejaVu Serif or Liberation Serif for body text, terminals, fine print

**If the user insists on one font everywhere:** DejaVu Serif — loses medieval feel
entirely but gains real readability. Liberation Serif if they want "old and formal"
connotation without the blackletter headache.

## How to deploy (see terminal-theming/references/system-wide-font-swap-checklist.md)

Every store that can carry a default font:

| Store | Keys |
|---|---|
| `~/.config/kdeglobals` `[General]` | `font`, `fixed`, `smallestReadableFont`, `menuFont`, `toolBarFont`, `activeFont` (legacy) |
| `~/.config/kdeglobals` `[WM]` | `activeFont`, `inactiveFont` (window titles) |
| `~/.config/gtk-3.0/settings.ini`, `gtk-4.0/settings.ini` | `gtk-font-name=<Family> <size>` |
| `~/.config/xsettingsd/xsettingsd.conf` | `Gtk/FontName "<Family> <size>"` + `pkill -HUP xsettingsd` |
| `~/.config/Trolltech.conf` | `font="<qfont>"` |
| dconf | `org.gnome.desktop.interface font-name`, `monospace-font-name`, `document-font-name` via `gsettings` |
| Alacritty | `~/.config/alacritty/alacritty.toml` `[font.normal|bold|italic|bold_italic]` |
| Kitty | `~/.config/kitty/kitty.conf` `font_family` / `bold_font` / `italic_font` / `bold_italic_font` |
| Ghostty | `~/.config/ghostty/config.ghostty` `font-family` |
| plasmalogin greeter | `~/.config/plasma-workspace/plasmalogin.conf` + greeter kdeglobals |

Qt font string format: `Family,pointSize,-1,5,weight,0,0,0,0,0,0,0,0,0,0,1`
(weight: 400 = Regular, 700 = Bold).

After deploy: `fc-cache -f`, `qdbus org.kde.KWin /KWin reconfigure`,
`systemctl --user restart plasma-plasmashell.service` (NOT `plasmashell --replace`),
`pkill -HUP xsettingsd`. Open apps keep cached fonts until restart.
