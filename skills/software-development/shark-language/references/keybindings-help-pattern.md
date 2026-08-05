# Keybindings Help Pattern for TUI Applications

## Structured Help Command

When the user types `help`, show a multi-section formatted help instead of a single-line string:

```rust
app.add_system_message(
    "🦞 OpenShark Commands\n\
    \n\
    Chat commands:\n\
    • help              — Show this help\n\
    • tools             — List available tools\n\
    \n\
    Keybindings:\n\
    • Ctrl+C            — Copy / Quit (double-tap)\n\
    • Ctrl+T            — Cycle theme"
        .to_string(),
);
```

**Why:** Single-line help strings are unreadable. Multi-section with clear categories (chat, model, branch, keybindings) lets users find what they need instantly.

## Sidebar Shortcuts Panel

The sidebar should show ALL keybindings, not just a subset:

```rust
let shortcuts = vec![
    Line::from(vec![Span::styled("Ctrl+C  ", accent_style()), Span::styled("Copy / Quit", muted_style())]),
    Line::from(vec![Span::styled("Ctrl+L  ", accent_style()), Span::styled("Clear chat", muted_style())]),
    Line::from(vec![Span::styled("Ctrl+B  ", accent_style()), Span::styled("Toggle sidebar", muted_style())]),
    Line::from(vec![Span::styled("Ctrl+M  ", accent_style()), Span::styled("Model selector", muted_style())]),
    Line::from(vec![Span::styled("Ctrl+A  ", accent_style()), Span::styled("Autonomous mode", muted_style())]),
    Line::from(vec![Span::styled("Ctrl+T  ", accent_style()), Span::styled("Cycle theme", muted_style())]),
    Line::from(vec![Span::styled("↑/↓     ", accent_style()), Span::styled("Scroll", muted_style())]),
    Line::from(vec![Span::styled("PgUp/Dn ", accent_style()), Span::styled("Fast scroll", muted_style())]),
];
```

**Rule:** Every Ctrl+ binding must appear in both the `help` command AND the sidebar. Users discover keybindings through both paths.

## Discovery Principle

Keybindings that aren't shown anywhere might as well not exist. The user can't discover:
- Ctrl+A for autonomous mode
- Ctrl+T for theme cycling
- Ctrl+M for model selector

Unless they're listed in help AND sidebar. Every new keybinding gets added to both locations immediately.
