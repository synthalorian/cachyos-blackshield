# TUI Streaming Hang — Comprehensive Fix

## Problem

The TUI shows "Streaming response..." indefinitely. The `is_streaming` flag never
clears to `false`. This has multiple root causes — all missing `StreamEvent::Done`
events in the background task.

## Root Causes (All in `stream_model_response_task` and `execute_tool_chain`)

### Phase 1: Initial response streaming

| Line | Scenario | Missing `Done`? |
|------|----------|-----------------|
| ~1683 | Tool execution fails (e.g., `fs write` to non-existent dir) | **YES** — sends `ToolResult` with `success: false`, no `Done` |
| ~1697 | Follow-up after tool success completes | Fixed in earlier patch |
| ~1754 | Suggestion tool execution fails | **YES** — same pattern as line 1683 |
| ~1762 | Security `RequireApproval` for suggestion | **YES** — sends `Error`, no `Done` |
| ~1768 | Security `Deny` for suggestion | **YES** — sends `Error`, no `Done` |

### Phase 2: `execute_tool_chain` follow-up retries (2025-06-01 discovery)

When `execute_tool_chain` calls the model for follow-up synthesis, the response
can be empty or too short. The retry paths were missing `Done`:

| Location | Scenario | Missing `Done`? |
|----------|----------|-----------------|
| `execute_tool_chain` ~1986 | Empty follow-up → retry success | **YES** — sends `FollowUp`, no `Done` |
| `execute_tool_chain` ~1989 | Empty follow-up → retry error | **YES** — sends `Error`, no `Done` |
| `execute_tool_chain` ~2012 | Too-short follow-up → retry success | **YES** — sends `FollowUp`, no `Done` |
| `execute_tool_chain` ~2015 | Too-short follow-up → retry error | **YES** — sends `Error`, no `Done` |

### Phase 3: Natural-language suggestion follow-up retries (2025-06-01 discovery)

Same retry-path bug exists in the `else` branch (natural-language suggestions,
not embedded `TOOL:` lines):

| Location | Scenario | Missing `Done`? |
|----------|----------|-----------------|
| `stream_model_response_task` ~2198 | Suggestion → empty follow-up → retry success | **YES** |
| `stream_model_response_task` ~2199 | Suggestion → empty follow-up → retry error | **YES** |
| `stream_model_response_task` ~2218 | Suggestion → brief follow-up → retry success | **YES** |
| `stream_model_response_task` ~2219 | Suggestion → brief follow-up → retry error | **YES** |

### Phase 4: API error in main chat_stream (2025-06-01 discovery)

| Location | Scenario | Missing `Done`? |
|----------|----------|-----------------|
| `stream_model_response_task` ~2278 | Main `provider.chat_stream()` fails | **YES** — sends `Error`, no `Done` |

## The Fix

Add `let _ = tx.send(StreamEvent::Done);` after EVERY event-send that represents
a terminal state in the stream state machine.

### Code Pattern (lines ~1676-1683)

```rust
// BEFORE — hangs forever on tool execution failure
Err(e) => {
    let _ = tx.send(StreamEvent::ToolResult {
        name: tool_name,
        args,
        result: e.to_string(),
        success: false,
    });
}

// AFTER — properly terminates stream
Err(e) => {
    let _ = tx.send(StreamEvent::ToolResult {
        name: tool_name,
        args,
        result: e.to_string(),
        success: false,
    });
    let _ = tx.send(StreamEvent::Done);
}
```

### All Fixes Applied

```rust
// Fix 1-4: Original comprehensive fix (tool failure, suggestion failure, security approval, security deny)
// See earlier patch — already in skill

// Fix 5-8: execute_tool_chain retry paths (empty + too-short follow-up, both success and error)
// In execute_tool_chain, after provider.chat_stream(retry_req).await:
Ok((retry_chunks, _)) => {
    let retry_content = retry_chunks.join("");
    let _ = tx.send(StreamEvent::FollowUp(retry_content));
    let _ = tx.send(StreamEvent::Done);  // <-- ADD
}
Err(e) => {
    let _ = tx.send(StreamEvent::Error(format!("Retry failed: {}", e)));
    let _ = tx.send(StreamEvent::Done);  // <-- ADD
}

// Fix 9-12: Natural-language suggestion retry paths (same pattern, in stream_model_response_task else branch)
// Identical to fixes 5-8, but inside the suggestion handler

// Fix 13: Main API error path
Err(e) => {
    let _ = tx.send(StreamEvent::Error(display_msg));
    let _ = tx.send(StreamEvent::Done);  // <-- ADD
}
```

## Prevention Checklist

When modifying `stream_model_response_task` or `execute_tool_chain`, verify EVERY
code path ends with one of these terminal events:
- `StreamEvent::ResponseComplete { ... }` — sets `is_streaming = false`
- `StreamEvent::Done` — sets `is_streaming = false`
- `StreamEvent::Error(...)` — sets `is_streaming = false`

**Rule:** If a branch sends `ToolResult`, `FollowUp`, `SystemMessage`, or
`MultiModelResponse` without also sending `ResponseComplete`/`Done`/`Error`,
it's a hang bug.

**Audit pattern:** Search for all `tx.send(` calls in `stream_model_response_task`
and `execute_tool_chain`. Any send that is NOT followed by `Done` or `Error` on
all control-flow paths is a bug.

```bash
# Quick audit — look for sends without matching Done
grep -n "tx.send" src/tui/mod.rs | grep -v "Done\|Error\|Start\|Chunk\|ResponseComplete"
```

## Related

- `references/tui-streaming-hang-followup-done.md` — Earlier fix for missing Done after FollowUp
- `references/tui-streaming-hang-api-error-done.md` — Missing Done after API error
- `references/tui-async-background-task-pattern.md` — Background task architecture
