# Config Reload at Runtime Pattern

**Problem:** The TUI loads config once at startup and caches it in `App.config`. When the user edits `~/.config/openshark/config.toml` while OpenShark is running, changes don't take effect until restart.

**Symptom:** User changes swarm `max_agents` or `roles` in config, runs `/swarm init`, but old settings still apply.

**Root cause:** `App::new()` loads config once. All subsequent checks use `app.config.swarm` — the cached value.

## Solution: Reload on Demand

Reload config from disk at the entry point of commands that depend on config state:

```rust
// In TUI command handler for /swarm init
"init" => {
    if prompt.is_empty() {
        // ... usage messages
    } else {
        // Reload config from disk to pick up any edits
        let fresh_config = crate::config::Config::load_or_default()
            .unwrap_or_else(|_| app.config.clone());
        // Update cached config so subsequent commands use new state
        app.config = fresh_config.clone();
        // ... proceed with swarm init (no enabled gate)
    }
}
```

## Key Points

1. **Reload at the entry point** — Don't reload on every frame (expensive). Reload when the user explicitly invokes a command that depends on config.

2. **Update cached config** — After reload succeeds, update `app.config` so subsequent commands in the same session use the new state.

3. **Graceful fallback** — If reload fails (file missing, parse error), fall back to cached config: `.unwrap_or_else(|_| app.config.clone())`.

4. **No enabled gate** — Previously, swarm checked `fresh_config.swarm.enabled` and blocked if false. This was removed because explicit `/swarm init` is sufficient user intent. See `references/swarm-enabled-gate-removal.md`.

## When to Apply

Apply this pattern to any TUI command that:
- Reads config values before executing
- Is likely to be retried after user edits config
- Doesn't require a restart to take effect

Commands that should NOT reload:
- `/model` — model switching is runtime state, not config
- `/theme` — theme is toggled at runtime
- `/branch` — branching is session state

## Anti-Pattern: Full Config Reload Loop

Don't reload config in the main event loop:
```rust
// WRONG — reloads every 16ms, wasteful
loop {
    app.config = Config::load_or_default().unwrap(); // Don't do this
    // ...
}
```
