# Swarm Enabled Gate Removal Pattern

**Problem:** The `swarm.enabled` config flag was used as a hard gate — both TUI (`/swarm init`) and CLI (`openshark swarm init`) checked `config.swarm.enabled` and blocked initialization if `false`. Since the default was `enabled = false`, users had to manually edit `~/.config/openshark/config.toml` before they could use swarm at all. This created friction and confusion — users would press `Ctrl+W` (toggle swarm UI), run `/swarm init`, and get "Swarm mode is disabled in config."

**Fix:** Remove the `enabled` gate from `/swarm init`. If the user explicitly runs `/swarm init <prompt>`, they want to use swarm. The `enabled` field still exists in `SwarmConfig` for backward compatibility but no longer blocks usage.

## Before (Broken)

```rust
// TUI: src/tui/mod.rs
"init" => {
    let fresh_config = Config::load_or_default().unwrap_or_else(|_| app.config.clone());
    if !fresh_config.swarm.enabled {
        app.add_system_message("Swarm mode is disabled in config.".to_string());
        app.add_system_message("Set [swarm] enabled = true in ~/.config/openshark/config.toml".to_string());
    } else {
        // ... init swarm
    }
}

// CLI: src/main.rs
let swarm_config = config.swarm.clone();
if !swarm_config.enabled {
    println!("Swarm mode is disabled in config.");
} else {
    // ... init swarm
}
```

## After (Fixed)

```rust
// TUI: src/tui/mod.rs
"init" => {
    let fresh_config = Config::load_or_default().unwrap_or_else(|_| app.config.clone());
    // Update cached config (still reload to pick up role/max_agents changes)
    app.config = fresh_config.clone();
    let engine = SwarmEngine::new(app.config.swarm.clone());
    match engine.init(&prompt, &app.config).await {
        Ok(()) => { /* ... success ... */ }
        Err(e) => app.add_system_message(format!("Swarm init failed: {}", e)),
    }
}

// CLI: src/main.rs
let swarm_config = config.swarm.clone();
let engine = swarm::SwarmEngine::new(swarm_config);
match engine.init(&prompt, &config).await {
    Ok(()) => { /* ... success ... */ }
    Err(e) => println!("Failed to initialize swarm: {}", e),
}
```

## Key Points

1. **Explicit user intent overrides config defaults** — Running `/swarm init` is an explicit opt-in. A config flag blocking it is unnecessary friction.

2. **Keep config reload** — Still reload config from disk at init time to pick up `max_agents`, `roles`, `consensus_mode` changes without restart.

3. **Preserve the field** — Don't remove `enabled` from `SwarmConfig` to avoid breaking existing user configs. Just stop using it as a gate.

4. **Update status/help text** — Remove `enabled=` from `/swarm status` output and help text to avoid confusion.

## When to Apply This Pattern

Apply to any feature where:
- A config boolean gates explicit user command invocation
- The default is "off" but users expect to opt in via command
- The gate creates a "edit config → retry → still blocked" loop

## Related

- `references/config-reload-runtime-pattern.md` — Config reload at command entry points
- `references/swarm-mode-architecture.md` — Full swarm architecture
