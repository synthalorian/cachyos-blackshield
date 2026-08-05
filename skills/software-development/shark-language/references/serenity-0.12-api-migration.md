# Serenity 0.12 Discord Bot API — Migration from 0.11

Session: 2026-05-30, building native Discord gateway for OpenShark with serenity 0.12.5.

## Module Path Changes

Serenity 0.12 restructured its public API. Many types moved to `serenity::all::*`:

```rust
// OLD (0.11) — module paths are private in 0.12
use serenity::model::application::interaction::Interaction;
use serenity::model::application::interaction::Interaction::ApplicationCommand;
use serenity::model::application::command::Command;
use serenity::model::application::CommandOptionType;

// NEW (0.12) — use serenity::all::*
use serenity::all::{Interaction, Command, CommandOptionType, GuildId};
```

## Interaction Type Changes

```rust
// OLD (0.11)
if let Interaction::ApplicationCommand(cmd) = interaction { ... }

// NEW (0.12) — use .as_command() / .command() methods
if let Some(cmd) = interaction.as_command() { ... }      // borrow
if let Some(cmd) = interaction.command() { ... }         // consume
```

## CreateInteractionResponse Builder

```rust
// OLD (0.11) — CreateInteractionResponse::new() existed
let builder = CreateInteractionResponse::new()
    .kind(InteractionResponseType::ChannelMessageWithSource)
    .message(data);

// NEW (0.12) — enum variants with embedded data
let data = CreateInteractionResponseMessage::new().content("Hello");
let builder = CreateInteractionResponse::Message(data);
// or for deferring:
let builder = CreateInteractionResponse::Defer(data);
```

## CreateCommandOption Builder

```rust
// OLD (0.11) — add_option took a closure
CreateCommand::new("chat")
    .description("Chat with bot")
    .add_option(|opt| opt
        .name("message")
        .description("Your message")
        .kind(CommandOptionType::String)
        .required(true)
    );

// NEW (0.12) — CreateCommandOption::new(kind, name, description)
use serenity::all::{CreateCommand, CreateCommandOption, CommandOptionType};

CreateCommand::new("chat")
    .description("Chat with bot")
    .add_option(
        CreateCommandOption::new(CommandOptionType::String, "message", "Your message")
            .required(true)
    );
```

## CommandDataOptionValue Access

```rust
// OLD (0.11) — .value.as_ref().and_then(|v| v.as_str())
let content = cmd.data.options
    .iter()
    .find(|o| o.name == "message")
    .and_then(|o| o.value.as_ref())
    .and_then(|v| v.as_str());

// NEW (0.12) — .value is CommandDataOptionValue, match on it directly
let content = cmd.data.options
    .iter()
    .find(|o| o.name == "message")
    .and_then(|o| match &o.value {
        CommandDataOptionValue::String(s) => Some(s.as_str()),
        _ => None,
    });
```

## EventHandler Signature

```rust
// Unchanged — still uses #[async_trait]
#[async_trait]
impl EventHandler for Handler {
    async fn message(&self, ctx: Context, msg: Message) { ... }
    async fn interaction_create(&self, ctx: Context, interaction: Interaction) { ... }
    async fn ready(&self, ctx: Context, ready: Ready) { ... }
}
```

## Common Pitfalls

1. **Private modules** — `serenity::model::application::interaction` and `serenity::model::application::command` are private. Always use `serenity::all::*`.
2. **CreateInteractionResponse::new() removed** — Use enum variants `CreateInteractionResponse::Message(data)`, `CreateInteractionResponse::Defer(data)`.
3. **CommandDataOptionValue is not Option** — Don't call `.as_ref()` on it. Match on the enum directly.
4. **GuildId::new() takes u64** — Still true in 0.12, but verify: `GuildId::new(guild_id_u64)`.

## Cargo.toml Feature Flags

```toml
[dependencies]
serenity = { version = "0.12", features = ["client", "gateway", "model", "cache", "rustls_backend"] }
```

Features needed for a typical bot:
- `client` — Client builder and EventHandler
- `gateway` — WebSocket gateway connection
- `model` — Discord data models (Message, Interaction, etc.)
- `cache` — In-memory cache for guilds, channels, users
- `rustls_backend` — TLS via rustls (no native TLS dependency)

## Full Minimal Example

```rust
use serenity::async_trait;
use serenity::all::{Context, EventHandler, GatewayIntents, Interaction, Message, Ready};
use serenity::client::Client;

struct Handler;

#[async_trait]
impl EventHandler for Handler {
    async fn message(&self, ctx: Context, msg: Message) {
        if msg.content == "!ping" {
            let _ = msg.channel_id.say(&ctx.http, "Pong!").await;
        }
    }

    async fn ready(&self, _ctx: Context, ready: Ready) {
        println!("Connected as {}", ready.user.name);
    }
}

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    let token = std::env::var("DISCORD_TOKEN")?;
    let intents = GatewayIntents::GUILD_MESSAGES | GatewayIntents::MESSAGE_CONTENT;
    
    let mut client = Client::builder(&token, intents)
        .event_handler(Handler)
        .await?;
    
    client.start().await?;
    Ok(())
}
```
