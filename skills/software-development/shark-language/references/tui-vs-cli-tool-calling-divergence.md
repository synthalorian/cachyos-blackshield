# TUI vs CLI Tool Calling Divergence

## Problem

Tool calling works in `openshark chat` (CLI) but fails in TUI mode, or vice versa. The model either refuses to use tools, outputs raw `<think>` tags, or the tool execution silently fails.

## Root Cause: Two Different Code Paths

OpenShark has **two completely different streaming implementations**:

### CLI Path (`openshark chat`)
- Uses `Provider::chat_stream()` → returns `Vec<String>` chunks
- Reasoning content wrapped in `<think>...</think>` tags by provider
- Embedded `TOOL:` lines parsed from raw text via regex
- No real-time display of reasoning

### TUI Path (`openshark tui`)
- Uses `Provider::chat_stream_realtime()` → returns `StreamChunk` enum via channel
- `StreamChunk::Reasoning(r)` — real-time reasoning deltas
- `StreamChunk::Content(c)` — response content
- `StreamChunk::ToolCall { id, name, arguments }` — native OpenAI function calling
- `StreamChunk::Finish(fr)` — completion signal

## Why This Causes Failures

1. **Model confusion**: When both `tools` array AND system prompt `TOOL:` instructions are sent, the model may get confused about which format to use
2. **Reasoning text interference**: kimi-k2.6 sends `reasoning_content` in `delta.reasoning_content`. If not properly extracted, `<think>` tags leak into `full_content` and break `parse_embedded_tools()`
3. **Double handling**: `ResponseComplete` event in TUI checks for embedded tools AND the background task also checks — potential race or duplicate execution
4. **Path-specific bugs**: A fix in one path (e.g., CLI) doesn't automatically apply to the other (TUI)

## Debugging Checklist

When "it failed the task" with minimal feedback:

1. **Identify which path failed** — CLI or TUI? They're different code.
2. **Check the raw response** — Add logging to see what the model actually output:
   ```rust
   eprintln!("RAW RESPONSE: {:?}", full_content);
   ```
3. **Verify reasoning extraction** — In TUI, `reasoning_content` should NOT be in `full_content`. Check `extract_thinking_from_chunk()`.
4. **Check for `<think>` tag pollution** — `parse_embedded_tools()` searches for `TOOL:` lines. If `<think>` blocks contain "TOOL:" text, false positives occur.
5. **Verify `tools` array is sent** — Log the request body. Without `tools`, models refuse.
6. **Check system prompt strength** — Weak prompts = model refuses. Strong prompts = model complies but may over-elaborate.

## Code Locations

| Function | File | Purpose |
|----------|------|---------|
| `chat_stream()` | `src/providers/mod.rs:448` | CLI path — returns `Vec<String>` |
| `chat_stream_realtime()` | `src/providers/mod.rs:578` | TUI path — returns `StreamChunk` receiver |
| `stream_model_response_task()` | `src/tui/mod.rs:2161` | TUI background task |
| `apply_stream_event()` | `src/tui/mod.rs:712` | TUI event handler |
| `parse_embedded_tools()` | `src/tui/mod.rs:1935` | Parse `TOOL:` lines from text |
| `parse_embedded_tools_cli()` | `src/main.rs:29` | CLI version of parser |
| `get_openai_tool_definitions()` | `src/tools/mod.rs:75` | Build `tools` array for API |

## Fix Pattern: Unified Tool Detection

Both paths should use the same tool detection logic. Current state (post-commit `c465666`):
- TUI: Native `StreamChunk::ToolCall` + embedded `TOOL:` fallback
- CLI: Embedded `TOOL:` only

**Ideal:** Both paths use the same `parse_embedded_tools()` function, same system prompt, same `tools` array.

## Related

- `references/kimi-k2.6-tool-calling-integration.md` — Full kimi-k2.6 integration
- `references/cli-chat-tool-execution.md` — CLI tool execution specifics
- `references/real-time-reasoning-streaming-pattern.md` — TUI reasoning display
- `references/model-tool-refusal-diagnosis.md` — When models refuse despite correct API
