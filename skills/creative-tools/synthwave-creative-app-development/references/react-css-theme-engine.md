# React CSS Custom Property Theme Engine

## Architecture

A React Context-based theme system using CSS class swapping on `<html>`. Themes are defined as separate CSS files each scoped to a `.theme-*` class selector. The React `ThemeContext` manages state, persistence, and class application.

### Key Difference from Rails/`data-theme` Approach

The Rails approach uses a single CSS file with `[data-theme="..."]` selectors. The React approach uses **multiple CSS files** each scoped to a `.theme-*` class, making themes independently loadable and tree-shakable.

### File Structure

```
src/
├── themes/
│   ├── synthwave84.css          → .theme-synthwave84 { --bg-primary: ... }
│   ├── synthwave-midnight.css   → .theme-synthwave-midnight { --bg-primary: ... }
│   ├── dark.css                 → .theme-dark { --bg-primary: ... }
│   ├── light.css                → .theme-light { --bg-primary: ... }
│   ├── cyberpunk.css            → .theme-cyberpunk { --bg-primary: ... }
│   └── fallout-terminal.css     → .theme-fallout-terminal { --bg-primary: ... }
├── hooks/
│   └── ThemeContext.tsx          → ThemeProvider, useTheme, theme registry
├── components/
│   └── ThemePicker.tsx          → Dropdown UI for theme selection
└── main.tsx                     → Imports all theme CSS files
```

### Variable Contract

Every theme file defines the SAME set of CSS custom properties, ensuring any component that references `var(--bg-primary)` works in any theme:

| Category | Variables |
|---|---|
| Backgrounds | `--bg-primary`, `--bg-secondary`, `--bg-tertiary`, `--bg-hover`, `--bg-surface`, `--bg-raised`, `--bg-overlay` |
| Text | `--text-primary`, `--text-secondary`, `--text-muted`, `--text-inverse` |
| Accents | `--accent-primary`, `--accent-secondary`, `--accent-tertiary`, `--accent-cyan`, `--accent-blue`, `--accent-pink`, `--accent-red`, `--accent-orange`, `--accent-green` |
| Semantic | `--success`, `--warning`, `--error`, `--info` |
| Borders | `--border-color`, `--border-glow`, `--border-light` |
| Glows | `--glow-primary`, `--glow-secondary`, `--glow-cyan`, `--glow-yellow`, `--glow-green` |
| Gradients | `--gradient-primary`, `--gradient-text`, `--gradient-sidebar`, `--gradient-header`, `--gradient-input` |
| CRT | `--crt-opacity`, `--grid-opacity-1`, `--grid-opacity-2` |
| Typography | `--font-body`, `--font-display`, `--font-mono` |
| Spacing | `--radius`, `--radius-sm`, `--radius-lg`, `--radius-xl` |
| Shadows | `--shadow-sm`, `--shadow-md`, `--shadow-lg` |
| Transition | `--transition-fast`, `--transition-normal`, `--transition-slow` |
| Metadata | `--theme-name`, `--theme-icon` |

### Backward-Compat Aliases

When migrating FROM hardcoded single-theme variable names (like `--accent-purple`) TO standardized names (like `--accent-primary`), add aliases at the bottom of each theme file:

```css
.theme-synthwave84 {
  /* ... all primary variables ... */

  /* Backward-compat aliases */
  --accent-purple: var(--accent-primary);
  --accent-magenta: var(--accent-secondary);
  --glow-purple: var(--glow-primary);
  --glow-magenta: var(--glow-secondary);
}
```

This lets existing CSS continue to work while new CSS uses the canonical names.

### ThemeContext Pattern

```tsx
// ThemeContext.tsx
import { createContext, useContext, useState, useCallback, useEffect } from 'react';

export type ThemeId = 'synthwave84' | 'dark' | 'light' | 'cyberpunk' | ...;

export const THEMES = [
  { id: 'synthwave84', name: "Synthwave '84", icon: '🌆', description: 'Deep purple neon' },
  // ...
];

// Load/save from localStorage
const STORAGE_KEY = 'janus_theme';

export function ThemeProvider({ children }: { children: React.ReactNode }) {
  const [theme, setThemeState] = useState<ThemeId>(() => {
    try { return localStorage.getItem(STORAGE_KEY) as ThemeId || 'synthwave84'; }
    catch { return 'synthwave84'; }
  });

  const setTheme = useCallback((id: ThemeId) => {
    setThemeState(id);
    localStorage.setItem(STORAGE_KEY, id);
  }, []);

  // Apply theme class to <html> element
  useEffect(() => {
    const root = document.documentElement;
    THEMES.forEach(t => root.classList.remove(`theme-${t.id}`));
    root.classList.add(`theme-${theme}`);
  }, [theme]);

  return (
    <ThemeContext.Provider value={{ theme, setTheme, themes: THEMES }}>
      {children}
    </ThemeContext.Provider>
  );
}
```

**Key decisions:**
- Theme class goes on `<html>` — not `<body>` — to ensure CSS cascade works correctly with `body::before/after` pseudo-elements
- All theme CSS files are imported in `main.tsx` so they're bundled at build time (no dynamic loading)
- `localStorage` for persistence — survives page reloads without a server roundtrip
- Theme Context wraps the auth layer so theme applies before auth redirects render

### Theme Picker Component

```tsx
function ThemePicker() {
  const { theme: currentTheme, setTheme } = useTheme();
  // Dropdown: button shows current theme icon+name, click opens list
  // Each option: icon + name + description + checkmark for active
  // Dropdown positioned above the toggle (bottom: calc(100% + 6px))
}
```

Styled with CSS variables so it auto-adapts to the current theme's colors.

### Per-Theme Override Files

Each theme file can include specific overrides at the bottom:

```css
/* synthwave84 overrides */
.theme-synthwave84 .sidebar {
  background: linear-gradient(180deg, #16082e 0%, #0d0221 100%);
}

/* dark/light themes turn off CRT effects */
.theme-dark body::after { opacity: 0; display: none; }
.theme-dark body::before { display: none; }

/* fallout-terminal forces monospace everywhere */
.theme-fallout-terminal * {
  font-family: var(--font-body) !important;
}
```

### Cross-Framework Translation

| Framework | Approach |
|---|---|
| **React** | CSS class swap on `<html>` via Context (this doc) |
| **Rails/Tailwind** | `[data-theme="..."]` attribute on `<html>` via server-rendered template (see `css-custom-property-theme-engine.md`) |
| **Flutter** | `ThemeData` with `ThemeExtension` — switch via `ThemeMode` or custom Provider |
| **egui/Rust** | `Visuals` struct with synthwave palette, switch via dropdown |

### Implementation Found In

- Janus (React + Vite, 7 themes) — first React project to use this pattern