# kimi-k2.6 Tool Calling Integration — Complete Reference

## Context

Session: 2026-06-01. OpenShark `openshark chat "run ls"` with kimi-k2.6 via kimi-coding proxy (`127.0.0.1:8699`). Model was outputting raw `<think>` tags to stdout alongside tool calls. We fixed the tool calling; the thinking text display remains an open question.

## Model ID Mapping

| User-facing | Proxy internal | API request |
|-------------|---------------|-------------|
| `kimi-k2.6` | `kimi-for-coding` | `kimi-for-coding` |

The proxy at `127.0.0.1:8699` maps `kimi-k2.6` → `kimi-for-coding`. Use `kimi-for-coding` in API requests.

## What Worked (Tool Calling)

### 1. Tools array in request body

The model ONLY tool-calls when the API request includes `tools`. System prompt alone is insufficient.

```rust
let mut request = ChatRequest::new(model, messages, true);
request.tools = Some(tools::get_openai_tool_definitions());
```

### 2. Strong system prompt

RLHF/safety training overrides weak prompts. The system prompt must frame the model as an agent, not a chatbot:

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
4. Low and Medium risk tools execute automatically.
5. High risk tools require user approval.
6. If the user says 'test', run the test tool immediately.
7. For one-line tasks, just do it. No manifesto.
```

### 3. Streaming tool call accumulation

Tool calls arrive as fragments across SSE chunks. Accumulate by index:

```rust
#[derive(Debug, Clone, Default)]
pub struct AccumulatedToolCall {
    pub id: String,
    pub name: String,
    pub arguments: String,
}

// In the streaming loop:
let mut pending_tool_calls: HashMap<u32, AccumulatedToolCall> = HashMap::new();

// Per-chunk:
if let Some(tcs) = tool_calls {
    for tc in tcs {
        let index = tc.get("index").and_then(|i| i.as_u64()).unwrap_or(0) as u32;
        let entry = pending_tool_calls.entry(index).or_default();
        if let Some(id) = tc.get("id").and_then(|i| i.as_str()) { if !id.is_empty() { entry.id.push_str(id); } }
        if let Some(name) = tc.get("function").and_then(|f| f.get("name")).and_then(|n| n.as_str()) { if !name.is_empty() { entry.name.push_str(name); } }
        if let Some(args) = tc.get("function").and_then(|f| f.get("arguments")).and_then(|a| a.as_str()) { entry.arguments.push_str(args); }
    }
}

// On finish_reason == "tool_calls":
for (_, tc) in pending_tool_calls.drain() {
    let _ = tx.send(StreamChunk::ToolCall { id: tc.id, name: tc.name, arguments: tc.arguments });
}
let _ = tx.send(StreamChunk::Finish("tool_calls".to_string()));
```

### 4. Reasoning content parsing

kimi-k2.6 emits reasoning in a separate `reasoning_content` delta field (NOT inside `<think>` tags in `content`):

```rust
let content = event.get("choices").and_then(|c| c.get(0)).and_then(|c| c.get("delta")).and_then(|d| d.get("content")).and_then(|c| c.as_str());
let reasoning = event.get("choices").and_then(|c| c.get(0)).and_then(|c| c.get("delta")).and_then(|d| d.get("reasoning_content")).and_then(|c| c.as_str());

if let Some(r) = reasoning {
    if !r.is_empty() {
        // Emit as StreamChunk::Reasoning for real-time display
        let _ = tx.send(StreamChunk::Reasoning(r.to_string()));
    }
}
```

This is a **cloud model pattern** — reasoning arrives in a separate field. Do NOT treat `reasoning_content` as regular content. Do NOT fall back to it when `content` is empty.

## CLI vs TUI Path Divergence

| Path | Function | Returns | Tool Calling Strategy |
|------|----------|---------|----------------------|
| **TUI** | `chat_stream_realtime()` | `StreamChunk` enum | Native `StreamChunk::ToolCall` + `StreamChunk::Reasoning` |
| **CLI** | `chat_stream()` | `Vec<String>` chunks | Parse embedded `TOOL:` lines from response text |

The CLI cannot use `StreamChunk::ToolCall` because `chat_stream()` returns raw text, not structured events. Instead:

```rust
fn parse_embedded_tools_cli(text: &str) -> Vec<(String, String)> {
    let mut tools = Vec::new();
    let re = regex::Regex::new(r"TOOL[:\.]\s*(\S+)(?:\s+(.*))?$")?;
    for cap in re.captures_iter(text) {
        let tool_name = cap.get(1).map(|m| m.as_str().trim()).unwrap_or("").to_string();
        let args = cap.get(2).map(|m| m.as_str().trim()).unwrap_or("").to_string();
        // Handle JSON-like command="value" format
        let args = if args.starts_with("command=\"") && args.ends_with("\"") {
            args[9..args.len()-1].to_string()
        } else {
            args
        };
        if !tool_name.is_empty() { tools.push((tool_name, args)); }
    }
    tools
}
```

## The Thinking Text Question (Resolved)

After fixing tool calling, raw `<think>` tags still stream to stdout in CLI mode. The TUI handles reasoning properly via `StreamChunk::Reasoning` → `StreamEvent::ReasoningChunk` → muted 💭 display.

### Root Cause

The model emits reasoning in TWO ways simultaneously:
1. `reasoning_content` delta field (structured, what we parse)
2. `<think>...</think>` blocks inside `content` (raw text, what leaks through)

### Fix: Deduplicate in Provider Parser

When `reasoning_content` is present, emit `StreamChunk::Reasoning` and filter out `<think>` blocks from `content`:

```rust
// In the SSE parsing loop:
if let Some(r) = reasoning {
    if !r.is_empty() {
        let _ = tx.send(StreamChunk::Reasoning(r.to_string()));
    }
}
if let Some(c) = content {
    if !c.is_empty() {
        // Strip any <think> blocks that the model included in content
        let clean = strip_think_tags(c);
        if !clean.is_empty() {
            let _ = tx.send(StreamChunk::Content(clean));
        }
    }
}
```

### CLI Thinking Text Options

For the CLI path (`chat_stream()` returning `Vec<String>`), two approaches:

**Option A: Strip before display** (clean output, good for scripting):
```rust
let clean_response = strip_think_tags(&full_response);
println!("{}", clean_response);
```

**Option B: Dim with ANSI** (preserves transparency):
```rust
for chunk in &chunks {
    if chunk.contains("<think>") || chunk.contains("</think>") {
        print!("\x1b[2m{}\x1b[0m", chunk);  // dim
    } else {
        print!("{}", chunk);
    }
}
```

**Current state (2026-06-01):** No CLI reasoning display implemented. Raw `<think>` tags print to stdout. TUI handles reasoning via `StreamChunk::Reasoning` properly.

## Commit Reference

`c465666` — `feat: streaming tool calling + reasoning content for kimi-k2.6`
- 23 files changed, 1527 insertions(+), 141 deletions(-)
- `StreamChunk` enum with `Reasoning`, `Content`, `ToolCall`, `Finish` variants
- `AccumulatedToolCall` for streaming fragment accumulation
- `ToolDefinition`/`ToolFunction` structs for OpenAI-compatible tool schema
- `reasoning_content` delta parsing in provider SSE loop
- CLI embedded `TOOL:` line parsing and execution
- `TOOL:` and `TOOL.` prefix support in message router
