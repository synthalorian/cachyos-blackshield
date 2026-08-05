# TUI Branding Customization — File Locations

Quick reference for changing OpenShark's TUI branding: display name, emoji, tagline, greeting, version, ASCII art, and colors.

## Identity / Config Layer

**`src/config/mod.rs`** — `AgentConfig` struct fields:
- `display_name: String` — shown in sidebar header, chat messages, streaming indicator
- `emoji: String` — sidebar border title, sidebar header, welcome message
- `tagline: String` — shown below name in sidebar
- `greeting: String` — welcome message prompt line

**`src/config/setup.rs`** — Setup wizard prompts for these fields (lines ~56-59)

**`src/agent/soul.rs`** — `AgentSoul` methods:
- `status_line()` — `emoji display_name — role`
- `welcome_message()` — `\nemoji display_name\ntagline\n\ngreeting`

## TUI Rendering Layer

**`src/tui/mod.rs`** — All rendering happens here (~1900 lines). Key functions:

### Sidebar Header (`draw_sidebar()`, ~line 1569)
```rust
// Border title (top-left of sidebar border):
.title(format!(" {} ", app.config.agent.emoji))

// Header content (centered, 2 lines):
Line::from(vec![
    Span::styled(format!(" {} ", agent_emoji), shark_style()),
    Span::styled(agent_name, highlight_style()),
    Span::styled(format!(" v{}", crate::VERSION), muted_style()),
]),
Line::from(vec![
    Span::styled(app.config.agent.tagline.clone(), muted_style()),
]),
```

### Welcome Message Injection (~line 675)
```rust
let welcome = format!(
    "\n{} {}\n{}\n\n{}",
    config.agent.emoji,
    config.agent.display_name,
    config.agent.tagline,
    config.agent.greeting
);
app.add_system_message(welcome);
```

### Chat Area Rendering (`draw_chat_area()`, ~line 1729)
- System messages use `ℹ ` prefix + `muted_style()`
- The `█` character detection (line 1782) applies `accent` color + BOLD for ASCII art lines
- Assistant streaming uses `🦞 ` prefix + `shark_style()`

## Theme / Color Layer

**`src/tui/theme.rs`** — `Theme` struct + 24 presets. Default is `synthwave84`:
- `background: Color::Rgb(26, 0, 51)` — deep purple
- `accent: Color::Rgb(34, 211, 238)` — cyan
- `highlight: Color::Rgb(253, 224, 71)` — yellow
- `border_unfocused: Color::Rgb(147, 51, 234)` — purple

Style helpers (all read from `current_theme()` dynamically):
- `shark_style()` — `accent` color + BOLD
- `highlight_style()` — `highlight` color + BOLD
- `accent_style()` — `accent` color + BOLD
- `muted_style()` — `muted` color

## Common Branding Changes

| Change | File(s) | Notes |
|--------|---------|-------|
| Display name | `config/mod.rs` default, `agent/soul.rs` | Also in setup wizard |
| Emoji | `config/mod.rs` default, `agent/soul.rs` | Sidebar title + header |
| Tagline | `config/mod.rs` default, `agent/soul.rs` | |
| Greeting | `config/mod.rs` default, `agent/soul.rs` | |
| Version | `Cargo.toml` | Uses `env!("CARGO_PKG_VERSION")` |
| Sidebar layout | `tui/mod.rs::draw_sidebar()` | ~line 1569 |
| Welcome message | `tui/mod.rs` (~line 675), `agent/soul.rs` | Injected as system message |
| Chat message styling | `tui/mod.rs::draw_chat_area()` | ~line 1729 |
| ASCII art color | `tui/mod.rs` line 1782 | `█` detection → `accent` + BOLD |
| Theme colors | `tui/theme.rs` | Add preset or modify default |

## ASCII Art in Welcome Message

To render ASCII art in the chat area with theme-aware coloring:
1. Include `█` or block characters in the welcome message content
2. The chat renderer detects `content_line.contains('█')` and applies `accent` + BOLD
3. Alternatively, inject styled spans directly (requires modifying `draw_chat_area()`)

## User-Specific Colors

The user (synth) has referenced `rat_purple_1` as a desired color for ASCII art. This appears to be a custom purple shade. If adding to the theme system:
1. Add a new `Color` field to `Theme` struct
2. Set the RGB value in `synthwave84()` and other relevant presets
3. Add a style helper function
4. Use in `draw_chat_area()` for ASCII art lines

**Open question:** Exact RGB for `rat_purple_1` — user has not specified. Candidate: `#8f00ff` / `Rgb(143, 0, 255)`.
