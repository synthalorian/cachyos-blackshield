# Harness vs Agent Identity Separation

OpenShark has two distinct identity concepts that must never be conflated:

## Harness Identity (Hardcoded)

The **app itself** — what users see as "the software."

- **Top-left sidebar header**: `🦞 openshark v1.0.0`
- **Hardcoded in source** (`src/tui/mod.rs`)
- **Never configurable** — same for every user
- **Represents the product brand**

```rust
// src/tui/mod.rs — HARDCODED, not from config
Line::from(vec![
    Span::styled("🦞 ", shark_style()),
    Span::styled("openshark", highlight_style()),
    Span::styled(format!(" v{}", crate::VERSION), muted_style()),
]),
```

## Agent Identity (User-Configurable)

The **AI personality** — who the user is talking to.

- **Chat bubbles**: `{emoji} {display_name}` (e.g. `🎹🦞 synthclaw`)
- **Streaming indicator**: `{emoji} {display_name}`
- **Loaded from config** (`~/.config/openshark/config.toml`)
- **Fully customizable** per user

```rust
// src/tui/mod.rs — from config.agent
let agent_emoji = if app.config.agent.emoji.is_empty() {
    "🦞"  // fallback for blank slate users
} else {
    &app.config.agent.emoji
};
(shark_style(), text_style(), format!("{} ", agent_emoji), agent_name.to_string())
```

## Default vs Personal Config

**Default (blank slate for new users):**
```toml
user_name = "user"

[agent]
name = "openshark"
display_name = "OpenShark"
emoji = "🦞"
greeting = ""  # no startup message
```

**synth's personal config:**
```toml
user_name = "synth"

[agent]
name = "synthclaw"
display_name = "synthclaw"
emoji = "🎹🦞"
greeting = ""  # no startup message
```

## Key Rule

> The harness name stays constant. The agent identity is the user's.

Never use `config.agent.display_name` or `config.agent.emoji` for the app header. Never hardcode the agent name in chat bubbles. Keep these boundaries clean.

## Files Involved

| File | Purpose |
|------|---------|
| `src/tui/mod.rs` (sidebar header) | Hardcoded harness branding |
| `src/tui/mod.rs` (chat bubbles) | Configurable agent emoji + name |
| `src/tui/mod.rs` (streaming indicator) | Configurable agent emoji + name |
| `src/config/mod.rs` (`AgentIdentity::default()`) | Blank slate defaults |
| `~/.config/openshark/config.toml` | User's personal identity |
