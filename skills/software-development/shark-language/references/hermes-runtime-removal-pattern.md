# Hermes Runtime Removal Pattern

How to remove a runtime dependency bridge while preserving setup/config transfer logic.

## The Scenario

OpenShark had `src/hermes/` — a full module that bridged to Hermes Agent at runtime:
- `mod.rs` — discovery, status, initialization
- `gateway.rs` — Discord/Telegram platform adapters (shell-outs to `hermes` CLI)
- `skills.rs` — load Hermes skills as prompt extensions
- `mcp.rs` — MCP server discovery and tool calling (Hermes bridge)
- `memory_bridge.rs` — cross-session memory sync

The user wants OpenShark to be **standalone** — no runtime dependency on Hermes. But the setup wizard should still offer to import config from Hermes/OpenClaw.

## The Rule

**Remove runtime dependency. Preserve setup/config compatibility.**

## Step-by-Step

### 1. Remove the runtime module
```bash
rm -rf src/hermes/
```

### 2. Remove `mod hermes;` from main.rs
```rust
// src/main.rs
// REMOVE: mod hermes;
```

### 3. Remove Hermes CLI subcommand
```rust
// src/main.rs — Commands enum
// REMOVE:
Hermes {
    #[arg(default_value = "status")]
    cmd: String,
},

// src/main.rs — match arm
// REMOVE entire Some(Commands::Hermes { cmd }) => { ... } block
```

### 4. Remove Hermes help text
```rust
// REMOVE from help output:
println!("  openshark hermes status      - Show integration status");
println!("  openshark hermes skills      - List available skills");
println!("  openshark hermes platforms   - Show connected platforms");
```

### 5. KEEP config fields and setup wizard

The `HermesIntegrationConfig` struct stays in `config/mod.rs`:
```rust
#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct HermesIntegrationConfig {
    pub enabled: bool,
    pub hermes_home: Option<String>,
    pub gateway_enabled: bool,
    pub discord_enabled: bool,
    // ... etc
}
```

The setup wizard in `config/setup.rs` keeps the Hermes section:
```rust
// ── Hermes Integration ──
if prompt_bool("Enable Hermes integration", false)? {
    let hermes_home = prompt("Hermes home directory:", Some("~/.hermes"))?;
    config.hermes_integration = HermesIntegrationConfig {
        enabled: true,
        hermes_home: Some(hermes_home),
        // ...
    };
}
```

### 6. REMOVE runtime references in other modules

Find all `hermes::` calls and remove:
```bash
grep -rn "hermes::" src/ --include="*.rs"
```

Common locations:
- `main.rs` — CLI command handlers
- `agent/mod.rs` — test Config constructors with `hermes_integration`
- `router/mod.rs` — test Config constructors
- `self_improve/mod.rs` — test Config constructors
- `security/mod.rs` — sensitive path list (may reference `~/.hermes`)

### 7. KEEP sensitive path protection

If `~/.hermes` is in the security sensitive paths list, keep it — it's still a sensitive directory even without runtime integration:
```rust
// src/security/mod.rs
let sensitive_paths = vec![
    "~/.ssh",
    "~/.hermes",  // KEEP — sensitive config directory
    "/etc/shadow",
];
```

### 8. Add OpenClaw transfer to setup (optional)

If the user wants OpenClaw config import too:
```rust
// ── OpenClaw Integration ──
if prompt_bool("Import from OpenClaw", false)? {
    let claw_config_path = prompt("OpenClaw config path:", Some("~/.config/openclaw/config.yaml"))?;
    // Parse and merge model shortcuts, provider preferences
}
```

## Verification

```bash
# Should compile with zero errors
cargo check

# All tests should pass
cargo test

# Hermes commands should be gone
 cargo run -- hermes status  # Should fail: unknown command
```

## Why This Pattern

- **Config compatibility**: Existing users' `config.toml` still loads (serde default handles missing fields)
- **Setup transfer**: Users can still migrate from Hermes/OpenClaw during setup
- **No runtime dependency**: OpenShark runs standalone without Hermes installed
- **Future native replacements**: The gateway/MCP slots can be filled with native implementations (serenity, native MCP client) without config changes

## Related

- `references/standalone-setup-vs-integration-pattern.md` — When to build standalone vs integrated
- `references/setup-config-transfer-spec.md` — Config transfer from Hermes/OpenClaw
