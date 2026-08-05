# Swarm Code Visibility Pattern

## User Requirement (Hard)

synth: "i want all of the code it writes to be visible"

This is non-negotiable. Every code block produced by ANY agent (main assistant or swarm agents) must be visually impossible to miss. Plain text code dumps are unacceptable.

## Implementation

### 1. Syntax Highlighting for All Surfaces

The `syntax_highlight::extract_and_highlight()` function detects markdown-style ` ``` ` code fences and splits text into alternating plain/code segments. This is applied to:

**A. Main assistant messages** (`draw_chat_area()`, regular chat):
```rust
if msg.role == "assistant" {
    let highlighted = syntax_highlight::extract_and_highlight(&msg.content);
    for (is_code, block_lines) in highlighted {
        if is_code {
            lines.push(Line::from(vec![
                Span::styled("┌─ code ──────────────────────────────", muted_style()),
            ]));
            for hl_line in block_lines {
                lines.push(hl_line);  // Already syntax-highlighted
            }
            lines.push(Line::from(vec![
                Span::styled("└─────────────────────────────────────", muted_style()),
            ]));
        } else {
            for hl_line in block_lines {
                lines.push(hl_line);
            }
        }
    }
}
```

**B. Swarm agent streaming** (`draw_chat_area()`, agent stream section):
```rust
let highlighted = syntax_highlight::extract_and_highlight(&state.content);
for (is_code, block_lines) in highlighted {
    if is_code {
        lines.push(Line::from(vec![
            Span::styled("┌─ code ──────────────────────────────", muted_style()),
        ]));
        for hl_line in block_lines { lines.push(hl_line); }
        lines.push(Line::from(vec![
            Span::styled("└─────────────────────────────────────", muted_style()),
        ]));
    } else {
        for hl_line in block_lines { lines.push(hl_line); }
    }
}
```

### 2. Code Block Borders

Every detected code block gets visual framing:
- **Top:** `┌─ code ──────────────────────────────` (muted gray)
- **Content:** Syntax-highlighted lines (language-appropriate colors)
- **Bottom:** `└─────────────────────────────────────` (muted gray)

This makes code blocks visually distinct from prose even at a glance.

### 3. Inspector Sidebar Code Detection

The Inspector tab's content preview shows a 📄 icon when code is detected:
```rust
let has_code = preview.contains("```") || preview.contains("fn ") || preview.contains("def ");
if has_code {
    lines.push(Line::from(vec![
        Span::styled("  📄 ".to_string(), muted_style()),
        Span::styled(preview.replace('\n', " "), muted_style()),
    ]));
}
```

Preview expanded from 60→120 chars so more context is visible.

### 4. Languages Supported

| Language | File Extensions | Color Scheme |
|----------|----------------|--------------|
| Rust | `.rs` | Keywords: magenta bold, Types: cyan, Builtins: blue, Strings: green, Numbers: yellow, Comments: gray italic |
| Python | `.py` | Same |
| JavaScript/TypeScript | `.js`, `.ts` | Same |
| JSON | `.json` | Keys: cyan, Strings: green, Numbers: yellow, Booleans: magenta |
| TOML | `.toml` | Keys: cyan, Sections: cyan bold, Comments: gray italic |
| YAML | `.yaml`, `.yml` | Keys: cyan bold, Lists: yellow, Booleans: magenta |
| Bash/Shell | `.sh`, `.bash` | Keywords: magenta bold, Builtins: blue |
| Generic | any | Plain white |

### 5. Tokenizer Features

`tokenize_and_highlight()` handles:
- `//` and `#` comments → dark gray italic
- `"..."` and `'...'` strings → green
- Rust raw strings `r#"..."#` → green
- Numbers with suffixes (`42u32`, `3.14f64`) → yellow
- Keywords → magenta bold
- Types → cyan
- Builtins → blue
- Rust macros `ident!` → yellow `!`

## Anti-Patterns to Avoid

❌ **Plain text code blocks** — `for line in content.lines() { lines.push(Line::from(line)) }` misses code entirely
❌ **Truncated code** — Never truncate code blocks for display. Show full content.
❌ **No visual framing** — Code without borders blends into prose
❌ **Inspector without code indicator** — Users can't tell which agents are writing code

## Files Modified

- `src/tui/mod.rs` — `draw_chat_area()`: assistant messages + swarm agent streaming
- `src/tui/syntax_highlight.rs` — `extract_and_highlight()`, `highlight_code_block()`
- Inspector preview: code detection icon + expanded preview length
