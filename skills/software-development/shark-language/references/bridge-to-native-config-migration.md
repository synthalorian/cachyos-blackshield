# Bridge-to-Native Config Migration Pattern

Session: 2026-05-30, replacing HermesIntegrationConfig with native GatewayConfig in OpenShark.

## The Problem

You have a config struct that bridges to an external tool (Hermes, OpenClaw, etc.). You want to replace it with native config while:
1. Not breaking existing user configs on disk
2. Keeping the old struct for serde backward compatibility
3. Updating all code references
4. Updating the setup wizard

## The Pattern

### Step 1: Define Native Config

```rust
// src/gateway/mod.rs
#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct GatewayConfig {
    #[serde(default)]
    pub discord: DiscordConfig,
    #[serde(default)]
    pub telegram: TelegramConfig,
    #[serde(default)]
    pub mcp: McpGatewayConfig,
}
```

### Step 2: Replace Field in Config Struct

```rust
// src/config/mod.rs
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Config {
    // ... other fields ...
    #[serde(default)]
    pub gateway: crate::gateway::GatewayConfig,
    // Keep old struct for backward compat but don't use it
}

// Keep for serde — old configs on disk still deserialize
#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct HermesIntegrationConfig {
    #[serde(default)]
    pub enabled: bool,
    // ... old fields ...
}
```

### Step 3: Update ALL Default Constructors

Search and replace across the entire codebase:

```bash
# Find all places that construct Config with hermes_integration
grep -rn "hermes_integration:" src/ --include="*.rs"

# Replace with gateway:
sed -i 's/hermes_integration: crate::config::HermesIntegrationConfig::default(),/gateway: crate::gateway::GatewayConfig::default(),/g' src/**/*.rs
sed -i 's/hermes_integration: HermesIntegrationConfig::default(),/gateway: crate::gateway::GatewayConfig::default(),/g' src/**/*.rs
```

Files that typically need updating:
- `src/config/mod.rs` — Config::default()
- `src/router/mod.rs` — test helpers
- `src/self_improve/mod.rs` — test helpers
- `src/agent/mod.rs` — test helpers
- `src/config/setup.rs` — setup wizard

### Step 4: Update Setup Wizard

Replace the old setup section with the new native one:

```rust
// src/config/setup.rs
// OLD:
if prompt_bool("Enable Hermes integration", false)? {
    config.hermes_integration = HermesIntegrationConfig { ... };
}

// NEW:
let mut gateway = GatewayConfig::default();
if prompt_bool("Enable Discord bot", false)? {
    let token = prompt("Discord bot token:", None)?;
    gateway.discord = DiscordConfig {
        enabled: true,
        bot_token: if token.is_empty() { None } else { Some(token) },
        // ...
    };
}
config.gateway = gateway;
```

### Step 5: Update Display/Status Code

```rust
// OLD:
if config.hermes_integration.enabled {
    println!("✅ Hermes integration: enabled");
}

// NEW:
if config.gateway.discord.enabled {
    println!("✅ Discord gateway: enabled");
}
```

## Key Insight

The `#[serde(default)]` attribute on the new `gateway` field means:
- Old configs that DON'T have `[gateway]` section will deserialize with `GatewayConfig::default()`
- New configs that DO have `[gateway]` section will use those values
- You can safely remove `hermes_integration` from the struct later once all users have migrated

## Pitfall: Missing Test Helpers

Test helpers that construct `Config` with `..Default::default()` or explicit field initialization will break. Always grep for the old field name after making the change.

## Pitfall: TOML Serialization Order

When `Config` serializes to TOML, the new `gateway` section appears where the field is defined. If you want it at the bottom of the file for readability, put the field last in the struct.
