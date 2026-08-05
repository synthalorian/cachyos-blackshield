# Multi-Platform Gateway Reply Path Implementation

> Session: 2026-05-30 — Telegram reply fix, Slack/Matrix scaffolding, version bump

## Problem

The multi-platform gateway (Telegram, Slack, Matrix) had a "fire and forget" architecture:
- Events flowed FROM platform TO router
- But replies were only logged, never sent back
- `UnifiedRouter` spawned tasks that did `info!("reply: {}", reply)` instead of calling platform APIs

## Solution: ReplySender Pattern

Each platform gateway now returns a `(event_rx, ReplySender)` tuple from `spawn_bot()`.

### Telegram (Fully Working)

```rust
// src/gateway/telegram.rs
#[derive(Clone)]
pub struct TelegramReplySender {
    pub bot: Bot,  // teloxide::Bot is Clone (Arc wrapper)
}

impl TelegramReplySender {
    pub async fn send_message(&self, chat_id: i64, text: &str) {
        const MAX_LEN: usize = 4096;
        if text.len() > MAX_LEN {
            for chunk in text.chars().collect::<Vec<_>>().chunks(MAX_LEN) {
                let chunk_str: String = chunk.iter().collect();
                self.bot.send_message(ChatId(chat_id), chunk_str).await;
            }
        } else {
            self.bot.send_message(ChatId(chat_id), text).await;
        }
    }
}

pub fn spawn_bot(config: Config) -> (mpsc::UnboundedReceiver<TelegramEvent>, TelegramReplySender) {
    let (tx, rx) = mpsc::unbounded_channel();
    let token = config.gateway.telegram.bot_token.clone().unwrap_or_default();
    let bot = Bot::new(token);
    let reply_sender = TelegramReplySender { bot };

    tokio::spawn(async move {
        let bot = TelegramBot::new(config, tx.clone());
        if let Err(e) = bot.start().await { error!("Telegram bot error: {}", e); }
    });

    (rx, reply_sender)
}
```

### Slack (Scaffolded)

```rust
#[derive(Clone)]
pub struct SlackReplySender;

impl SlackReplySender {
    pub async fn send_message(&self, _channel_id: &str, _text: &str) {
        // TODO: Implement via Slack Web API (chat.postMessage)
        // Requires storing the Slack client from Socket Mode connection
    }
}
```

### Matrix (Scaffolded)

```rust
#[derive(Clone)]
pub struct MatrixReplySender;

impl MatrixReplySender {
    pub async fn send_message(&self, _room_id: &str, _text: &str) {
        // TODO: Implement via matrix-sdk room.send()
        // Requires storing the Matrix client and room handle from sync loop
    }
}
```

### UnifiedRouter Wiring

```rust
// main.rs — spawn thread
let (mut event_rx, reply_sender) = crate::gateway::telegram::spawn_bot(config.clone());

while let Some(event) = event_rx.recv().await {
    let mut unified = UnifiedRouter::new(router.config.clone())?;
    unified.handle_telegram_event(event, &reply_sender).await;
}
```

```rust
// unified_router.rs
pub async fn handle_telegram_event(
    &mut self,
    event: TelegramEvent,
    reply_sender: &TelegramReplySender,
) {
    match event {
        TelegramEvent::UserMessage { chat_id, ... } => {
            let (reply_tx, mut reply_rx): (mpsc::UnboundedSender<String>, mpsc::UnboundedReceiver<String>) =
                mpsc::unbounded_channel();  // explicit type annotation required!

            let sender = reply_sender.clone();
            tokio::spawn(async move {
                while let Some(reply) = reply_rx.recv().await {
                    sender.send_message(chat_id, &reply).await;
                }
            });

            self.inner.handle_event(DiscordEvent::UserMessage {
                channel_id: chat_id as u64,
                reply_tx,
                ...
            }).await;
        }
        ...
    }
}
```

## Critical Pitfall: Channel Type Inference

Without explicit type annotation on `mpsc::unbounded_channel()`, the compiler infers `UnboundedReceiver<str>` instead of `UnboundedReceiver<String>`, producing:

```
error[E0277]: the size for values of type `str` cannot be known at compilation time
```

**Fix:** Always annotate:
```rust
let (reply_tx, mut reply_rx): (mpsc::UnboundedSender<String>, mpsc::UnboundedReceiver<String>) =
    mpsc::unbounded_channel();
```

## Version Bump Checklist

1. Update `version = "x.y.z"` in `Cargo.toml`
2. Change `#[command(version = "0.1.0")]` → `#[command(version = env!("CARGO_PKG_VERSION"))]` in `src/main.rs`
3. Update `CHANGELOG.md`
4. `cargo build --release`
5. Verify: `./target/release/openshark --version`

## Files Modified (Session 2026-05-30)

| File | Change |
|------|--------|
| `src/gateway/telegram.rs` | Added `TelegramReplySender`, changed `spawn_bot` return type |
| `src/gateway/slack.rs` | Added `SlackReplySender`, token validation, `Ready` event |
| `src/gateway/matrix.rs` | Added `MatrixReplySender`, config validation, `Ready` event |
| `src/gateway/unified_router.rs` | Reply tasks now call platform APIs instead of logging |
| `src/main.rs` | Destructure tuple returns, pass senders to unified router |
| `Cargo.toml` | `version = "0.4.0"` |
| `src/main.rs` | `version = env!("CARGO_PKG_VERSION")` |
| `CHANGELOG.md` | Created with full history |
