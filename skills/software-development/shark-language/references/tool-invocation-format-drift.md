# Tool Invocation Format Drift — Full-Scope Audit Pattern

## Problem

The model outputs `TOOL.tool_name args` (dot separator) instead of the expected
`TOOL:tool_name args` (colon separator). If the parser only accepts one format,
tools silently fail — dead text in chat, 0ms execution time, user thinks it's hung.

## Root Cause

System prompts tell the model to use `TOOL:`, but models drift. Kimi k2.6 in
particular often outputs `TOOL.fs cat ...` instead of `TOOL:fs cat ...`. The
`parse_embedded_tools()` function only checked for `starts_with("TOOL:")`, so
`TOOL.` lines were treated as plain text.

## Symptoms

- TUI shows `TOOL.fs list /path` but no results appear
- Tool execution time stays at `0ms`
- Sidebar shows active tools but nothing happens
- Model gets confused and tries `fs.list` (wrong format entirely)

## Full-Scope Fix

Every location that parses, detects, strips, or generates tool invocations must
accept both formats. Here's the complete audit checklist:

### 1. Embedded tool parsing (`src/tui/mod.rs`)

```rust
fn parse_embedded_tools(text: &str) -> Vec<(String, String)> {
    let mut tools = Vec::new();
    for line in text.lines() {
        let trimmed = line.trim();
        let prefix = if trimmed.starts_with("TOOL:") {
            Some("TOOL:")
        } else if trimmed.starts_with("TOOL.") {
            Some("TOOL.")
        } else {
            None
        };
        if let Some(p) = prefix {
            let rest = &trimmed[p.len()..];
            let rest = rest.trim_start();
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

### 2. Tool line stripping (`src/tui/mod.rs`)

```rust
fn strip_tool_lines(text: &str) -> String {
    let mut result = String::new();
    for line in text.lines() {
        let trimmed = line.trim();
        if !trimmed.starts_with("TOOL:") && !trimmed.starts_with("TOOL.") {
            // ... append line
        }
    }
    result
}
```

### 3. Explicit tool detection regex (`src/tools/detection.rs`)

```rust
// BEFORE — only matches TOOL:
let re = Regex::new(r"(?m)^\s*TOOL:\s*(\S+)(?:\s+(.*))?$")?;

// AFTER — matches both TOOL: and TOOL.
let re = Regex::new(r"(?m)^\s*TOOL[:\.]\s*(\S+)(?:\s+(.*))?$")?;
```

### 4. User input handler (`src/tui/mod.rs`)

```rust
// BEFORE
if input.starts_with("TOOL:") {
    handle_user_tool_invocation(app, &input)?;
}

// AFTER
if input.starts_with("TOOL:") || input.starts_with("TOOL.") {
    handle_user_tool_invocation(app, &input)?;
}
```

### 5. Single-tool response handler (`src/tui/mod.rs`)

```rust
// In ResponseComplete handler
} else if content.starts_with("TOOL:") || content.starts_with("TOOL.") {
    let rest = if content.starts_with("TOOL:") { &content[5..] } else { &content[5..] };
    // ... parse tool_name and args
}
```

### 6. Chained tool check (`src/tui/mod.rs`)

```rust
// In execute_approved_tool_task follow-up handler
if !follow_content.starts_with("TOOL:") && !follow_content.starts_with("TOOL.") {
    // ... process as normal text
}
```

### 7. System prompts (`src/tui/mod.rs`, `src/swarm/mod.rs`, `src/gateway/channel_state.rs`)

All system prompts must tell the model both formats work:

```
When you need to use a tool, output it as: TOOL:<tool_name> <args> or TOOL.<tool_name> <args>
```

Files to update:
- `src/tui/mod.rs` — TUI system message construction
- `src/swarm/mod.rs` — Swarm agent system prompts
- `src/gateway/channel_state.rs` — Discord/Telegram bot system prompts (both `new()` and `reset()`)

### 8. Gateway tool execution (`src/gateway/message_router.rs`)

```rust
async fn try_execute_tools(&self, response: &str) -> Option<String> {
    let tool_start = response.find("TOOL:").or_else(|| response.find("TOOL."))?;
    let tool_line = &response[tool_start..];
    let tool_line = tool_line.lines().next()?;
    let rest = if tool_line.starts_with("TOOL:") {
        &tool_line[5..]
    } else {
        &tool_line[5..]
    };
    // ... parse and execute
}
```

### 9. CLI help text (`src/main.rs`)

```rust
println!("  In TUI, use TOOL:<tool_name> <args> or TOOL.<tool_name> <args> to execute manually.");
```

## Prevention

Use helper functions instead of hardcoding `starts_with("TOOL:")` in multiple places:

```rust
pub fn is_tool_invocation(line: &str) -> bool {
    let trimmed = line.trim();
    trimmed.starts_with("TOOL:") || trimmed.starts_with("TOOL.")
}

pub fn parse_tool_invocation_line(line: &str) -> Option<(String, String)> {
    let trimmed = line.trim();
    let rest = if trimmed.starts_with("TOOL:") {
        &trimmed[5..]
    } else if trimmed.starts_with("TOOL.") {
        &trimmed[5..]
    } else {
        return None;
    };
    let rest = rest.trim_start();
    let parts: Vec<&str> = rest.splitn(2, ' ').collect();
    if parts.is_empty() || parts[0].is_empty() {
        return None;
    }
    Some((parts[0].trim().to_string(), parts.get(1).unwrap_or(&"").trim().to_string()))
}
```

## Tests to Add

```rust
#[test]
fn test_explicit_tool_with_dot_separator() {
    let text = "TOOL.fs cat /home/synth/projects/README.md";
    let suggestions = detect_tool_suggestions(text);
    assert_eq!(suggestions.len(), 1);
    assert_eq!(suggestions[0].tool_name, "fs");
    assert_eq!(suggestions[0].args, "cat /home/synth/projects/README.md");
}

#[test]
fn test_explicit_tool_with_space_after_dot() {
    let text = "TOOL. fs cat /home/synth/projects/README.md";
    let suggestions = detect_tool_suggestions(text);
    assert_eq!(suggestions.len(), 1);
    assert_eq!(suggestions[0].tool_name, "fs");
}
```

## Related

- `references/tui-tool-separator-quirk.md` — The specific incident that triggered this audit
- `references/tui-embedded-tool-execution-pattern.md` — How embedded tools are parsed and executed
- `references/tui-streaming-hang-comprehensive-fix.md` — Missing Done signals compound the visible symptom
