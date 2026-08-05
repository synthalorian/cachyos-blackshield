# Security Gate Integration Pattern

Wiring `SecurityEngine` into all tool execution paths in OpenShark.

## The 5 Execution Paths

| # | Path | Function | Thread |
|---|------|----------|--------|
| 1 | User types `TOOL:...` | `tui/mod.rs::handle_user_tool_invocation()` | Main (TUI) |
| 2 | Model suggests tool in stream | `tui/mod.rs::stream_model_response_task()` | Background (tokio::spawn) |
| 3 | Tool suggestion approved | `tui/mod.rs::execute_tool_suggestion()` | Main (TUI) |
| 4 | Agentic plan step | `agent/mod.rs::execute_single_step()` | Main (agent) |
| 5 | Background stream task | `tui/mod.rs::stream_model_response_task()` | Background |

## Main Thread Paths (1, 3)

Add `security_engine: SecurityEngine` to `App` struct, initialize in `App::new()`:

```rust
let security_engine = SecurityEngine::new(
    SecurityConfig::load().unwrap_or_default()
)?;
```

Gate pattern:
```rust
match app.security_engine.check_tool_call(tool_name, args) {
    SecurityDecision::Allow => { /* proceed */ }
    SecurityDecision::RequireApproval { reason, risk_level } => {
        app.add_system_message(format!(
            "🔒 Security: Tool '{}' requires approval\n  Reason: {}\n  Risk: {:?}",
            tool_name, reason, risk_level
        ));
        return Ok(());
    }
    SecurityDecision::Deny { reason } => {
        app.add_system_message(format!(
            "🚫 Security: Tool '{}' blocked\n  Reason: {}",
            tool_name, reason
        ));
        app.security_engine.audit(tool_name, args, false, RiskLevel::Critical, &reason);
        return Ok(());
    }
}
```

After execution, sanitize and audit:
```rust
let sanitized = app.security_engine.sanitize_output(tool_name, &result);
app.security_engine.audit(tool_name, args, true, RiskLevel::Low, "approved");
```

## Background Thread Paths (2, 5)

`App` is not `Send` (contains `MemoryStore` with non-Send internals). Cannot pass `security_engine` from `App` to background task.

**Solution:** Create fresh `SecurityEngine` in background task:
```rust
let security_engine = match SecurityEngine::new(
    SecurityConfig::load().unwrap_or_default()
) {
    Ok(engine) => engine,
    Err(e) => {
        let _ = tx.send(StreamEvent::Error(format!("Security init failed: {}", e)));
        return Ok(());
    }
};
```

Same gate pattern, but send `StreamEvent::Error` for Deny/RequireApproval instead of `add_system_message`.

## Autonomous Mode (Runtime Toggle)

For a session-level toggle that elevates risk tolerance without permanently weakening security,
see `references/autonomous-mode-toggle-pattern.md`.

Key points:
- Add `SecurityEngine::check_tool_call_with_mode(tool, args, autonomous_mode)` 
- `autonomous_mode: true` elevates threshold to `RiskLevel::High`
- Never bypasses sudo, sensitive paths, or PII checks
- Bind to `Ctrl+A` in TUI with clear status message

## What Gets Blocked vs Allowed (Defaults — Coding-Friendly)

Add `security_engine: SecurityEngine` to `Agent` struct, initialize in `Agent::new()`.

Pass to `execute_single_step()`:
```rust
async fn execute_single_step(
    &self,
    step: &PlanStep,
    security_engine: &SecurityEngine,
) -> Result<String> {
    match security_engine.check_tool_call(&step.tool_name, &step.args) {
        SecurityDecision::Allow => {}
        SecurityDecision::RequireApproval { reason, risk_level } => {
            return Err(anyhow!(
                "Security approval required for tool '{}': {} (risk: {:?})",
                step.tool_name, reason, risk_level
            ));
        }
        SecurityDecision::Deny { reason } => {
            security_engine.audit(&step.tool_name, &step.args, false, RiskLevel::Critical, &reason);
            return Err(anyhow!("Security blocked tool '{}': {}", step.tool_name, reason));
        }
    }
    // ... execute, sanitize, audit
}
```

## What Gets Blocked vs Allowed (Defaults)

| Tool | Permission | Blocks |
|------|-----------|--------|
| `git` | Allow | Nothing |
| `search` | Allow | Nothing |
| `test` | Allow | Nothing |
| `fs` | Ask | `/etc/shadow`, `~/.ssh`, `~/.config/openshark` |
| `terminal` | Ask | `sudo`, `rm -rf /`, fork bombs |
| `edit` | Ask | Same sensitive paths as `fs` |
| `lsp` | Allow | Nothing |
| `refactor` | Ask | Same sensitive paths |

To make more permissive: edit `~/.config/openshark/security.toml`:
```toml
auto_approve_risk_level = "Medium"  # Auto-approves Low + Medium risk
```

## Files Modified

- `src/tui/mod.rs` — Add `security_engine` to `App`, gate `handle_user_tool_invocation()`, `execute_tool_suggestion()`, create in `stream_model_response_task()`
- `src/agent/mod.rs` — Add `security_engine` to `Agent`, gate `execute_single_step()`
- `src/security/pii.rs` — Fix `test_detect_api_key` (48 alphanumerics after `sk-`)
