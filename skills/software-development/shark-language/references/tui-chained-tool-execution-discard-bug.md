# Chained Tool Execution Result Discard Bug

## Problem

In `execute_approved_tool_task()` (tui/mod.rs), when a follow-up response contained a chained tool suggestion (e.g., the model wants to run a second tool after the first), the code executed the tool but **threw away the result**:

```rust
// BROKEN — result is dropped on the floor
let _ = executor
    .execute_with_timeout_simple(next_tool, next_args, 30000)
    .await;
```

The tool ran, but no `ToolResult` event was sent through the channel. The TUI showed no output, `is_streaming` stayed true, and the user thought the harness was hung.

## Root Cause

The chained tool execution path was added as a quick "recurse through same pipeline" comment, but the developer never wired the result back into the event stream. The `let _ =` pattern silently discarded both success and error results.

## Fix

Replace the discard with full result handling:

1. **Send ToolResult event** — so the TUI displays the tool output
2. **Build follow-up messages** — include the tool invocation + result in model context
3. **Request synthesis** — call `provider.chat_stream()` with the enriched context
4. **Send FollowUp event** — stream the model's synthesis back to the user
5. **Handle errors** — send error events instead of silently dropping them

```rust
match executor.execute_with_timeout_simple(next_tool.clone(), next_args.clone(), 30000).await {
    Ok(result) => {
        let _ = tx.send(StreamEvent::ToolResult {
            name: next_tool.clone(),
            args: next_args.clone(),
            result: result.clone(),
            success: true,
        });
        // Build follow-up messages and request synthesis...
        let mut chained_messages = follow_messages.clone();
        chained_messages.push(Message {
            role: "assistant".to_string(),
            content: format!("TOOL:{} {}", next_tool, next_args),
            images: None,
        });
        chained_messages.push(Message {
            role: "user".to_string(),
            content: format!("Tool result: {}", result),
            images: None,
        });
        let chained_req = ChatRequest::new(model.clone(), chained_messages, true);
        match provider.chat_stream(chained_req).await {
            Ok((chunks, _metrics)) => {
                let chained_content = chunks.join("");
                let _ = tx.send(StreamEvent::FollowUp(chained_content));
            }
            Err(e) => {
                let _ = tx.send(StreamEvent::Error(format!("Chained follow-up failed: {}", e)));
            }
        }
    }
    Err(e) => {
        let _ = tx.send(StreamEvent::ToolResult {
            name: next_tool,
            args: next_args,
            result: e.to_string(),
            success: false,
        });
    }
}
```

## Prevention

- **Never use `let _ =` on async tool execution results** in event-driven code
- **Always send a terminal event** (`ToolResult`, `Error`, or `Done`) after any async operation
- **Code review checklist:** Every `.await` in a background task must have a visible outcome in the event stream

## Detection

If the model outputs a tool suggestion after a tool result, but the TUI shows:
- No new message after "Auto-executing: ..."
- Streaming indicator stays active indefinitely
- No error message

→ Check `execute_approved_tool_task()` for discarded results.

## Affected Versions

OpenShark v1.0.0 — fixed in post-v1.0.0 commit.
