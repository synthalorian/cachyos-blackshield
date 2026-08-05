# TUI Native Tool Calling — Real Bugs from Integration

Session: 2026-06-01 — OpenShark commit `c465666` (streaming tool calling + reasoning)
Model: kimi-k2.6 via kimi-coding proxy

## Bug 1: JSON Args Not Parsed for Shell Execution

**Symptom:** User types `run ls` in TUI. Model calls `terminal` tool with args `{"command": "ls"}`. Tool executes `sh -c {command: "ls"}` which fails:
```
[stderr]: sh: line 1: {command:: command not found
```

**Root cause:** The `tool_args` extraction in `stream_model_response_task` only handles `command` and `args` fields for SOME tools, but the terminal tool's JSON schema uses `{"command": "..."}` and the extraction code was present but the shell tool still received raw JSON.

**Code path:**
```rust
// src/tui/mod.rs ~line 2233
let tool_args = match serde_json::from_str::<serde_json::Value>(&args) {
    Ok(v) => {
        if let Some(cmd) = v.get("command").and_then(|c| c.as_str()) {
            cmd.to_string()  // This SHOULD extract "ls"
        } else if let Some(a) = v.get("args").and_then(|a| a.as_str()) {
            a.to_string()
        } else {
            args.clone()  // Falls through to here if extraction fails
        }
    }
    Err(_) => args.clone(),
};
```

**Why it failed:** The model may have output malformed JSON or the `command` field was nested differently. The fallback `args.clone()` passes raw JSON to `sh -c`.

**Fix needed:** More robust JSON arg extraction + validation before passing to shell tools.

## Bug 2: Empty Assistant Message After Native Tool Call

**Symptom:** After tool execution, follow-up request fails:
```
API error 400 Bad Request: {"error":{"message":"the message at position 2 with role 'assistant' must not be empty","type":"invalid_request_error"}}
```

**Root cause:** When model makes a native tool call without text content, `full_content` is empty string `""`. We push:
```rust
follow_messages.push(Message {
    role: "assistant".to_string(),
    content: full_content.clone(),  // ""
    images: None,
});
```

**Fix needed:** When `full_content.trim().is_empty()`, use a placeholder like `"Using tool: {name}"` or skip the assistant message and only send the tool result.

## Code Locations

| File | Lines | Purpose |
|------|-------|---------|
| `src/tui/mod.rs` | 2230-2260 | JSON arg extraction in native tool call handler |
| `src/tui/mod.rs` | 2268-2280 | Follow-up message building with empty assistant content |
| `src/providers/mod.rs` | 228-245 | `build_chat_body` — serializes messages including empty content |
| `src/tools/terminal.rs` | 17-20 | `sh -c {args}` — receives raw JSON when extraction fails |

## Debugging Checklist for "It Failed the Task"

When user says tool calling failed with minimal feedback:

1. **Check WHICH path failed** — CLI (`chat_stream`) or TUI (`chat_stream_realtime`)? They diverge completely.
2. **Look at actual error output** — Don't guess. The screenshot showed `[stderr]: sh: line 1: {command:: command not found` which immediately points to JSON args not being parsed.
3. **Trace the code path** — Native tool call (`StreamChunk::ToolCall`) vs embedded `TOOL:` line detection? Different handlers, different bugs.
4. **Verify assistant message content** — If follow-up fails with 400, check if assistant message is empty.
5. **Check `full_content` accumulation** — For native tool calls, `full_content` only accumulates `StreamChunk::Content`, not `StreamChunk::ToolCall`. So it's empty by design.

## Prevention

- Always validate tool args before passing to shell execution
- Never send empty assistant messages to the API
- Log the raw tool call args for debugging
- Test with both native tool calls AND embedded `TOOL:` syntax
