# Tool JSON Args Dual-Format Pattern

When a tool is exposed via OpenAI native function calling, the model sends arguments as a JSON object (e.g., `{"operation": "list", "path": "/home/synth"}`). But the same tool may also be called via embedded text parsing (e.g., `TOOL:fs list /home/synth`). The tool's `execute()` method must handle both formats.

## The Problem

The `fs` tool's schema tells the model to pass JSON:
```json
{
  "operation": "list",
  "path": "/home/synth/projects"
}
```

But `FsTool::execute()` expected flat strings:
```rust
fn execute(&self, args: &str) -> Result<String> {
    let parts: Vec<&str> = args.splitn(2, ' ').collect();
    let cmd = parts[0];  // "list"
    let rest = parts[1]; // "/home/synth/projects"
}
```

Result: `Unknown fs command: operation='list'` — the JSON string `"{"operation":"list",...}"` gets split on space, `cmd` becomes the whole JSON blob, and no match is found.

## The Fix

Try JSON parsing first, fall back to flat string format:

```rust
fn execute(&self, args: &str) -> Result<String> {
    // Try parsing as JSON first (native tool calling format)
    if let Ok(json) = serde_json::from_str::<serde_json::Value>(args) {
        if let Some(op) = json.get("operation").and_then(|v| v.as_str()) {
            let path = json.get("path").and_then(|v| v.as_str()).unwrap_or(".");
            match op {
                "read" => return cmd_read(path),
                "write" => {
                    let content = json.get("content").and_then(|v| v.as_str()).unwrap_or("");
                    return cmd_write(&format!("{} {}", path, content));
                }
                "list" => return cmd_list(path),
                "tree" => return cmd_tree(path),
                "stat" => return cmd_stat(path),
                "glob" => return cmd_glob(path),
                "find" => {
                    let name = json.get("name").and_then(|v| v.as_str()).unwrap_or("");
                    return cmd_find(&format!("{} {}", path, name));
                }
                "cat" => return cmd_cat(path),
                _ => return Ok(format!("Unknown fs operation: {}\n{}", op, USAGE)),
            }
        }
    }

    // Fall back to flat string format: "command rest..."
    let parts: Vec<&str> = args.splitn(2, ' ').collect();
    // ... existing flat-string logic
}
```

## Pattern for Any Tool

Any tool that supports native function calling should implement this dual-format handler:

1. **Try JSON parse first** — check if args is valid JSON and extract named fields
2. **Map JSON fields to internal commands** — the schema fields (`operation`, `path`, `command`, etc.) map to the tool's internal sub-commands
3. **Fall back to flat string** — for backward compatibility with text-based invocation (`TOOL:tool_name args`)
4. **Return usage on unknown operation** — help the model recover by showing valid options

## Schema Design Tip

When defining the OpenAI tool schema in `get_openai_tool_definitions()`, align the JSON property names with what the tool expects:

```rust
"fs" => json!({
    "type": "object",
    "properties": {
        "operation": {
            "type": "string",
            "enum": ["read", "write", "list", "tree", "stat", "glob", "find", "cat"],
        },
        "path": { "type": "string" },
        "content": { "type": "string" },  // for write
        "name": { "type": "string" },     // for find
    },
    "required": ["operation", "path"]
}),
```

The `enum` in the schema is critical — it tells the model exactly which operations are valid, reducing hallucinated commands.

## Common Pitfall

Don't assume the model will always pass JSON in the exact shape you expect. Fields may be missing, types may be wrong, or the model may pass a flat string despite the schema. Always:
- Use `and_then(|v| v.as_str())` not `.as_str().unwrap()`
- Provide sensible defaults (`unwrap_or(".")`, `unwrap_or("")`)
- Fall back to flat-string parsing if JSON parsing fails
- Return usage/help text on unknown operations so the model can self-correct
