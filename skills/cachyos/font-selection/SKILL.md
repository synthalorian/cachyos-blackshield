---
name: font-selection
description: Use when selecting readable fonts for a Linux desktop.
---

# Font Selection & Evaluation

Class playbook for evaluating candidate fonts and selecting one that works for
daily use — balancing readability against aesthetic intent. Covers the
specimen-rendering pipeline, vision-analyze comparison, and font package
discovery on Arch/CachyOS.

## When this applies

- User says a font is hard to read and wants alternatives
- Comparing two or more candidate fonts for system-wide deployment
- Searching for a font with a specific aesthetic (medieval, blackletter, serif)
  that is also readable at small sizes
- About to deploy a font across kdeglobals/GTK/terminals/plasmalogin (see
  `terminal-theming` SKILL.md + its `references/system-wide-font-swap-checklist.md`
  for deployment mechanics — this skill covers *selection* only)

## The core problem: display vs text fonts

Decorative fonts (blackletter, Old English, heavy display serifs) look great at
48pt on a poster and become illegible at 11pt on a dark terminal. The evaluation
must separate these:

| Category | Readable at 9–12pt? | Best use | Examples |
|---|---|---|---|
| Blackletter / Old English | No — tight spacing, tiny counters, ambiguous `u/v/n`, `a/h` | Titles, logos, certificates only | Canterbury, Fraktur, Unifraktur, MedievalSharp |
| High-contrast display serif | Marginal — hairlines fade on dark bg at small sizes | Headlines, pull quotes, UI labels at 12pt+ | Cormorant, Cormorant Garamond, Playfair Display |
| Old-style / Garalde serif | Yes, with caveats — needs adequate size/weight | Body text, documents, UI at 11pt+ | Cormorant Garamond, EB Garamond, Caslon, Jenson |
| Transitional / screen serif | Yes — designed for legibility | Body text, terminals, daily UI | DejaVu Serif, Liberation Serif, Noto Serif |
| Sans / humanist | Yes — most readable class | UI, terminals, body text | 3270 Nerd Font, Inter, Noto Sans |

**Rule of thumb:** "medieval feel but readable" → old-style serif (Cormorant
Garamond, EB Garamond), not blackletter. "Readable across the board" → screen
serif or the existing Nerd Font stack. One font doing both is what produces the
Canterbury problem; splitting display vs body across two fonts is usually right.

## Comparative evaluation workflow

When comparing N candidates, do not eyeball a single screenshot. Use the
specimen pipeline:

1. **Render each candidate** with `font-specimen.py` (from `terminal-theming`
   skill, `scripts/font-specimen.py`):
   ```
   python3 ~/.hermes/skills/cachyos/terminal-theming/scripts/font-specimen.py \
       --family "<Family>" --out /tmp/font-comparison/<safe-name>.png
   ```
   Resolves actual installed TTF files via fc-match — ground truth, not config
   parsing. Renders title/pangram/bold/nerd-glyph rows.

2. **Vision-analyze each specimen** asking:
   - Character shapes: distinct at small sizes?
   - Spacing: tight (blackletter) or open (screen serif)?
   - Weight: do hairlines survive on dark backgrounds?
   - Readability: can you distinguish `u/v/n`, `a/h`, `1/l/I`, `0/O`?
   - Verdict: readable at 11pt on dark background?

3. **Compare side by side.** Render all candidates in one batch, read the
   vision-analyze outputs together. The contrast between "looks cool at 48pt"
   and "unreadable at 11pt" usually jumps out.

4. **Check weights exist.** `fc-list | grep -i <family>` and
   `fc-match "<family>:style=Bold"`. A font whose bold is synthetic (same TTF for
   regular and bold) won't give real bold in terminals.

5. **If deploying**, follow the system-wide font swap checklist in
   `terminal-theming/references/system-wide-font-swap-checklist.md` — kdeglobals
   (General + WM, both legacy `activeFont` and modern keys), GTK2/3/4, xsettingsd,
   Trolltech.conf, dconf, Alacritty, Kitty, Ghostty, plasmalogin greeter.

## Font package discovery (Arch/CachyOS)

```bash
# Official repos
pacman -Ss 'font' | grep -iE "medieval|blackletter|fraktur|garamond|cormorant|cinzel|old"

# AUR
paru -Ss 'font' | grep -iE "medieval|blackletter|fraktur|garamond|cormorant|cinzel|old"
# or yay -Ss ... if paru unavailable

# Already installed
fc-list : family | sort -u | grep -iE "serif|garamond|caslon|baskerv|trajan|jenson|bembo|cinzel|pirata|medieval|fraktur|cormorant|cardo|old"

# Verify resolution
fc-match "<Family>"
fc-match "<Family>:style=Bold"
fc-list | grep -i "<family>"
```

**AUR packages for medieval-style fonts** (verified this session):
- `ttf-cormorant` (extra repo — `sudo pacman -S ttf-cormorant`) — Cormorant family, elegant display serif with medieval/Renaissance aura, fully variable-weight
- `ttf-medievalsharp` (AUR) — Gothic letters, more readable than pure blackletter but still decorative
- `ttf-unifraktur` (AUR) — Fraktur fonts — still blackletter, still not for body text

## Pitfalls

- **Blackletter at small sizes is always a problem.** Canterbury, Fraktur, Old
  English — dense vertical rhythm, tiny counters, ambiguous letterforms make them
  unreadable at 11pt on dark backgrounds. If the user picked one for daily use,
  steer toward old-style serif or screen serif. Don't say "try larger size" —
  that's not a real system-wide solution.
- **`fc-match` is not a glyph-coverage proof.** `fc-match 'Family:charset=E005'`
  returns the best family match even when the font lacks the glyph. Use
  `fc-list ':charset=E005' family` to see which fonts actually have it.
- **Same TTF for regular and bold.** If `fc-query` shows the same file for both
  weights, bold is synthetic. Some specimen generators list the same path for both
  — check before deploying.
- **Don't deploy nerd-fonts' shipped `10-nerd-font-symbols.conf`.** Its
  `<prefer>` aliases insert Symbols BEFORE the requested family and can hijack
  generic monospace requests. See `terminal-theming/references/system-wide-font-swap-checklist.md`.
- **Fontconfig cache after install.** `fc-cache -f` after adding any font. Verify
  with `fc-match` before rendering specimens.

## Related skills

- `terminal-theming` — owns `font-specimen.py`, terminal font configs
  (Alacritty/Kitty/Ghostty), and the system-wide font swap checklist
- `cachyos` — system-level config for KDE/Ghostty/Limine/Plymouth
