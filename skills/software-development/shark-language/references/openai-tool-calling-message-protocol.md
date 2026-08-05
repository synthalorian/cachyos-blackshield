# OpenAI-Compatible Tool Calling: Message Protocol Requirements

When implementing native function/tool calling against OpenAI-compatible APIs (OpenAI, Kimi, OpenRouter, llama-swap, etc.), the message protocol requires two fields that are easy to miss:

## Required Fields

### 1. `tool_call_id` on `role: "tool"` messages

Every tool result message must include `tool_call_id` matching the `id` from the assistant's `tool_calls`:

```json
{
  "role": "tool",
  "content": "ls result...",
  "tool_call_id": "call_abc123"
}
```

**Without this:** API returns `400 Bad Request: tool_call_id is not found`

### 2. `tool_calls` on `role: "assistant"` messages that initiate tool calls

When the assistant message contains tool invocations, it must include the `tool_calls` array:

```json
{
  "role": "assistant",
  "content": null,
  "tool_calls": [
    {
      "id": "call_abc123",
      "type": "function",
      "function": {
        "name": "fs",
        "arguments": "{\"command\": \"ls\"}"
      }
    }
  ]
}
```

**Without this:** The API cannot correlate the tool result with the original request.

## Empty Content Pitfall

When an assistant message has `tool_calls` but no text content, the API requires `content` to be `null`, NOT an empty string `""`:

```rust
let content = if m.role == "assistant" && m.content.is_empty() && m.tool_calls.is_some() {
    serde_json::Value::Null
} else {
    m.to_openai_content()
};
```

**Without this:** API returns `400 Bad Request: {"error":{"message":"the message at position N with role 'assistant' must not be empty","type":"invalid_request_error"}}`

**Why:** The API treats `""` as "present but empty" (invalid), but `null` as "intentionally absent" (valid for tool-calling messages).

## Streaming Accumulation

Tool calls arrive as fragments across SSE chunks. Accumulate by `index`:

```rust
let mut pending: HashMap<u32, AccumulatedToolCall> = HashMap::new();

// In each SSE chunk:
for tc in delta.tool_calls {
    let idx = tc.index.unwrap_or(0) as u32;
    let entry = pending.entry(idx).or_default();
    if let Some(id) = tc.id { entry.id.push_str(id); }
    if let Some(name) = tc.function.name { entry.name.push_str(name); }
    if let Some(args) = tc.function.arguments { entry.arguments.push_str(args); }
}

// On finish_reason == "tool_calls":
for (idx, tc) in pending.drain() {
    emit ToolCall { id: tc.id, name: tc.name, arguments: tc.arguments };
}
```

**Key lesson:** Arguments stream as partial JSON strings. Concatenate all fragments before parsing.

## Rust Implementation Pattern

Add fields to your `Message` struct:

```rust
#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct Message {
    pub role: String,
    pub content: String,
    #[serde(skip_serializing_if = "Option::is_none", default)]
    pub images: Option<Vec<String>>,
    #[serde(skip_serializing_if = "Option::is_none", default)]
    pub tool_call_id: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none", default)]
    pub tool_calls: Option<Vec<ToolCallRequest>>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ToolCallRequest {
    pub id: String,
    pub r#type: String,
    pub function: ToolCallFunction,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ToolCallFunction {
    pub name: String,
    pub arguments: String,
}
```

Serialize conditionally in the request body builder:

```rust
let content = if m.role == "assistant" && m.content.is_empty() && m.tool_calls.is_some() {
    serde_json::Value::Null
} else {
    m.to_openai_content()
};
let mut msg = json!({
    "role": m.role,
    "content": content,
});
if let Some(ref id) = m.tool_call_id {
    msg["tool_call_id"] = json!(id);
}
if let Some(ref calls) = m.tool_calls {
    msg["tool_calls"] = json!(calls);
}
```

## Blast Radius Warning

Adding fields to a widely-used struct like `Message` requires updating **all** struct literal constructions across the codebase. In Rust, `Default` derive helps but struct literals without `..Default::default()` must include all fields.

**Workflow:**
1. Add fields to struct + constructors (`Message::text()`, `Message::with_image()`)
2. Run `cargo check` to find all broken struct literals
3. Fix systematically — use a script for bulk updates if there are many
4. Verify no accidental hits on similarly-named structs (`ChatMessage`, `MemoryMessage`, etc.)

## Common Errors

### `tool_call_id is not found`
```
[API error 400 Bad Request: {"error":{"message":"tool_call_id is not found","type":"invalid_request_error"}}]
```

**Diagnosis:** The follow-up request after tool execution is missing `tool_call_id` on the `role: "tool"` message, or the assistant message initiating the tool call lacks `tool_calls`.

**Fix:** Thread the `tool_call_id` from the original `StreamChunk::ToolCall { id, ... }` through to both the assistant message (as `tool_calls`) and the tool result message (as `tool_call_id`).

### `assistant message must not be empty`
```
[API error 400 Bad Request: {"error":{"message":"the message at position N with role 'assistant' must not be empty","type":"invalid_request_error"}}]
```

**Diagnosis:** Assistant message has `tool_calls` but `content` is serialized as `""` instead of `null`.

**Fix:** Emit `content: null` (not `""`) when `role == "assistant"`, `content.is_empty()`, and `tool_calls.is_some()`.
