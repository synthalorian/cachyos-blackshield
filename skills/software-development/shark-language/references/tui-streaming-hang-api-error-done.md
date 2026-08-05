# TUI Streaming Hang — Missing Done After API Error

## Problem

The TUI shows "⚠️ Response seems incomplete — synthesizing full answer..." or
appears to hang after tool execution. The `is_streaming` flag never clears.

## Root Cause

When the main `provider.chat_stream()` call in `stream_model_response_task` fails
(e.g., context exceeded, rate limit, network error), the error handler sends
`StreamEvent::Error` but does NOT send `StreamEvent::Done`. The TUI stays in
streaming mode forever.

This is especially common when:
- Context compression fails to keep usage under limit
- The completion re-request adds MORE messages to already-overflowing context
- The model rejects the request with "context length exceeded"

## Code Location

`src/tui/mod.rs`, `stream_model_response_task`, main `match provider.chat_stream(request).await`:

```rust
Err(e) => {
    let error_msg = format!("{}", e);
    let display_msg = if let Some(json_start) = error_msg.find('{') {
        // ... JSON parsing to extract error message
    } else {
        error_msg
    };
    let _ = tx.send(StreamEvent::Error(display_msg));
    // MISSING: let _ = tx.send(StreamEvent::Done);
}
```

## Fix

Add `Done` after the error send:

```rust
Err(e) => {
    let error_msg = format!("{}", e);
    let display_msg = if let Some(json_start) = error_msg.find('{') {
        // ... JSON parsing
    } else {
        error_msg
    };
    let _ = tx.send(StreamEvent::Error(display_msg));
    let _ = tx.send(StreamEvent::Done);  // <-- ADD THIS
}
```

## Diagnosis

Check sidebar metrics:
- `Ctx Used` > `Max Ctx` → context exceeded, API rejected the request
- `Tool exec: 0ms` → tool ran but follow-up never completed
- No error message visible in chat → `Error` event was sent but `Done` wasn't,
  so the TUI may not have rendered it before entering hung state

## Related

- `references/tui-streaming-hang-comprehensive-fix.md` — Master reference for all missing-Done hang bugs
- `references/context-compression-system.md` — Context compression to prevent exceeding limits
