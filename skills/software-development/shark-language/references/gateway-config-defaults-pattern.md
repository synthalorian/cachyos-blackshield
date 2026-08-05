# Gateway Config Defaults Pattern

## Problem

When a project supports multiple external platforms (Discord, Telegram, Slack, Matrix, MCP), the default config often only includes the primary platform. Users must hand-write config sections for additional platforms, which is error-prone and discourages adoption.

## Solution

Include **all platforms pre-configured with env var placeholders** in `Config::default()`:

```rust
impl Default for Config {
    fn default() -> Self {
        Self {
            // ... other fields ...
            gateway: GatewayConfig {
                discord: DiscordConfig {
                    enabled: false,
                    bot_token: "${DISCORD_BOT_TOKEN}".to_string(),
                    // ... other discord fields ...
                },
                telegram: TelegramConfig {
                    enabled: false,
                    bot_token: "${TELEGRAM_BOT_TOKEN}".to_string(),
                    allowed_chats: vec![],
                    require_command_prefix: false,
                },
                slack: SlackConfig {
                    enabled: false,
                    bot_token: "${SLACK_BOT_TOKEN}".to_string(),
                    app_token: "${SLACK_APP_TOKEN}".to_string(),
                    allowed_channels: vec![],
                },
                matrix: MatrixConfig {
                    enabled: false,
                    homeserver: "https://matrix.org".to_string(),
                    access_token: "${MATRIX_ACCESS_TOKEN}".to_string(),
                    allowed_rooms: vec![],
                },
                mcp: McpGatewayConfig {
                    enabled: false,
                    servers: vec![],
                },
            },
            // ...
        }
    }
}
```

## Env Var Resolution

Resolve `${VAR}` syntax at config load time:

```rust
fn resolve_gateway_token(token: &str) -> String {
    if token.starts_with("${") && token.ends_with("}") {
        let var_name = &token[2..token.len()-1];
        std::env::var(var_name).unwrap_or_else(|_| token.to_string())
    } else {
        token.to_string()
    }
}

// In Config::load():
config.gateway.discord.bot_token = resolve_gateway_token(&config.gateway.discord.bot_token);
config.gateway.telegram.bot_token = resolve_gateway_token(&config.gateway.telegram.bot_token);
// ... etc for all platforms
```

## Generated Default Config

When a user runs the app for the first time, the generated `config.toml` includes:

```toml
[gateway.discord]
enabled = false
bot_token = "${DISCORD_BOT_TOKEN}"
application_id = "${DISCORD_APP_ID}"
guild_ids = []
allowed_channels = []
require_mention = false
command_prefix = "!shark"

[gateway.telegram]
enabled = false
bot_token = "${TELEGRAM_BOT_TOKEN}"
allowed_chats = []
require_command_prefix = false

[gateway.slack]
enabled = false
bot_token = "${SLACK_BOT_TOKEN}"
app_token = "${SLACK_APP_TOKEN}"
allowed_channels = []

[gateway.matrix]
enabled = false
homeserver = "https://matrix.org"
access_token = "${MATRIX_ACCESS_TOKEN}"
allowed_rooms = []

[gateway.mcp]
enabled = false
servers = []
```

## Activation Flow

1. **Export env vars:** `export DISCORD_BOT_TOKEN="..."`
2. **Enable platform:** Set `enabled = true` in config
3. **Restart app** — no other config needed

## Benefits

- **Zero hand-written config** for new platforms — just env vars + flip switch
- **12-factor compliance** — secrets in env, config in files
- **Safe to share** — config files contain no actual tokens
- **Discoverability** — users see all available platforms immediately
- **Setup wizard synergy** — wizard can fill in values interactively as alternative to env vars

## Pitfall: Struct Completeness

When adding a new platform config, ensure ALL fields in the struct have defaults. If a field is missing from `Default`, the config won't compile:

```rust
// ERROR: missing field `whatsapp` in struct `GatewayConfig`
// Even if whatsapp is unused, the field must be present:
whatsapp: WhatsAppConfig::default(),
```

## Integration with Setup Wizard

The setup wizard should offer BOTH paths:
1. **Env var mode** (default): "Export these env vars and set enabled = true"
2. **Interactive mode**: "Enter tokens now and I'll write them to config"

```rust
// setup.rs
fn prompt_gateway_config() -> GatewayConfig {
    let use_env = Confirm::new("Use environment variables for tokens?")
        .with_default(true)
        .prompt()
        .unwrap_or(true);
    
    if use_env {
        // Return config with ${VAR} placeholders
        GatewayConfig::default()
    } else {
        // Interactive: prompt for each token
        GatewayConfig {
            discord: DiscordConfig {
                enabled: true,
                bot_token: Text::new("Discord bot token:").prompt().unwrap(),
                // ...
            },
            // ...
        }
    }
}
```
