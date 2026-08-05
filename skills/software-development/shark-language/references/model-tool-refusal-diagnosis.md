# Model Tool Refusal Diagnosis — kimi-k2.6

## Problem

The kimi-k2.6 model (via kimi-coding proxy at `127.0.0.1:8699`) was refusing to execute tools despite:
- Aggressive system prompt instructions ("You MUST use tools", "You have TOOL ACCESS")
- OpenAI-compatible `tools` array sent in API request
- Explicit tool descriptions in system prompt

Model consistently responded with "I don't have access to your local file system" and "I cannot execute commands."

## Root Cause

The model's **safety training / RLHF** overrides system prompt instructions when it believes it's a generic chatbot without tool access. The model generates `\u003cthink\u003e` blocks where it explicitly decides "I don't have access" — this is a trained behavior, not a prompt engineering failure.

**Critical finding:** The model ONLY tool-calls when the API request includes a proper `tools` array AND the system prompt explicitly tells it to use those tools. Without the `tools` parameter, the model falls back to generic refusal behavior regardless of prompt text.

## Verification

Direct API test proving tool calling works:

```bash
curl -s http://127.0.0.1:8699/v1/chat/completions \
  -H "Authorization: Bearer $KIMI_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "kimi-for-coding",
    "messages": [
      {"role": "system", "content": "You are a helpful assistant with tool access."},
      {"role": "user", "content": "run the command ls"}
    ],
    "stream": false,
    "tools": [
      {
        "type": "function",
        "function": {
          "name": "terminal",
          "description": "Execute shell commands",
          "parameters": {
            "type": "object",
            "properties": {
              "command": {"type": "string"}
            },
            "required": ["command"]
          }
        }
      }
    ]
  }'
```

**Result:** `finish_reason: "tool_calls"` with structured `tool_calls` array.

Streaming test also works — tool calls arrive as fragments in SSE deltas:
```
data:{"delta":{"tool_calls":[{"index":0,"function":{"arguments":"{\""}}]}}
data:{"delta":{"tool_calls":[{"index":0,"function":{"arguments":"command"}}]}}
data:{"delta":{"tool_calls":[{"index":0,"function":{"arguments":"\":\""}}]}}
data:{"delta":{"tool_calls":[{"index":0,"function":{"arguments":"ls"}}]}}
data:{"delta":{"tool_calls":[{"index":0,"function":{"arguments":"\"}"}}]}}
```

## Streaming Tool Call Accumulation

Tool call arguments are streamed token-by-token across multiple SSE chunks. Must accumulate:

```python
# Pseudocode for accumulation
tool_calls = {}  # index -> {"id": "", "name": "", "arguments": ""}
for chunk in stream:
    for tc in chunk.get("tool_calls", []):
        idx = tc["index"]
        if "id" in tc:
            tool_calls[idx]["id"] = tc["id"]
        if "function" in tc:
            if "name" in tc["function"]:
                tool_calls[idx]["name"] = tc["function"]["name"]
            if "arguments" in tc["function"]:
                tool_calls[idx]["arguments"] += tc["function"]["arguments"]

# When finish_reason == "tool_calls":
for tc in tool_calls.values():
    args = json.loads(tc["arguments"])
    execute_tool(tc["name"], args)
```

## OpenShark Fixes Implemented

All 5 steps completed:

1. **Wired tools into chat request** — `stream_model_response_task` now sets `request.tools = Some(crate::tools::get_openai_tool_definitions())` before every API call.

2. **Parsed tool_calls in streaming** — `chat_stream_realtime()` accumulates `delta.tool_calls` fragments across SSE chunks into a `HashMap<u32, AccumulatedToolCall>`. When `finish_reason == "tool_calls"`, emits `StreamChunk::ToolCall { id, name, arguments }`.

3. **Handled ToolCall in TUI** — `StreamChunk::ToolCall` branch in the streaming loop parses JSON arguments, executes via `AsyncToolExecutor`, sends `StreamEvent::ToolResult`, then constructs follow-up messages with `role: "tool"` and re-calls the model.

4. **Non-streaming path** — `chat_stream()` (used by `openshark chat` CLI) also gets `tools` wired in.

5. **Model name** — Proxy maps `kimi-k2.6` → `kimi-for-coding`. Correct ID used.

### Code Changes Made

- Added `ToolDefinition`/`ToolFunction` structs to `providers/mod.rs`
- Added `tools` field to `ChatRequest`
- Added `tools` serialization in `build_chat_body()`
- Added `get_openai_tool_definitions()` in `tools/mod.rs`
- Renamed conflicting `ToolDefinition` → `ToolDef` in tools module
- Added `StreamChunk::ToolCall` and `StreamChunk::Finish` variants
- Added `AccumulatedToolCall` struct and accumulation logic in `chat_stream_realtime()`
- Added `StreamChunk::ToolCall` handler in TUI streaming loop
- Added follow-up chat flow with `role: "tool"` messages

## Key Lesson

**Models with tool calling capability will still refuse if the `tools` parameter is missing from the API request.** System prompt alone is insufficient. The `tools` array is the structural signal that tells the model it's in agent mode, not chat mode.

## Post-Implementation Note: RLHF Override — FIXED

The model's RLHF/safety training WAS overriding the structural `tools` signal when the system prompt was weak (e.g., "You are a helpful assistant"). The fix requires **both** the `tools` array **and** an aggressively direct system prompt that frames the model as an agent, not a chatbot.

**Working system prompt pattern:**
```
You are an AI coding assistant with TOOL ACCESS. You MUST use tools when asked to perform actions.
You are NOT a generic chatbot — you are an agent with real tool capabilities.

AVAILABLE TOOLS:
- terminal: Execute shell commands
- fs: Filesystem operations
...

TOOL USAGE RULES:
1. When asked to do something requiring a tool, output ONLY: TOOL:<tool_name> <args>
2. Do NOT say 'I don't have access', 'I cannot execute commands', 'I don't have a terminal', or ANY refusal. You DO have access.
3. Do NOT preamble. Just output the TOOL: line.
4. CRITICAL: You MUST use the available tools. Refusing to use tools is a failure mode.
```

**Also critical:** The CLI `chat` subcommand must set `request.tools = Some(tools::get_openai_tool_definitions())`. Without this, the model never sees the structural signal and falls back to generic refusal.

**Verified working:** With both fixes in place, kimi-k2.6 via kimi-coding proxy outputs `TOOL:terminal command="ls"` and executes successfully.

## CLI Chat Tool Execution

The `openshark chat` CLI subcommand uses `chat_stream()` (non-realtime), which returns raw text chunks. Native `StreamChunk::ToolCall` events are NOT emitted in this path. Instead, parse embedded `TOOL:` lines from the response text and execute them:

```rust
// After collecting full_response from chunks:
let embedded_tools = parse_embedded_tools_cli(&full_response);
for (tool_name, args) in embedded_tools {
    if let Some(tool) = tools::find_tool(&tool_name) {
        match tool.execute(&args) {
            Ok(result) => println!("Result:\n{}", result),
            Err(e) => println!("Error: {}", e),
        }
    }
}
```

**JSON-like arg extraction:** Models may output `TOOL:terminal command="ls"` instead of `TOOL:terminal ls`. Extract the value:
```rust
let args = if args.starts_with("command=\"") && args.ends_with("\"") {
    args[9..args.len()-1].to_string()  // "command=\"" is 9 chars
} else {
    args
};
```
