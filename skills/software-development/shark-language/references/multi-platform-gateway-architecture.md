# Multi-Platform Gateway Architecture

## Overview

OpenShark's gateway system normalizes events from Discord, Telegram, Slack, and Matrix into a single `DiscordEvent` format, allowing the existing `MessageRouter` to handle all platforms without duplication.

## Architecture

```
┌─────────┐  ┌──────────┐  ┌────────┐  ┌────────┐
│ Discord │  │ Telegram │  │ Slack  │  │ Matrix │
└────┬────┘  └────┬─────┘  └───┬────┘  └───┬────┘
     │            │            │           │
     └────────────┴────────────┴───────────┘
                  │
          ┌───────▼────────┐
          │ UnifiedRouter  │  ← converts all events to DiscordEvent
          └───────┬────────┘
                  │
          ┌───────▼────────┐
          │ MessageRouter  │  ← existing logic: memory, skills, tools
          └────────────────┘
```

## Components

### platform.rs — Unified Event Types

```rust
pub enum Platform { Discord, Telegram, Slack, Matrix }

pub enum PlatformEvent {
    UserMessage(UserMessage),
    Command(PlatformCommand),
    Ready { platform: Platform },
    Disconnected { platform: Platform },
}

pub struct UserMessage {
    pub platform: Platform,
    pub channel_id: String,
    pub user_id: String,
    pub username: String,
    pub content: String,
    pub reply_tx: mpsc::UnboundedSender<String>,
}
```

### unified_router.rs — Event Normalization

`UnifiedRouter` wraps `MessageRouter` and provides `handle_discord_event`, `handle_telegram_event`, `handle_slack_event`, `handle_matrix_event`. Each method:
1. Creates a `reply_tx`/`reply_rx` channel pair
2. Spawns a task to forward replies back to the platform
3. Converts the platform-specific event to `DiscordEvent::UserMessage`
4. Delegates to `MessageRouter::handle_event()`

**Key insight:** String-based IDs (Slack channel IDs, Matrix room IDs) are hashed to `u64` for `DiscordEvent` compatibility using `std::collections::hash_map::DefaultHasher`.

### Per-Platform Gateways

| File | Purpose |
|------|---------|
| `gateway/discord.rs` | serenity 0.12 — full implementation |
| `gateway/telegram.rs` | teloxide 0.17 — Bot API polling |
| `gateway/slack.rs` | slack-morphism stub — Socket Mode ready |
| `gateway/matrix.rs` | matrix-sdk stub — sync loop ready |

## Threading Model

Each gateway runs on a **dedicated OS thread** with its own tokio runtime. This is required because `MessageRouter` contains `rusqlite::Connection` (not `Send`/`Sync`).

```rust
std::thread::spawn(move || {
    let rt = tokio::runtime::Runtime::new().unwrap();
    rt.block_on(async {
        let mut event_rx = gateway::telegram::spawn_bot(config.clone());
        let mut unified = gateway::unified_router::UnifiedRouter::new(config).unwrap();
        while let Some(event) = event_rx.recv().await {
            unified.handle_telegram_event(event).await;
        }
    });
});
```

## Crate Selection Rationale

| Platform | Crate | Version | Why |
|----------|-------|---------|-----|
| Discord | `serenity` | 0.12 | Mature, official Bot API, excellent async support |
| Telegram | `teloxide` | 0.17 | Elegant DSL, Bot API polling/webhooks, very active |
| Slack | `slack-morphism` | 2.22 | Socket Mode + Web API, modern, maintained |
| Matrix | `matrix-sdk` | 0.17 | Official SDK, E2EE support, mature |

## SQLite Version Conflict (Resolved)

Adding `matrix-sdk` 0.17 pulled in `rusqlite` 0.37, conflicting with OpenShark's `rusqlite` 0.34 (different `libsqlite3-sys` versions).

**Fix:** Upgrade OpenShark's `rusqlite` to 0.37:
```bash
cargo remove rusqlite
cargo add rusqlite@0.37 --features=bundled,chrono
```

## Activation Checklist

### Telegram
1. Talk to @BotFather on Telegram → `/newbot` → get token
2. Add to config: `bot_token = "${TELEGRAM_BOT_TOKEN}"`
3. Set `enabled = true`
4. Optionally set `allowed_chats = [123456789]`

### Slack
1. Create app at api.slack.com
2. Enable Socket Mode → generate app-level token (`xapp-...`)
3. Install to workspace → get bot token (`xoxb-...`)
4. Add both tokens to config
5. Swap stub for full Socket Mode implementation in `gateway/slack.rs`

### Matrix
1. Create account on homeserver (or use existing)
2. Generate access token (Element → Settings → Help & About → Access Token)
3. Add `homeserver`, `user_id`, `access_token` to config
4. Swap stub for full sync loop in `gateway/matrix.rs`

## Future Work

- Implement full Slack Socket Mode connection
- Implement full Matrix sync loop with E2EE
- Add reply-back channels (currently stubs log replies instead of sending)
- Add platform-specific formatting (Markdown → platform-native format)
- Add platform-specific command prefixes
