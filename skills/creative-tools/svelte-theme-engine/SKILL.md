---
name: svelte-theme-engine
description: Svelte + CSS variable theming and palette sync.
tags:
  - svelte
  - theme-engine
  - css-variables
  - ghostty
  - kde
  - design-tokens
  - drawer
  - synthwave
---

# Svelte Theme Engine + UI Polish

**Class**: Svelte + CSS custom property theme systems, Ghostty/KDE palette exact-sync workflows, and retro-futurist UI polish tasks.

## When to Use

- Theme, re-theme, or sync a Svelte web app’s palette with a terminal theme source
- Palette exactness matters: Ghostty, Alacritty, Kitty, KDE color schemes
- Polishing drawers, animations, or accessibility in Svelte app views

## Canonical Source Sync

Treat one source as canonical. For OpenShark Chompers: `~/.config/ghostty/config.ghostty` provides exact hex values: background `#0D0221`, foreground `#FF7EDB`, cursor `#F3E70F`, selection-background `#8F00FF`, selection-foreground `#0D0221`, accents: pink `#FF7EDB`, cyan `#03EDF9`, purple `#8F00FF`, yellow `#F3E70F`.

**Mirror rule**: The web theme’s semantic tokens must map directly from these terminal exacts. Add aliases in `themes.js` where needed.

**Pitfall**: Cross-platform drift. Palette changes must update web theme, Flutter themes, README badges, and KDE color schemes in the same edit set.

## Svelte Drawer Polish

For off-canvas drawers, use stateful class toggles with hardware-accelerated motion:
- `drawerOpen` boolean drives `.backdrop.show` / `.drawer.open`
- CSS: `transform: translateX(-100%)` → `translateX(0)` and backdrop opacity transition
- Keyboard: `Escape` closes drawer
- Outside click: backdrop dismisses drawer
- ARIA: `role="region"`, `aria-label`

## Token-First CSS

Never hardcode `border-radius`, `transition`, or `font` values in component styles:
1. Define shared tokens in global `app.css`: `--radius`, `--transition`, `--mono`
2. Reference them in ALL views, including scoped `<style>` blocks
3. Migrate views incrementally as you edit them

**Pitfall**: Svelte scoped `<style>` blocks do not inherit `:root` token values automatically unless those custom properties are explicitly referenced.

## Accessibility Hardenings

A `<div>` with `onclick` triggers Svelte a11y warnings:
- Add `role`, `tabindex`, and keyboard handlers
- Prefer native `button`/`a` elements when semantically appropriate

## Verification

- Rebuild after CSS: `npm run build`
- Check emitted chunks + gzip sizes in build output
- Diff theme vars against Ghostty palette for exactness
- Test drawer UX manually: Escape, backdrop click, tab-focus path
