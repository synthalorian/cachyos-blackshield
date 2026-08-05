# Discord Slash Commands Implementation — OpenShark Gateway

Session: 2026-05-30, implementing full slash command suite for OpenShark's native Discord gateway.

## Architecture

```
Discord Gateway (serenity 0.12)
  │
  ├─ Handler::interaction_create() → Defer → Send DiscordEvent::SlashCommand
  │                                    │         via mpsc channel
  │                                    │
  │                                    ▼
  │                              MessageRouter::handle_slash_command()
  │                                    │
  │                                    ├─ Extract command name + options
  │                                    ├─ Match on command name
  │                                    ├─ Get/update ChannelState
  │                                    └─ Send response via reply_tx
  │
  └─ Handler collects reply_tx chunks → CreateInteractionResponseFollowup
```

## Deferred Response Pattern (Critical)

Discord requires an initial response within 3 seconds. For slow operations (LLM calls, agent tasks), **defer immediately**:

```rust
async fn interaction_create(&self, ctx: Context, interaction: Interaction) {
    if let Some(command) = interaction.as_command() {
        // 1. DEFER immediately — buys unlimited time
        let deferred = CreateInteractionResponse::Defer(
            CreateInteractionResponseMessage::new(),
        );
        command.create_response(&ctx.http, deferred).await?;

        // 2. Process the command (may take seconds)
        let (reply_tx, mut reply_rx) = mpsc::unbounded_channel::<String>();
        let event = DiscordEvent::SlashCommand { interaction, reply_tx };
        self.event_tx.send(event)?;

        // 3. Collect response chunks
        let mut full_response = String::new();
        while let Some(chunk) = reply_rx.recv().await {
            full_response.push_str(&chunk);
        }

        // 4. Send followup(s) — NOT create_response (already used for defer)
        for chunk in split_chunks(&full_response, 2000) {
            command.create_followup(
                &ctx.http,
                CreateInteractionResponseFollowup::new().content(chunk)
            ).await?;
        }
    }
}
```

**Key rule:** After deferring, you CANNOT call `create_response` again. Use `create_followup` for all output.

## Per-Channel State Management

Each Discord channel gets isolated state:

```rust
pub struct ChannelState {
    pub history: Vec<Message>,      // system + user + assistant messages
    pub model: String,              // active model name
    pub provider: Provider,         // provider instance for this model
    pub custom_system_prompt: Option<String>,
    pub typing_indicator: bool,
    pub max_history: usize,
    pub require_mention: bool,
}
```

Storage:
```rust
pub struct ChannelStateStore {
    states: Arc<Mutex<HashMap<u64, ChannelState>>>,
    config: Config,
}
```

**Why `std::sync::Mutex` not `tokio::sync::RwLock`:** ChannelState operations are fast (HashMap insert/lookup, Vec push). No async I/O inside the critical section. `std::sync::Mutex` is simpler and avoids async lifetime issues.

## Command Registry

Register commands in `ready()` event:

```rust
async fn ready(&self, ctx: Context, ready: Ready) {
    let guild_ids = &config.guild_ids;
    if guild_ids.is_empty() {
        Command::set_global_commands(&ctx.http, commands).await?;
    } else {
        for guild_id in guild_ids {
            guild_id.set_commands(&ctx.http, commands).await?;
        }
    }
}
```

**Global vs Guild commands:**
- Global: visible everywhere, takes up to 1 hour to propagate
- Guild: instant, only visible in that guild
- Use guild commands for development, global for production

## Full Command List (14 commands)

| Command | Options | Description |
|---------|---------|-------------|
| `/chat` | `message` (required) | Chat with OpenShark |
| `/new` | — | Start fresh conversation |
| `/system` | `prompt` (required) | Set custom system prompt |
| `/reset` | — | Reset to defaults |
| `/model` | `name` (optional) | List or switch model |
| `/models` | — | Detailed model list |
| `/agent` | `task` (required) | Run autonomous task |
| `/tools` | — | List available tools |
| `/tool` | `name`, `args` (both required) | Execute tool directly |
| `/memory` | `query` (required) | Search conversation memory |
| `/remember` | `fact` (required) | Save fact to memory |
| `/status` | — | Bot status for this channel |
| `/stats` | — | Usage statistics |
| `/settings` | `key`, `value` (both optional) | View/change settings |
| `/help` | — | Command reference |

## Extracting Options

```rust
fn get_string_option<'a>(
    options: &'a [CommandDataOption],
    name: &str,
) -> Option<&'a str> {
    options
        .iter()
        .find(|o| o.name == name)
        .and_then(|o| match &o.value {
            CommandDataOptionValue::String(s) => Some(s.as_str()),
            _ => None,
        })
}
```

## Threading Model

The Discord gateway runs on a **dedicated OS thread** with its own tokio runtime:

```rust
std::thread::spawn(move || {
    let rt = tokio::runtime::Runtime::new().unwrap();
    rt.block_on(async {
        let mut event_rx = spawn_bot(config.clone());
        let mut router = MessageRouter::new(config).unwrap();
        while let Some(event) = event_rx.recv().await {
            router.handle_event(event).await;
        }
    });
});
```

**Why not `tokio::spawn`:** `MessageRouter` contains `rusqlite::Connection` which uses `RefCell` internally — not `Send`/`Sync`. A dedicated thread with its own runtime avoids this constraint entirely.

## Message Splitting

Discord has a 2000-character limit per message. Split intelligently:

```rust
fn split_chunks(text: &str, max_len: usize) -> Vec<String> {
    text.chars()
        .collect::<Vec<_>>()
        .chunks(max_len)
        .map(|c| c.iter().collect())
        .collect()
}
```

For better UX, split on paragraph boundaries when possible rather than hard character boundaries.

## Wiring into main.rs

```rust
if config.gateway.discord.enabled {
    let discord_config = config.clone();
    std::thread::spawn(move || {
        let rt = tokio::runtime::Runtime::new().unwrap();
        rt.block_on(async {
            let mut event_rx = gateway::discord::spawn_bot(discord_config.clone());
            let mut router = gateway::message_router::MessageRouter::new(discord_config).unwrap();
            while let Some(event) = event_rx.recv().await {
                router.handle_event(event).await;
            }
        });
    });
}
```

## Common Pitfalls

1. **Forgetting to defer:** Without defer, commands that take >3 seconds (any LLM call) will show "This interaction failed" in Discord.
2. **Using `create_response` after defer:** Always use `create_followup` after deferring.
3. **Move closure issues with `flat_map` + `move`:** When iterating config providers inside a closure, clone values before the closure instead of capturing by move.
4. **rusqlite `Send` issue:** Don't try to make `MessageRouter` `Send`. Use a dedicated thread instead.
5. **Global command propagation:** Global commands take up to 1 hour. Use guild commands for testing.

## Files

- `src/gateway/commands.rs` — Command definitions and registration
- `src/gateway/discord.rs` — Serenity event handler, defer/followup logic
- `src/gateway/message_router.rs` — Slash command handlers, chat routing
- `src/gateway/channel_state.rs` — Per-channel state management
- `src/gateway/mod.rs` — Module exports, config structs
- `src/main.rs` — Discord gateway spawn on TUI startup
