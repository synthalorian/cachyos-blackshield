# CSS Custom Property Theme Architecture

## How It Works

The entire UI is driven by CSS custom properties (variables). Seven theme `.css` files each define *every* variable under a class selector (`.theme-synthwave84`, `.theme-dark`, etc.). At runtime, the React `ThemeContext` applies the corresponding class to `<html>`, and every component reading `var(--bg-primary)` instantly re-renders with the correct color.

There is no runtime CSS-in-JS library. There are no per-component style overrides. The theme is a pure CSS-layer swap.

## Architecture Diagram

```
index.html (default: no theme class on <html>)
  └── main.tsx (imports all 7 theme CSS files + App.css)
        └── ThemeProvider (wraps entire app)
              ├── On mount: reads localStorage → applies `.theme-<id>` to <html>
              ├── setTheme(): saves to localStorage + swaps class on <html>
              └── ThemePicker (dropdown in Sidebar)
```

## File Structure

```
src/themes/
├── synthwave84.css          ── Deep purple neon (default)
├── synthwave-midnight.css   ── Cool navy blues
├── synthwave-dawn.css       ── Warm amber sunrise
├── dark.css                 ── Clean modern dark (Catppuccin)
├── light.css                ── Clean modern light
├── cyberpunk.css            ── High-contrast neon dystopia
└── fallout-terminal.css     ── Green phosphor CRT (all monospace)
```

## Anatomy of a Theme File

Every theme file has the same structure. The `themes/` directory IS the theme implementation — no per-component CSS needs editing to add a new theme.

### Variable Groups (in order):

```css
.theme-myname {          /* ← class selector, NOT :root */
  /* 1. Backgrounds (7 levels) */
  --bg-primary: #...;     /* app background */
  --bg-secondary: #...;   /* elevated surfaces (sidebar, cards) */
  --bg-tertiary: #...;    /* inputs, search bars */
  --bg-hover: #...;       /* hover states */
  --bg-surface: #...;     /* card backgrounds */
  --bg-raised: #...;      /* dropdowns, modals */
  --bg-overlay: rgba(...); /* semi-transparent overlays */

  /* 2. Text */
  --text-primary: #...;   /* headings, primary content */
  --text-secondary: #...; /* body text */
  --text-muted: #...;     /* metadata, hints */
  --text-inverse: #...;   /* text on gradients */

  /* 3. Accents (7 colors) */
  --accent-primary: #...;  /* primary interaction color */
  --accent-secondary: #...; /* secondary, gradients pair */
  --accent-tertiary: #...;  /* highlights (level, XP) */
  --accent-cyan: #...;
  --accent-blue: #...;
  --accent-pink: #...;
  --accent-red: #...;
  --accent-orange: #...;
  --accent-green: #...;

  /* 4. Semantic */
  --success: #...;
  --warning: #...;
  --error: #...;
  --info: #...;

  /* 5. Borders */
  --border-color: #...;
  --border-glow: rgba(...);
  --border-light: #...;

  /* 6. Glow effects (box-shadow values, not colors) */
  --glow-primary: 0 0 12px rgba(...), 0 0 24px rgba(...);
  --glow-secondary: ...;
  --glow-cyan: ...;
  --glow-yellow: ...;
  --glow-green: ...;

  /* 7. Gradients */
  --gradient-primary: linear-gradient(135deg, ...);
  --gradient-text: linear-gradient(180deg, ...);
  --gradient-sidebar: linear-gradient(180deg, ...);
  --gradient-header: ...;
  --gradient-input: ...;

  /* 8. CRT & Atmosphere */
  --crt-opacity: 0.25;      /* 0 for non-retro themes (dark, light) */
  --grid-opacity-1: rgba(... /* subtle grid */
  --grid-opacity-2: rgba(... /* auth-view perspective grid */

  /* 9. Typography */
  --font-body: 'Inter', ...;
  --font-display: 'Orbitron', ...;
  --font-mono: 'Share Tech Mono', ...;

  /* 10. Layout */
  --radius: 8px;            /* can vary per theme (cyberpunk=4px, terminal=2px) */
  --radius-sm: 6px;
  --radius-lg: 12px;
  --radius-xl: 16px;
  --shadow-sm: 0 1px 3px rgba(...);
  --shadow-md: ...;
  --shadow-lg: ...;

  /* 11. Animation */
  --transition-fast: 0.15s;
  --transition-normal: 0.2s;
  --transition-slow: 0.3s;

  /* 12. Picker metadata */
  --theme-name: 'My Theme';
  --theme-icon: '🌆';
}

/* 13. Per-theme overrides for global pseudo-elements */
.theme-myname body::after { opacity: var(--crt-opacity); }
.theme-myname .sidebar { background: var(--gradient-sidebar); }
```

### Backward-Compat Aliases

Always add these at the end of every theme file (right after `--theme-icon:`):

```css
  /* Backward-compat aliases */
  --accent-purple: var(--accent-primary);
  --accent-magenta: var(--accent-secondary);
  --glow-purple: var(--glow-primary);
  --glow-magenta: var(--glow-secondary);
```

This means existing `.css` files that reference `var(--accent-purple)` keep working without modification. New CSS should use the new names. When the old references are all migrated, remove the aliases.

## ThemeContext (React)

```typescript
// hooks/ThemeContext.tsx

export type ThemeId = 'synthwave84' | 'dark' | 'light' | ...;

export const THEMES: ThemeInfo[] = [
  { id: 'synthwave84', name: "Synthwave '84", icon: '🌆', description: '...' },
  // ...
];

function ThemeProvider({ children }) {
  const [theme, setThemeState] = useState<ThemeId>(loadTheme);

  useEffect(() => {
    const root = document.documentElement;
    THEMES.forEach(t => root.classList.remove(`theme-${t.id}`));
    root.classList.add(`theme-${theme}`);
  }, [theme]);
  // ...
}
```

## ThemePicker UI Pattern

Position in the sidebar between the navigation and the user-info section. Dropdown opens upward (bottom-anchored) so it doesn't overflow the sidebar bottom edge. Each option shows icon + name + description.

## Adding a New Theme

1. Create `src/frontend/src/themes/newtheme.css` with the full variable set
2. Import it in `src/frontend/src/main.tsx`
3. Add `ThemeInfo` entry to `hooks/ThemeContext.tsx`
4. Done — no other files need changes

## Non-Retro Theme Notes

**Dark & Light themes** disable retro effects:
- `--crt-opacity: 0` + `body::after { display: none; }`
- `body::before { display: none; }` (hides grid overlay)
- Replace `--font-display: 'Orbitron', ...` with `--font-display: 'Inter', ...` (no display font)
- `--radius-*` are larger (more modern feel)
- `--glow-*` are more subtle (lower opacity, smaller blur)

**Fallout Terminal** forces all text to monospace:
```css
.theme-fallout-terminal * { font-family: var(--font-body) !important; }
```