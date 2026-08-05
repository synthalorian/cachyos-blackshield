# Streaming Tool Call Accumulation Pattern

## Problem

When using OpenAI-compatible function calling with streaming (`stream: true`), tool calls don't arrive as complete objects. They come as fragments across multiple SSE chunks:

```
data:{"delta":{"tool_calls":[{"index":0,"function":{"arguments":"{\""}}]}}
data:{"delta":{"tool_calls":[{"index":0,"function":{"arguments":"command"}}]}}
data:{"delta":{"tool_calls":[{"index":0,"function":{"arguments":"\":\""}}]}}
data:{"delta":{"tool_calls":[{"index":0,"function":{"arguments":"ls"}}]}}
data:{"delta":{"tool_calls":[{"index":0,"function":{"arguments":"\"}"}}]}}
```

Each chunk contains a partial `arguments` string. Must accumulate before parsing.

## Accumulation Algorithm

```rust
use std::collections::HashMap;

#[derive(Default)]
struct AccumulatedToolCall {
    id: String,
    name: String,
    arguments: String,
}

fn accumulate_tool_calls(
    tool_calls: &mut HashMap<u32, AccumulatedToolCall>,
    delta_tool_calls: &[serde_json::Value],
) {
    for tc in delta_tool_calls {
        let index = tc.get("index").and_then(|i| i.as_u64()).unwrap_or(0) as u32;
        let entry = tool_calls.entry(index).or_default();
        
        if let Some(id) = tc.get("id").and_then(|i| i.as_str()) {
            entry.id.push_str(id);
        }
        
        if let Some(func) = tc.get("function") {
            if let Some(name) = func.get("name").and_then(|n| n.as_str()) {
                entry.name.push_str(name);
            }
            if let Some(args) = func.get("arguments").and_then(|a| a.as_str()) {
                entry.arguments.push_str(args);
            }
        }
    }
}

// When finish_reason == "tool_calls":
for (_, tc) in tool_calls {
    let args: serde_json::Value = serde_json::from_str(&tc.arguments)
        .expect("Invalid tool call arguments JSON");
    execute_tool(&tc.name, &args);
}
```

## OpenShark Integration (Verified)

In `providers/mod.rs::chat_stream_realtime()`, the accumulation uses a `HashMap<u32, AccumulatedToolCall>` keyed by the `index` field from each delta fragment:

```rust
#[derive(Debug, Clone, Default)]
pub struct AccumulatedToolCall {
    pub id: String,
    pub name: String,
    pub arguments: String,
}

// In the streaming loop:
let mut pending_tool_calls: HashMap<u32, AccumulatedToolCall> = HashMap::new();

// When processing each SSE chunk:
if let Some(tcs) = tool_calls {
    for tc in tcs {
        let index = tc.get("index")
            .and_then(|i| i.as_u64())
            .unwrap_or(0) as u32;
        let entry = pending_tool_calls.entry(index).or_default();

        if let Some(id) = tc.get("id").and_then(|i| i.as_str()) {
            if !id.is_empty() { entry.id.push_str(id); }
        }
        if let Some(name) = tc.get("function")
            .and_then(|f| f.get("name"))
            .and_then(|n| n.as_str()) {
            if !name.is_empty() { entry.name.push_str(name); }
        }
        if let Some(args) = tc.get("function")
            .and_then(|f| f.get("arguments"))
            .and_then(|a| a.as_str()) {
            entry.arguments.push_str(args);
        }
    }
}

// When finish_reason == "tool_calls":
for (idx, mut tc) in pending_tool_calls.drain() {
    let _ = tx.send(StreamChunk::ToolCall {
        id: tc.id,
        name: tc.name,
        arguments: tc.arguments,
    });
}
let _ = tx.send(StreamChunk::Finish("tool_calls".to_string()));
```

**Critical:** Use `HashMap` keyed by `index`, NOT scalar variables. Multiple tool calls or out-of-order fragments will clobber each other with scalar state.

## TUI Handling

In `tui/mod.rs`, handle `StreamChunk::ToolCall`:

1. Parse `arguments` JSON
2. Execute the tool via `AsyncToolExecutor`
3. Send result back as new message: `role: "tool"`, `tool_call_id: id`, `content: result`
4. Trigger follow-up chat with the tool result message included

## Non-Streaming Path

For `chat_stream()` (non-streaming), tool calls arrive complete in the response:

```rust
let response = provider.chat(request).await?;
if response.choices[0].finish_reason == Some("tool_calls".to_string()) {
    let message = &response.choices[0].message;
    for tc in message.tool_calls.iter() {
        execute_tool(&tc.function.name, &tc.function.arguments);
    }
}
```

Note: `Message` struct needs a `tool_calls` field for non-streaming responses.

## Testing

Verify with direct API call:

```bash
curl -s http://127.0.0.1:8699/v1/chat/completions \
  -H "Authorization: Bearer *** \
  -H "Content-Type: application/json" \
  -d '{
    "model": "kimi-for-coding",
    "messages": [
      {"role": "system", "content": "You have tool access."},
      {"role": "user", "content": "run ls"}
    ],
    "stream": true,
    "tools": [...]
  }'
```

Look for:
- `delta.tool_calls` fragments in SSE stream
- `finish_reason: "tool_calls"` in final chunk
- Accumulated arguments parse as valid JSON
