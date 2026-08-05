# Discord Free-Form Chat Pattern

OpenShark's Discord bot can operate in two modes: free-form chat (default) or mention-only (legacy).

## Free-Form Chat Mode (Default)

The bot responds to **every message** in allowed channels without requiring `@mention` or `!shark` prefix.

**Config:**
```toml
[gateway.discord]
require_mention = false  # default
command_prefix = "!shark"
```

**Behavior:**
- All messages in allowed channels trigger a response
- Prefix commands (`!model`, `!tools`, etc.) still work
- Natural language memory queries still work
- Automatic memory recall runs on every message

**Use case:** General-purpose chatbot in dedicated channels. Users can just talk naturally.

## Mention-Only Mode (Legacy)

The bot only responds when explicitly mentioned or when using the prefix.

**Config:**
```toml
[gateway.discord]
require_mention = true
command_prefix = "!shark"
```

**Behavior:**
- Only responds to `@OpenShark` mentions
- Or messages starting with `!shark`
- All other messages are ignored

**Use case:** Bot coexists with humans in busy channels. Only responds when called.

## Per-Channel Override

Channel state tracks `require_mention` per-channel. Can be toggled at runtime:

```
/settings key:require_mention value:true   # Enable mention-only for this channel
!settings require_mention on               # Same via keyword command
```

## Implementation

In `discord.rs::Handler::message()`:

```rust
let should_respond = if discord_config.require_mention {
    // Legacy mode: need mention or prefix
    bot_mentioned || has_prefix
} else {
    // Free-form mode: respond to everything
    true
};
```

The `has_prefix` check still runs to strip the prefix for command parsing, but it doesn't gate the response.
