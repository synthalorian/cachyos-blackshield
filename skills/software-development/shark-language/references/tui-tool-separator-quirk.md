# TUI Tool Separator Quirk — TOOL: vs TOOL.

## Problem

Model outputs `TOOL.fs cat /path` (dot) but parser only accepts `TOOL:fs cat /path` (colon).
Tools appear as plain text in chat, never execute. User sees "0 tools" in sidebar
or tools stuck at "in-progress" with 0ms execution time.

## Fix

Update `parse_embedded_tools()` in `src/tui/mod.rs` to accept both separators:

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

Also update `strip_tool_lines()` to strip both formats from display.

## Related

- `references/tool-invocation-format-drift.md` — Full-scope audit pattern for all locations that parse tool invocations
