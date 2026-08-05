# Session 2026-05-30: OpenShark TUI Fixes + Security Threshold

## Problems Fixed

### 1. Tool Execution "Lost in the Sauce"
**Symptom:** Model says "Let me check..." → tool executes → silence. No result, no follow-up. User thinks OpenShark is stuck.

**Root cause:** Natural-language tool suggestions were detected in the UI thread (`apply_stream_event`) and executed fire-and-forget via `tokio::spawn`. The result was discarded, never fed back into model context.

**Fix:** Moved ALL tool execution into the background streaming task (`stream_model_response_task`). The UI thread now only displays messages and handles approval popups. Added `StreamEvent::SystemMessage` variant for background task → UI notices.

**Files:** `src/tui/mod.rs` — `StreamEvent` enum, `apply_stream_event()`, `stream_model_response_task()`

### 2. Dynamic Input Bar
**Symptom:** Typing past the input bar width clipped text into the void. Cursor positioned wrong on wrapped lines.

**Root cause:** `Constraint::Length(3)` hardcoded the bar to 3 lines. Cursor math assumed single-line input.

**Fix:**
- `input_bar_height()` — computes needed lines from text ÷ wrap width, capped at 8
- `compute_wrapped_cursor_position()` — accounts for line wrapping using `unicode-width` crate
- Layout constraint changed from `Length(3)` to `Length(input_bar_height(app, width))`

**Files:** `src/tui/mod.rs`, `Cargo.toml` (added `unicode-width = "0.2"`)

### 3. `/evolution` Command
**Added:** TUI command to inspect adaptive state in real-time. Shows tool confidence thresholds, model bias scores, session stats.

**Files:** `src/tui/mod.rs` — `process_user_input()`, help text

### 4. Security Threshold: Medium → High
**Symptom:** `mkdir` with heredoc (`cat > ... << 'EOF'`) triggered approval popup because `>` redirect is classified as High risk.

**Root cause:** `auto_approve_risk_level` was `Medium`. High-risk operations (redirects, curl, ssh) required approval.

**Fix:** Changed `auto_approve_risk_level` to `High` in `SecurityConfig::default()`.

**Behavior after fix:**
- Low/Medium/High = auto-execute
- Only Critical = requires approval (rm -rf, mkfs, dd, fdisk)

**Files:** `src/security/mod.rs`

## User Preference Captured
User wants **full-send mode** — minimal interruptions, tools execute without approval unless truly destructive. Security threshold should default to `High`, not `Medium`.
