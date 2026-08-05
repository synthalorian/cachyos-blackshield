# TUI Tool Approval Pattern — Auto-Approve + Popup + Timeout

**When to use:** Adding or modifying tool approval flow in OpenShark's ratatui TUI.

## Architecture

The tool approval system has three layers:

1. **Security engine** (`src/security/mod.rs`) — decides `Allow` / `RequireApproval` / `Deny`
2. **Background stream task** (`stream_model_response_task`) — checks security before executing
3. **TUI main loop** (`run_app`) — handles user y/n input + auto-close timeout

## Risk Levels

| Level | Examples | Default Behavior |
|-------|----------|-----------------|
| None | `echo hello` | Auto-approve |
| Low | `fs read`, `search`, `git status` | Auto-approve |
| Medium | `git push`, `pip install`, `cargo install` | **Auto-approve** (configurable) |
| High | `curl`, `ssh`, `> redirect`, `sudo` | Require approval popup |
| Critical | `rm -rf /`, `mkfs`, `dd` | Require approval (never bypassed) |

## Changing the Threshold

Edit `SecurityConfig::default()` in `src/security/mod.rs`:

```rust
// Auto-approve up to Medium (Low + Medium auto-execute, High + Critical need approval)
auto_approve_risk_level: RiskLevel::Medium,

// More restrictive — only Low auto-executes
auto_approve_risk_level: RiskLevel::Low,

// Full-send — even High auto-executes (Critical still blocked)
auto_approve_risk_level: RiskLevel::High,
```

## Popup Input Handling (Critical Fix)

The original code used a `match app.mode` nested inside the main key handler, which caused y/n to not register. The fix is a **top-level guard** at the start of `handle_input`:

```rust
async fn handle_input(app: &mut App, key: KeyEvent) -> Result<bool> {
    // ToolApproval mode: handle y/n IMMEDIATELY, no other input accepted
    if app.mode == AppMode::ToolApproval {
        match key.code {
            KeyCode::Char('y') | KeyCode::Char('Y') => {
                if let Some(suggestion) = app.pending_suggestion.take() {
                    app.mode = AppMode::Normal;
                    app.add_system_message(format!(
                        "✅ Approved: {} {}", suggestion.tool_name, suggestion.args
                    ));
                    let _ = execute_tool_suggestion(app, &suggestion).await;
                }
            }
            KeyCode::Char('n') | KeyCode::Char('N') | KeyCode::Esc => {
                let tool_name = app.pending_suggestion
                    .as_ref()
                    .map(|s| s.tool_name.clone())
                    .unwrap_or_default();
                app.pending_suggestion = None;
                app.mode = AppMode::Normal;
                app.add_system_message(format!(
                    "⏭ Skipped tool suggestion{}.",
                    if tool_name.is_empty() {
                        "".to_string()
                    } else {
                        format!(" for {}", tool_name)
                    }
                ));
            }
            _ => {
                // Ignore all other keys in approval mode
                app.add_system_message("Press 'y' to approve or 'n' to skip.".to_string());
            }
        }
        return Ok(false);
    }
    // ... rest of normal input handling
}
```

**Why this works:** The guard runs **before** any other key handling. When in `ToolApproval` mode, only y/n/Esc are processed. Everything else is ignored with a reminder.

## Auto-Close Timeout

Add a timestamp field to `App`:

```rust
struct App {
    // ... other fields ...
    /// Timestamp when tool approval popup was shown (for auto-close timeout).
    tool_approval_shown_at: Option<Instant>,
}
```

Initialize in `App::new()`:
```rust
tool_approval_shown_at: None,
```

Set when entering approval mode:
```rust
self.pending_suggestion = Some(suggestion);
self.mode = AppMode::ToolApproval;
self.tool_approval_shown_at = Some(Instant::now());
```

Check in the main `run_app` loop (after the tick update):
```rust
// Auto-close tool approval popup after 60 seconds of inactivity
if app.mode == AppMode::ToolApproval {
    if let Some(shown_at) = app.tool_approval_shown_at {
        if shown_at.elapsed() >= Duration::from_secs(60) {
            let tool_name = app
                .pending_suggestion
                .as_ref()
                .map(|s| s.tool_name.clone())
                .unwrap_or_default();
            app.pending_suggestion = None;
            app.mode = AppMode::Normal;
            app.tool_approval_shown_at = None;
            app.add_system_message(format!(
                "⏭ Tool approval timed out after 60s{}.",
                if tool_name.is_empty() {
                    "".to_string()
                } else {
                    format!(" for {}", tool_name)
                }
            ));
        }
    }
}
```

## System Prompt for Tool Auto-Use

Tell the model it **can** auto-use tools. The old prompt said "Do NOT auto-invoke" which trained the model to never use tools:

```rust
let system_msg = Message {
    role: "system".to_string(),
    content: format!(
        "{}\n\nYou have access to tools. \
         When you need to use a tool, output it as: TOOL:<tool_name> <args> \
         Low and Medium risk tools execute automatically. \
         High risk tools (curl, ssh, redirects, sudo) require user approval. \
         Be concise and direct. Don't overthink.",
        soul.system_prompt()
    ),
};
```

## Auto-Execution in `apply_stream_event`

When the model response contains a tool suggestion and the security engine returns `Allow`, execute asynchronously since `apply_stream_event` is synchronous:

```rust
crate::security::SecurityDecision::Allow => {
    // Clone before moving into async block
    let tool_name = suggestion.tool_name.clone();
    let args = suggestion.args.clone();
    self.add_system_message(format!(
        "🔧 Auto-executing: {} {} (low risk)",
        tool_name, args
    ));
    let executor = AsyncToolExecutor::new();
    tokio::spawn(async move {
        let _ = executor
            .execute_with_timeout_simple(tool_name, args, 30000)
            .await;
    });
}
```

**Critical:** Clone `tool_name` and `args` **before** the `tokio::spawn`. The `suggestion` variable is used later in the `RequireApproval` branch, so it can't be moved into the async block.

## Files to Touch

| File | What to change |
|------|---------------|
| `src/security/mod.rs` | `auto_approve_risk_level` default |
| `src/tui/mod.rs` — `App` struct | Add `tool_approval_shown_at` field |
| `src/tui/mod.rs` — `App::new()` | Initialize `tool_approval_shown_at: None` |
| `src/tui/mod.rs` — `apply_stream_event` | Set timestamp + handle `Allow` branch |
| `src/tui/mod.rs` — `handle_input` | Top-level ToolApproval guard |
| `src/tui/mod.rs` — `run_app` | Auto-close timeout check |
| `src/tui/mod.rs` — system msg | Update prompt to encourage tool use |
