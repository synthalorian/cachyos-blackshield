# TUI ASCII Art Branding

Techniques for rendering stylized text logos in ratatui TUIs.

## Block Character ASCII Art

Use full block characters (`█`) for solid fills and spaces for background. This creates high-contrast art that renders cleanly in any terminal.

```rust
let ascii_art = r#" ██████  ██████  ███████ ██   ██ ███████  █████  ██████  ██   ██
██   ██ ██   ██ ██      ██  ██  ██      ██   ██ ██   ██ ██  ██
███████ ██████  █████   █████   █████   ███████ ██████  █████
██   ██ ██      ██      ██  ██  ██      ██   ██ ██   ██ ██  ██
██   ██ ██      ███████ ██   ██ ██      ██   ██ ██   ██ ██   ██"#;
```

**Key rules for readability:**
- Every letter must be the SAME width (e.g., 7 chars) for consistent spacing
- Use spaces between letters, not block characters
- Avoid ambiguous shapes — an `O` should look like an `O`, not a `D`
- Test by squinting at it — if you can't read it, neither can the user
- No trailing spaces on lines (ratatui's `Wrap { trim: true }` strips them)

## Coloring ASCII Art in ratatui

The chat rendering loop can detect ASCII art lines and apply a special color:

```rust
for content_line in msg.content.lines() {
    let line_style = if msg.role == "system" && content_line.contains('█') {
        Style::default()
            .fg(current_theme().border_unfocused)  // purple
            .add_modifier(Modifier::BOLD)
    } else {
        content_style
    };
    lines.push(Line::from(vec![Span::styled(content_line, line_style)]));
}
```

**Why `border_unfocused` for purple:** The synthwave84 theme's `border_unfocused` is `Rgb(147, 51, 234)` — a vibrant purple that matches the synthwave aesthetic. The `accent` color is cyan, which is wrong for purple branding.

## Sidebar Header with Emoji

Add an emoji prefix to the sidebar header:

```rust
let mut header_lines = vec![
    Line::from(vec![
        Span::styled("🦞 ", shark_style()),
        Span::styled(agent_name, highlight_style()),
        Span::styled(format!(" v{}", crate::VERSION), muted_style()),
    ]),
];
```

**Note:** If the config `emoji` field is empty (user removed it), hardcode the desired emoji in the TUI rendering rather than reading from config. The TUI branding is independent of the agent's configurable emoji.

## Removing Tagline from Sidebar

Make tagline conditional so empty taglines don't render a blank line:

```rust
if !app.config.agent.tagline.is_empty() {
    header_lines.push(Line::from(vec![
        Span::styled(app.config.agent.tagline.clone(), muted_style()),
    ]));
}
```

## File Locations for TUI Branding

| Element | File | Line ~ |
|---------|------|--------|
| Sidebar header (name, version, emoji) | `src/tui/mod.rs` | `draw_sidebar()` ~1595 |
| Sidebar block title (border) | `src/tui/mod.rs` | `draw_sidebar()` ~1571 |
| Welcome message (ASCII art + greeting) | `src/tui/mod.rs` | `run()` ~675 |
| ASCII art color detection | `src/tui/mod.rs` | `draw_chat_area()` ~1780 |
| Default identity values | `src/config/mod.rs` | `AgentIdentity::default()` ~52 |
| Setup wizard prompts | `src/config/setup.rs` | `run()` ~54 |
| Theme colors | `src/tui/theme.rs` | `Theme::synthwave84()` ~45 |
