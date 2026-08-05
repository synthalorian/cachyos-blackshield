# CLI Chat Tool Execution Pattern

## Problem

The `openshark chat` CLI subcommand uses `chat_stream()` which returns raw `Vec<String>` chunks — not structured `StreamChunk` events. Native OpenAI function calling (`StreamChunk::ToolCall`) only works in the TUI's `chat_stream_realtime()` path. The CLI must parse and execute embedded `TOOL:` lines from the response text.

## Solution

### 1. Strong System Prompt + Tools Array

The CLI must set BOTH an agent-framed system prompt AND the `tools` array:

```rust
let system_prompt = format!(
    "You are an AI coding assistant with TOOL ACCESS. You MUST use tools when asked to perform actions. \
     You are NOT a generic chatbot — you are an agent with real tool capabilities. \
     \n\nAVAILABLE TOOLS:\n{}\n\nTOOL USAGE RULES:\n\
     1. When asked to do something requiring a tool, output ONLY: TOOL:<tool_name> <args>\n\
     2. Do NOT say 'I don't have access' or 'I cannot execute commands'. You DO have access.\n\
     3. Do NOT preamble. Just output the TOOL: line.\n\
     4. CRITICAL: You MUST use the available tools. Refusing to use tools is a failure mode.",
    tool_descriptions
);

let mut request = ChatRequest::new(model, messages, true);
request.tools = Some(tools::get_openai_tool_definitions());
```

**Without `request.tools`, the model will refuse regardless of prompt text.**

### 2. Parse Embedded TOOL: Lines

After collecting the full response, extract and execute tool invocations:

```rust
fn parse_embedded_tools_cli(text: &str) -> Vec<(String, String)> {
    let mut tools = Vec::new();
    let re = match regex::Regex::new(r"TOOL[:\.]\s*(\S+)(?:\s+(.*))?$") {
        Ok(r) => r,
        Err(_) => return tools,
    };
    for cap in re.captures_iter(text) {
        let tool_name = cap.get(1).map(|m| m.as_str().trim()).unwrap_or("").to_string();
        let args = cap.get(2).map(|m| m.as_str().trim()).unwrap_or("").to_string();
        if tool_name.is_empty() { continue; }
        // Handle JSON-like `command="value"` format
        let args = if args.starts_with("command=\"") && args.ends_with("\"") {
            args[9..args.len()-1].to_string()  // "command=\"" is 9 chars
        } else {
            args
        };
        tools.push((tool_name, args));
    }
    tools
}
```

### 3. Execute and Display Results

```rust
let embedded_tools = parse_embedded_tools_cli(&full_response);
if !embedded_tools.is_empty() {
    for (tool_name, args) in embedded_tools {
        println!("🔧 Executing: {} {}", tool_name, args);
        match tools::find_tool(&tool_name) {
            Some(tool) => {
                match tool.execute(&args) {
                    Ok(result) => println!("✅ Result:\n{}", result),
                    Err(e) => println!("❌ Error: {}", e),
                }
            }
            None => println!("❌ Unknown tool: {}", tool_name),
        }
    }
}
```

## JSON-Like Arg Extraction

Models trained on OpenAI function calling may output `TOOL:terminal command="ls"` instead of `TOOL:terminal ls`. The `command="..."` wrapper must be stripped:

| Raw Output | Extracted Args |
|---|---|
| `TOOL:terminal command="ls"` | `ls` |
| `TOOL:terminal command="ls -la"` | `ls -la` |
| `TOOL:fs operation="read" path="file.txt"` | `operation="read" path="file.txt"` (fs tool handles its own parsing) |

Slice math: `command="` is 9 characters (`c-o-m-m-a-n-d-=-"`), so `args[9..args.len()-1]` extracts the inner value.

## Thinking Text in CLI Mode

When using reasoning models (kimi-k2.6, DeepSeek-R1) via CLI, raw `<think>` tags stream to stdout alongside the response:

```
<think>The user wants to run the `ls` command. This is a terminal operation.
I should use the `terminal` tool to execute this command.</think>
TOOL:terminal command="ls"
```

The CLI path (`chat_stream()`) returns raw text, not structured `StreamChunk` events. Two approaches:

### Option A: Strip `<think>` blocks before display

Filter out `<think>...</think>` blocks in the stream parser or after collecting the full response:

```rust
fn strip_think_tags(text: &str) -> String {
    let mut result = text.to_string();
    while let Some(start) = result.find("<think>") {
        if let Some(end) = result.find("</think>") {
            result.replace_range(start..end + 8, "");
        } else {
            break;
        }
    }
    result.trim().to_string()
}
```

This gives clean output but loses reasoning visibility. Good for scripting/automation.

### Option B: Render reasoning dimmed (like TUI)

Use ANSI escape codes to dim reasoning text while streaming:

```rust
// In the chunk-printing loop:
for chunk in &chunks {
    if chunk.starts_with("<think>") || chunk.contains("</think>") {
        // Dim the text
        print!("\x1b[2m{}\x1b[0m", chunk);
    } else {
        print!("{}", chunk);
    }
}
```

This preserves transparency but requires terminal support for ANSI dim codes.

**Current state (2026-06-01):** No CLI reasoning display implemented. Raw `<think>` tags print to stdout. The TUI handles reasoning properly via `StreamChunk::Reasoning` → `StreamEvent::ReasoningChunk` → muted 💭 display.

## Testing

```bash
# Should output TOOL:terminal command="ls" then execute it
openshark chat "run ls"

# Should output TOOL:fs command="list" then list directory
openshark chat "what files are here?"
```

## Related

- `references/model-tool-refusal-diagnosis.md` — Why models refuse and how to fix it
- `references/streaming-tool-call-accumulation.md` — Realtime streaming path (TUI)
- `references/tui-real-time-reasoning-display.md` — TUI reasoning display (dual-stream ephemeral)
