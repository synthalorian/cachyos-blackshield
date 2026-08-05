# CSS Custom Property Theme Engine (Web)

## Architecture

A zero-runtime theme system using CSS custom properties (CSS variables) with `data-theme` attribute switching. No JavaScript state management needed for theme application — the browser handles it natively.

### File Structure
```
app/assets/stylesheets/application.css   → Theme variable definitions + component styles
app/views/layouts/application.html.erb   → <html data-theme="<%= theme_name %>">
```

### Implementation Pattern

**1. Define theme variables in CSS**

```css
/* Default (Synthwave '84) */
:root {
  --color-bg: #0a0a1a;
  --color-surface: #1a0a2e;
  --color-primary: #b388ff;
  --color-secondary: #00e5ff;
  --color-accent: #ff6ec7;
  --color-text: #e0d0f0;
  --color-text-muted: #7a5f9a;
  --color-border: #3d2a5e;
  --color-success: #00e676;
  --color-error: #ff5252;
}

/* Per-theme overrides via data-theme selector */
[data-theme="dark"] {
  --color-bg: #0f0f0f;
  --color-primary: #6366f1;
  --color-secondary: #22d3ee;
  /* ... overrides only the values that differ ... */
}
```

**2. Apply theme in the server-rendered HTML**

```erb
<!-- Rails: set from user preference or model -->
<html data-theme="<%= current_theme.name %>">
```

**3. Reference variables throughout all components**

```html
<div class="bg-[var(--color-surface)] text-[var(--color-text)] 
            border border-[var(--color-border)]">
  <button class="bg-[var(--color-primary)] text-[var(--color-bg)]">
    Themed Button
  </button>
</div>
```

### Synthwave '84 Palette (Match Your Omarchy System)

| Token | Value | Purpose |
|-------|-------|---------|
| `--color-bg` | `#0a0a1a` | Deep space background |
| `--color-surface` | `#1a0a2e` | Cards, panels |
| `--color-surface-alt` | `#2d1b4e` | Hover states, elevated surfaces |
| `--color-primary` | `#b388ff` | Purple glow — main interactions |
| `--color-secondary` | `#00e5ff` | Cyan accent — links, highlights |
| `--color-accent` | `#ff6ec7` | Hot pink — call-to-action, badges |
| `--color-text` | `#e0d0f0` | Lavender white — body text |
| `--color-text-muted` | `#7a5f9a` | Muted purple — secondary text |
| `--color-border` | `#3d2a5e` | Subtle borders |
| `--color-success` | `#00e676` | Green for positive states |
| `--color-warning` | `#ffab00` | Amber for warnings |
| `--color-error` | `#ff5252` | Red for errors |

### Theme Expansion Pattern

New themes are added by:
1. Adding a `[data-theme="theme-name"]` block in the CSS with all variable overrides
2. Adding the theme to the database (if using a Theme model) or to a config list
3. Providing a selector UI (radio buttons, dropdown) that sets the `data-theme` attribute

For a model-backed system:
```ruby
# Theme model with JSONB colors column
class Theme < ApplicationRecord
  validates :colors, presence: true
  PALETTE_KEYS = %w[background surface primary secondary accent text text_muted border].freeze
end
```

### Benefits Over Runtime Solutions

- **Zero JavaScript** — theme applies before any JS runs, no FOUC
- **No build step** — themes are additive CSS, no rebuild needed
- **All components automatically themed** — just reference `var(--color-*)`
- **Browser-native cascade** — respects specificity, inheritance, devtools inspection
- **Tailwind CSS v4 compatible** — use `bg-[var(--color-surface)]` instead of framework tokens

### Cross-Platform Translation

This pattern translates directly to other UI frameworks:

- **Flutter**: `ThemeData` with `ThemeExtension` — define synthwave color families, switch via `ThemeMode` or custom provider
- **egui/Rust**: `Visuals` struct with synthwave palette, switch via dropdown
- **Tailwind v4**: CSS-first config — define tokens as CSS variables, reference with `var(--color-*)`
- **Rails/Tailwind**: `stylesheet_link_tag "application"` after tailwind import for override cascade

### Implementation Found In

- Yayo Studio (Rails 8.1, PostgreSQL, Tailwind v4) — first project to use this pattern
- 6 system themes seeded: Synthwave '84, Dark, Light, Neon Nights, Sunset Drive, Ocean Deep
