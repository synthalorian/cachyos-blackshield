# TUI Streaming Hang — Missing StreamEvent::Done After FollowUp

## Problem

After the model auto-executed a tool (via natural-language suggestion detection), the background task sent `StreamEvent::FollowUp` with the follow-up response, but **never sent `StreamEvent::Done`**. This left `is_streaming = true` forever, locking the input bar on "Streaming response..." and preventing user input.

## Root Cause

In `src/tui/mod.rs::stream_model_response_task()`, the follow-up chat_stream after tool execution sends `FollowUp` but falls through without signaling completion:

```rust
// BEFORE (broken — hangs forever)
match provider.chat_stream(follow_up).await {
    Ok((follow_chunks, _metrics)) => {
        let follow_content: String = follow_chunks.join("");
        let _ = tx.send(StreamEvent::FollowUp(follow_content));
        // MISSING: StreamEvent::Done
    }
    Err(e) => {
        let _ = tx.send(StreamEvent::Error(format!("Follow-up failed: {}", e)));
        // MISSING: StreamEvent::Done
    }
}
```

The `apply_stream_event` handler for `FollowUp` calls `add_assistant_message()` but does NOT set `is_streaming = false`. Only `Done` does that.

## Fix

Add `StreamEvent::Done` after both success and error paths:

```rust
// AFTER (fixed)
match provider.chat_stream(follow_up).await {
    Ok((follow_chunks, _metrics)) => {
        let follow_content: String = follow_chunks.join("");
        let _ = tx.send(StreamEvent::FollowUp(follow_content));
        let _ = tx.send(StreamEvent::Done);  // ← CRITICAL
    }
    Err(e) => {
        let _ = tx.send(StreamEvent::Error(format!("Follow-up failed: {}", e)));
        let _ = tx.send(StreamEvent::Done);  // ← CRITICAL
    }
}
```

## Affected Code Paths

Two locations in `stream_model_response_task` had this bug:
1. **Line ~1697** — Explicit `TOOL:` prefix path (after direct tool invocation)
2. **Line ~1766** — Natural language tool suggestion path (after `detect_tool_suggestions`)

## Verification

After fix, the tool execution flow should complete cleanly:
1. User sends message
2. Model responds with tool suggestion
3. Tool auto-executes (low risk)
4. `ToolResult` event shows result
5. `FollowUp` event shows assistant response
6. `Done` event clears `is_streaming`
7. Input bar returns to "Type a message or command..."

## Related

- `references/tui-tool-execution-followup-pattern.md` — General tool execution → follow-up pattern
- `references/tui-async-background-task-pattern.md` — Background task event pipeline
