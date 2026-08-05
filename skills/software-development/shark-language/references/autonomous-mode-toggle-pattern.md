# Autonomous Mode Toggle Pattern

Runtime toggle that elevates the security auto-approve threshold from Medium to High,
allowing the model to execute `curl`, output redirection, and other high-risk tools
without blocking — while still protecting against `sudo`, destructive commands, and
sensitive path access.

## Use Case

User wants the harness to "slam through prompts autonomously" for one-liner coding tasks,
but doesn't want to permanently weaken security. Solution: a session-level toggle.

## Implementation

### 1. Add `autonomous_mode` to App state

```rust
// tui/mod.rs
struct App {
    // ... existing fields ...
    security_engine: crate::security::SecurityEngine,
    autonomous_mode: bool,
}
```

Initialize to `false` in `App::new()`.

### 2. Add `check_tool_call_with_mode` to SecurityEngine

```rust
// security/mod.rs
impl SecurityEngine {
    /// Default check — safe mode.
    pub fn check_tool_call(&self, tool_name: &str, args: &str) -> SecurityDecision {
        self.check_tool_call_with_mode(tool_name, args, false)
    }

    /// Check with explicit autonomous mode override.
    pub fn check_tool_call_with_mode(
        &self,
        tool_name: &str,
        args: &str,
        autonomous_mode: bool,
    ) -> SecurityDecision {
        // L1-L4: sandbox, permissions, sudo, sensitive paths — NEVER bypassed
        // ... (same as standard check) ...

        // L5: Risk assessment with elevated threshold in autonomous mode
        let risk = self.assess_risk(tool_name, args);
        let threshold = if autonomous_mode {
            RiskLevel::High
        } else {
            self.config.auto_approve_risk_level.clone()
        };
        if risk > threshold {
            return SecurityDecision::RequireApproval { /* ... */ };
        }

        // L6: PII check — still active even in autonomous mode
        // ...

        SecurityDecision::Allow
    }
}
```

**Critical:** Never bypass sudo checks, sensitive path checks, or PII detection.
Only the risk-level threshold is elevated.

### 3. Wire all call sites to pass `autonomous_mode`

| Path | Change |
|------|--------|
| `handle_user_tool_invocation` | `security_engine.check_tool_call_with_mode(tool, args, app.autonomous_mode)` |
| `execute_tool_suggestion` | Same — `app.autonomous_mode` |
| `stream_model_response_task` | Create `SecurityEngine` in bg task, pass `false` (conservative for bg) OR pass `autonomous_mode` via channel |
| `Agent::execute_single_step` | Add `autonomous_mode: bool` param, pass through from `AgentConfig` |

### 4. Add Ctrl+A keybinding in TUI

```rust
// tui/mod.rs::handle_input()
KeyCode::Char('a') if key.modifiers.contains(KeyModifiers::CONTROL) => {
    app.autonomous_mode = !app.autonomous_mode;
    let status = if app.autonomous_mode {
        "🚀 AUTONOMOUS MODE ON — High-risk tools auto-approved. sudo/sensitive paths still blocked."
    } else {
        "🔒 Autonomous mode off — Standard security (Medium risk threshold)."
    };
    app.add_system_message(status.to_string());
}
```

### 5. Update help text

```rust
"Commands: ... | Ctrl+A: autonomous mode, ..."
```

## Security Posture Comparison

| Scenario | Default (Medium) | Autonomous (High) |
|----------|-----------------|-------------------|
| `git push` | ✅ auto | ✅ auto |
| `cargo install` | ✅ auto | ✅ auto |
| `curl` | 🔒 requires approval | ✅ auto |
| `> file.txt` | 🔒 requires approval | ✅ auto |
| `ssh` | 🔒 requires approval | ✅ auto |
| `sudo` | 🚫 blocked | 🚫 blocked |
| `rm -rf /` | 🚫 blocked | 🚫 blocked |
| `~/.ssh` access | 🚫 blocked | 🚫 blocked |
| PII in args | 🔒 flagged | 🔒 flagged |

## Default Config (Coding-Friendly)

```rust
// security/mod.rs::SecurityConfig::default()
let mut tool_permissions = HashMap::new();
tool_permissions.insert("fs".to_string(), PermissionLevel::Allow);
tool_permissions.insert("terminal".to_string(), PermissionLevel::Allow);
tool_permissions.insert("git".to_string(), PermissionLevel::Allow);
tool_permissions.insert("search".to_string(), PermissionLevel::Allow);
tool_permissions.insert("edit".to_string(), PermissionLevel::Allow);
tool_permissions.insert("lsp".to_string(), PermissionLevel::Allow);
tool_permissions.insert("refactor".to_string(), PermissionLevel::Allow);
tool_permissions.insert("test".to_string(), PermissionLevel::Allow);

auto_approve_risk_level: RiskLevel::Medium,
```

All coding tools are `Allow` by default. Only risk assessment (based on command content)
and hard blocks (sudo, sensitive paths) gate execution.

## Files Touched

- `src/security/mod.rs` — `check_tool_call_with_mode()`
- `src/tui/mod.rs` — `App.autonomous_mode`, keybinding, help text
- `src/tui/mod.rs` — all `check_tool_call` call sites updated
- `src/agent/mod.rs` — `execute_single_step` param, `AgentConfig` optional field
