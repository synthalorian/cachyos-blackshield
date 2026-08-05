# Session 2026-05-30: Tool Execution Follow-Up Fix + Dynamic Input Bar + Security Threshold

## Problems Fixed

### 1. Tool Execution Got Lost in the Sauce

**Symptom:** Model says "Let me check..." → tool executes → result never comes back → no follow-up response. User sees only the initial message, then silence.

**Root cause:** Natural-language tool suggestions were detected in `apply_stream_event` (UI thread) and executed with `tokio::spawn` fire-and-forget. The result was never fed back to the model.

**Fix:** Move ALL tool execution into the background task (`stream_model_response_task`). Two paths now:

1. `TOOL:fs list /path` → execute → send `ToolResult` → follow-up request → send `FollowUp`
2. Natural language ("Let me check...") → detect suggestion → same flow

The UI (`apply_stream_event`) only handles approval-required tools (shows y/n popup). Auto-execute happens in the background task with full result → follow-up chaining.

**Code pattern:**
```rust
// In stream_model_response_task, after ResponseComplete:
if full_content.starts_with("TOOL:") {
    // ... execute tool, send ToolResult, do follow-up
} else {
    // Handle natural-language tool suggestions
    let suggestions = detect_tool_suggestions(&full_content);
    if let Some(suggestion) = suggestions.into_iter().find(|s| s.confidence >= 0.6) {
        match security_engine.check_tool_call(&suggestion.tool_name, &suggestion.args) {
            Allow => {
                // Execute + follow-up (same as TOOL: path)
            }
            RequireApproval => {
                // Send error — UI will show popup
            }
            Deny => { /* Send error */ }
        }
    }
}
```

**Key insight:** The `StreamEvent::SystemMessage` variant was added to show "🔧 Auto-executing..." notices from the background task.

### 2. Approval Flow Got Stuck

**Symptom:** User presses 'y' to approve → tool executes → follow-up response comes back → if follow-up contains another tool suggestion, nothing happens. Flow dies.

**Root cause:** `execute_tool_suggestion` ran synchronously in the UI loop. The follow-up response was just added as a plain message with `app.add_assistant_message()`. No tool suggestion detection on the follow-up.

**Fix:** When user presses 'y', spawn a background task (`execute_approved_tool_task`) that mirrors the normal streaming pipeline:

```rust
// handle_input — KeyCode::Char('y'):
let (tx, rx) = tokio::sync::mpsc::unbounded_channel();
app.stream_rx = Some(rx);

tokio::spawn(async move {
    let _ = execute_approved_tool_task(
        tx, provider, model, model_messages,
        security_engine, suggestion,
    ).await;
});
```

The background task:
1. Executes the approved tool → sends `ToolResult`
2. Does follow-up request → sends `ResponseComplete`
3. **Checks follow-up for chained tool suggestions** → auto-executes or queues another approval
4. Sends `Done`

All events flow through `apply_stream_event` which already handles tool suggestion detection.

**Required changes:**
- `SecurityEngine` must be `Clone` — derive Clone on all sub-structs (Sandbox, Guardrails, PiiDetector, IdentityManager)
- `StreamEvent::SystemMessage(String)` variant added for background task notices

### 3. Dynamic Input Bar

**Symptom:** Typing past 3 lines in the input bar causes text to "phase into the nether" — clipped and unreadable.

**Root cause:** `Constraint::Length(3)` hardcoded the input bar. Cursor positioning assumed single-line: `cursor_y = inner.y`.

**Fix:**

```rust
// Compute height based on text length and wrap width
fn input_bar_height(app: &App, area_width: u16) -> u16 {
    let available_width = area_width.saturating_sub(2).max(1) as usize;
    let text_len = if app.input.is_empty() {
        "Type a message or command...".len()
    } else {
        app.input.len()
    };
    let lines = (text_len + available_width - 1) / available_width;
    let capped = lines.max(1).min(8);
    (capped as u16) + 2 // +2 for borders
}

// Fix cursor for wrapped text
fn compute_wrapped_cursor_position(
    text: &str, cursor_pos: usize, wrap_width: usize,
    base_x: u16, base_y: u16,
) -> (u16, u16) {
    let before_cursor = &text[..cursor_pos.min(text.len())];
    let mut col: usize = 0;
    let mut row: u16 = 0;
    for ch in before_cursor.chars() {
        if ch == '\n' { row += 1; col = 0; }
        else {
            let ch_width = ch.width().unwrap_or(1);
            if col + ch_width > wrap_width { row += 1; col = ch_width; }
            else { col += ch_width; }
        }
    }
    (base_x + col as u16, base_y + row)
}
```

**Dependencies:** Add `unicode-width = "0.2"` to `Cargo.toml` for proper character width handling.

**Layout constraint:**
```rust
let chat_layout = Layout::default()
    .direction(Direction::Vertical)
    .constraints([
        Constraint::Min(3),
        Constraint::Length(input_bar_height(app, main_layout[1].width)),
    ])
    .split(main_layout[1]);
```

### 4. Security Threshold: Medium → High

**Symptom:** `mkdir` with heredoc (`cat > ... << 'EOF'`) required approval. User: "I definitely did not WANT to have to approve a mkdir."

**Root cause:** `auto_approve_risk_level: RiskLevel::Medium`. The `>` redirect in the heredoc classified the command as High risk.

**Fix:** Changed default from `Medium` to `High`:

```rust
// FULL-SEND MODE: Auto-approve up to High risk (mkdir, curl, redirects, ssh)
// Only Critical (rm -rf, mkfs, fdisk, format) requires approval
auto_approve_risk_level: RiskLevel::High,
```

**Behavior:**
| Risk | Examples | Behavior |
|------|----------|----------|
| Low | `fs read`, `git status` | ✅ Auto |
| Medium | `git push`, `pip install` | ✅ Auto |
| High | `mkdir`, `curl`, `>`, `ssh` | ✅ Auto (was: require approval) |
| Critical | `rm -rf`, `dd`, `mkfs` | 🔒 Require approval |

**User preference:** Full-send coding mode. Only filesystem-destroying operations should interrupt flow.

## Files Modified

- `src/tui/mod.rs` — Background task patterns, StreamEvent variants, input bar functions
- `src/security/mod.rs` — `auto_approve_risk_level: High`, Clone derives
- `src/security/sandbox.rs` — `#[derive(Clone)]`
- `src/security/guardrails.rs` — `#[derive(Clone)]`
- `src/security/pii.rs` — `#[derive(Clone)]`
- `src/security/identity.rs` — `#[derive(Clone)]`
- `Cargo.toml` — Added `unicode-width = "0.2"`
