# Multi-Theme TUI System Architecture

Dynamic theme system for ratatui-based TUIs with preset definitions, global state, and runtime switching.

## Design

```
┌─────────────────────────────────────────┐
│  Theme (struct with 18 Color fields)    │
│  ├── name: String                       │
│  ├── background, foreground             │
│  ├── accent, accent_secondary           │
│  ├── highlight, muted                   │
│  ├── error, success                     │
│  ├── border_focused, border_unfocused   │
│  ├── title                              │
│  ├── selected_bg, selected_fg           │
│  ├── row_alt_bg                         │
│  ├── tool, user_name, agent_name        │
│  └── 19 preset constructors             │
└─────────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────┐
│  static CURRENT_THEME: RwLock<Option<Theme>>  │
│  set_theme() / current_theme()          │
└─────────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────┐
│  Style helpers (dynamic, theme-aware)   │
│  bg_style(), text_style(), accent_style()│
│  All read from current_theme()          │
└─────────────────────────────────────────┘
```

## Implementation

### Theme Struct

```rust
#[derive(Debug, Clone, PartialEq)]
pub struct Theme {
    pub name: String,
    pub background: Color,
    pub foreground: Color,
    pub accent: Color,
    pub accent_secondary: Color,
    pub highlight: Color,
    pub muted: Color,
    pub error: Color,
    pub success: Color,
    pub border_focused: Color,
    pub border_unfocused: Color,
    pub title: Color,
    pub selected_bg: Color,
    pub selected_fg: Color,
    pub row_alt_bg: Color,
    pub tool: Color,
    pub user_name: Color,
    pub agent_name: Color,
}
```

Note: `Color` from `ratatui::style` does NOT implement serde. Don't add Serialize/Deserialize to Theme unless you build a custom wrapper or store theme by name in config.

### Global State

```rust
use std::sync::RwLock;

static CURRENT_THEME: RwLock<Option<Theme>> = RwLock::new(None);

pub fn set_theme(theme: Theme) {
    if let Ok(mut guard) = CURRENT_THEME.write() {
        *guard = Some(theme);
    }
}

pub fn current_theme() -> Theme {
    if let Ok(guard) = CURRENT_THEME.read() {
        guard.clone().unwrap_or_default()
    } else {
        Theme::default()
    }
}
```

### Style Helpers (Dynamic)

All style helpers read from `current_theme()` instead of hardcoded constants:

```rust
pub fn bg_style() -> Style {
    let t = current_theme();
    Style::default().bg(t.background)
}

pub fn accent_style() -> Style {
    let t = current_theme();
    Style::default()
        .fg(t.accent)
        .bg(t.background)
        .add_modifier(Modifier::BOLD)
}
// ... etc for all 15+ style helpers
```

### Presets

Each preset is a constructor method on `Theme`:

```rust
impl Theme {
    pub fn synthwave84() -> Self { /* ... */ }
    pub fn catppuccin() -> Self { /* ... */ }
    pub fn tokyo_night() -> Self { /* ... */ }
    // ... 19 total
    
    pub fn all_presets() -> Vec<Self> { vec![...] }
    pub fn by_name(name: &str) -> Option<Self> { ... }
    pub fn names() -> Vec<String> { ... }
}
```

## Config Integration

Store theme by name (string) in config, not the full Theme:

```rust
// config/mod.rs
#[serde(default = "default_theme")]
pub theme: String,

fn default_theme() -> String { "synthwave84".to_string() }
```

Initialize on TUI startup:
```rust
pub async fn run(config: Config) -> Result<()> {
    if let Some(theme) = Theme::by_name(&config.theme) {
        set_theme(theme);
    }
    // ...
}
```

## TUI Keybind

`Ctrl+T` cycles through themes:
```rust
KeyCode::Char('t') if key.modifiers.contains(KeyModifiers::CONTROL) => {
    let names = Theme::names();
    let current = current_theme().name;
    let idx = names.iter().position(|n| n == &current).unwrap_or(0);
    let next_idx = (idx + 1) % names.len();
    let next_name = names[next_idx].clone();
    if let Some(theme) = Theme::by_name(&next_name) {
        set_theme(theme);
        app.add_system_message(format!("🎨 Theme: {}", next_name));
    }
}
```

## Theme Sources

All 19 presets are derived from Omarchy terminal themes:
- **Core**: synthwave84 (default), white, vantablack, matte-black
- **Omarchy dark**: catppuccin, tokyo-night, gruvbox, nord, everforest, kanagawa, rose-pine, miasma, ethereal, ristretto, osaka-jade
- **Omarchy light**: lumon, flexoki-light
- **Specialty**: hackerman, retro-82

Color values are extracted from `~/.local/share/omarchy/themes/*/colors.toml` and mapped to the 18 Theme fields.

## Migration from Static Theme

When converting from hardcoded colors to dynamic themes:

1. Replace `const RAT_*: Color` with `current_theme().field`
2. Update all `Style::default().fg(RAT_*)` to `fg(current_theme().field)`
3. Add `#[allow(dead_code)]` to old constant definitions during transition
4. Remove constants once all consumers use dynamic helpers
5. Add `theme` field to Config and all test constructors
