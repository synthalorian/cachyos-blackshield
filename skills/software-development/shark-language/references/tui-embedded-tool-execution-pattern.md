# TUI Embedded Tool Execution Pattern

## Problem

The model outputs `TOOL:` lines **embedded in natural language responses**, not just at the start:

```
I see the grid already has some vectors running.
TOOL: fs cat /home/synth/projects/README.md
TOOL: fs tree /home/synth/projects/0x7-web 2
Let me analyze what I found...
```

The old code only handled two cases:
1. `content.starts_with("TOOL:")` — start-of-response tools
2. `detect_tool_suggestions()` — natural language patterns like "Let me search..."

Both failed for embedded `TOOL:` lines because:
- `starts_with("TOOL:")` is false when the response begins with natural language
- The detection regex `TOOL:(\S+)` required NO space after the colon, but models output `TOOL: fs cat` (with space)

Result: tools displayed as raw text, never executed, streaming state broken.

## Solution

### 1. Parse ALL `TOOL:` lines from anywhere in the response

```rust
fn parse_embedded_tools(text: &str) -> Vec<(String, String)> {
    let mut tools = Vec::new();
    for line in text.lines() {
        let trimmed = line.trim();
        if trimmed.starts_with("TOOL:") {
            let rest = &trimmed[5..];           // after "TOOL:"
            let rest = rest.trim_start();       // handle "TOOL: fs cat" → "fs cat"
            let parts: Vec<&str> = rest.splitn(2, ' ').collect();
            if !parts.is_empty() && !parts[0].is_empty() {
                let tool_name = parts[0].trim().to_string();
                let args = parts.get(1).unwrap_or(&"").trim().to_string();
                tools.push((tool_name, args));
            }
        }
    }
    tools
}
```

### 2. Strip `TOOL:` lines for clean display

```rust
fn strip_tool_lines(text: &str) -> String {
    let mut result = String::new();
    for line in text.lines() {
        let trimmed = line.trim();
        if !trimmed.starts_with("TOOL:") {
            if !result.is_empty() {
                result.push('\n');
            }
            result.push_str(line);
        }
    }
    result
}
```

### 3. Execute tool chain with follow-up

```rust
async fn execute_tool_chain(
    tx: &tokio::sync::mpsc::UnboundedSender<StreamEvent>,
    provider: &Provider,
    model: &str,
    model_messages: &[Message],
    security_engine: &crate::security::SecurityEngine,
    tools: &[(String, String)],
    original_content: &str,
) -> Result<()> {
    let mut follow_messages = model_messages.to_vec();
    follow_messages.push(Message {
        role: "assistant".to_string(),
        content: strip_tool_lines(original_content),
    });

    let executor = AsyncToolExecutor::new();

    for (tool_name, args) in tools {
        // SECURITY GATE per tool
        match security_engine.check_tool_call(tool_name, args) {
            crate::security::SecurityDecision::Allow => {}
            // ... RequireApproval / Deny handling with StreamEvent::Done
        }

        match executor.execute_with_timeout_simple(tool_name.clone(), args.clone(), 30000).await {
            Ok(result) => {
                let sanitized = security_engine.sanitize_output(tool_name, &result);
                let _ = tx.send(StreamEvent::ToolResult { ... });
                follow_messages.push(Message {
                    role: "user".to_string(),
                    content: format!("Tool result ({} {}): {}", tool_name, args, sanitized),
                });
            }
            Err(e) => { /* send ToolResult failure, push error to follow_messages */ }
        }
    }

    // Single follow-up with ALL tool results
    let follow_up = ChatRequest::new(model.to_string(), follow_messages, true);
    match provider.chat_stream(follow_up).await {
        Ok((follow_chunks, _metrics)) => {
            let _ = tx.send(StreamEvent::FollowUp(follow_chunks.join("")));
            let _ = tx.send(StreamEvent::Done);
        }
        Err(e) => {
            let _ = tx.send(StreamEvent::Error(format!("Follow-up failed: {}", e)));
            let _ = tx.send(StreamEvent::Done);
        }
    }
    Ok(())
}
```

### 4. Wire into `stream_model_response_task`

Replace the old `if full_content.starts_with("TOOL:")` block:

```rust
// Handle tool invocation + follow-up
let embedded_tools = parse_embedded_tools(&full_content);
if !embedded_tools.is_empty() {
    let _ = execute_tool_chain(
        &tx, &provider, &model, &model_messages,
        &security_engine, &embedded_tools, &full_content
    ).await;
} else {
    // Natural-language suggestion fallback...
}
```

### 5. Update `apply_stream_event` for `ResponseComplete`

```rust
let embedded_tools = parse_embedded_tools(&content);
if !embedded_tools.is_empty() {
    let display_content = strip_tool_lines(&content);
    if !display_content.trim().is_empty() {
        self.add_assistant_message(display_content);
    }
    for (tool_name, args) in &embedded_tools {
        self.model_messages.push(Message {
            role: "assistant".to_string(),
            content: format!("TOOL:{} {}", tool_name, args),
        });
    }
} else if content.starts_with("TOOL:") {
    // Legacy start-of-response handling...
} else {
    // Normal assistant message...
}
```

### 6. Fix detection regex

In `src/tools/detection.rs`, change:
```rust
// BEFORE — fails on "TOOL: fs cat"
let re = Regex::new(r"(?m)^\s*TOOL:(\S+)(?:\s+(.*))?$")?;

// AFTER — handles "TOOL:fs cat" AND "TOOL: fs cat"
let re = Regex::new(r"(?m)^\s*TOOL:\s*(\S+)(?:\s+(.*))?$")?;
```

## Key Differences from Old Pattern

| Aspect | Old | New |
|--------|-----|-----|
| Tool detection | `starts_with("TOOL:")` only | `parse_embedded_tools()` scans all lines |
| Space after colon | Not supported | Supported via `trim_start()` |
| Multiple tools | Only first detected | ALL executed in sequence |
| Display | Raw `TOOL:` lines visible | Stripped via `strip_tool_lines()` |
| Follow-up context | Single tool result | Accumulated results from all tools |

## Files Modified

- `src/tui/mod.rs` — `parse_embedded_tools()`, `strip_tool_lines()`, `execute_tool_chain()`, wiring in `stream_model_response_task()` and `apply_stream_event()`
- `src/tools/detection.rs` — regex fix `TOOL:(\S+)` → `TOOL:\s*(\S+)`

## Testing

Added tests:
- `test_explicit_tool_with_space_after_colon` — verifies `TOOL: fs cat` parsing
- `test_multiple_embedded_tools` — verifies multiple `TOOL:` lines in one response
