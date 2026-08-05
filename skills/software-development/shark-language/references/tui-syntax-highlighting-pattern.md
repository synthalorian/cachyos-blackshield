# TUI Syntax Highlighting Pattern

## Overview

Built-in syntax highlighter for ratatui `Line`/`Span` rendering. Supports Rust, Python, JavaScript/TypeScript, JSON, TOML, YAML, and Bash. Detects code blocks in markdown-style ``` delimiters and highlights them with language-appropriate colors.

## Architecture

```
src/tui/syntax_highlight.rs
├── highlight_code_block(code, lang) → Vec<Line<'static>>
├── extract_and_highlight(text) → Vec<(bool, Vec<Line<'static>>)>
│   └── Splits text into (is_code_block, lines) segments
└── Per-language highlighters:
    ├── highlight_rust()     → magenta keywords, cyan types, blue builtins
    ├── highlight_python()   → same scheme
    ├── highlight_js()       → same scheme
    ├── highlight_json()     → cyan keys, green strings, yellow numbers
    ├── highlight_toml()     → cyan keys, gray comments
    ├── highlight_yaml()     → cyan keys, yellow lists, magenta booleans
    ├── highlight_bash()     → magenta keywords, blue builtins
    └── highlight_generic()  → plain white
```

## Tokenizer

`tokenize_and_highlight()` handles:
- **Comments** — `//` and `#` → dark gray italic
- **Strings** — `"..."`, `'...'`, Rust raw strings `r#"..."#` → green
- **Numbers** — integers, floats, hex, binary, with Rust suffixes (`u32`, `f64`) → yellow
- **Keywords** — language-specific, bold magenta
- **Types** — language-specific, cyan
- **Builtins** — language-specific, blue
- **Macros** — Rust `ident!` → yellow `!`

## extract_and_highlight

Parses markdown-style code blocks and returns alternating plain/code segments:

```rust
pub fn extract_and_highlight(text: &str) -> Vec<(bool, Vec<Line<'static>>)> {
    // Returns: [(false, plain_lines), (true, highlighted_rust), (false, plain_lines), ...]
}
```

Usage in `draw_chat_area()`:
```rust
let segments = syntax_highlight::extract_and_highlight(&msg.content);
for (is_code, segment_lines) in segments {
    if is_code {
        // Render with code block styling (e.g., darker background)
        for line in segment_lines {
            lines.push(line);
        }
    } else {
        // Render as normal text
        for line in segment_lines {
            lines.push(line);
        }
    }
}
```

## Lifetime Notes

All functions return `Vec<Line<'static>>` and `Vec<Span<'static>>`. The ratatui `Line` and `Span` types require owned strings, not references. Using `'static` lifetime ensures compatibility with the TUI's rendering pipeline.

Common compiler error:
```
error[E0106]: missing lifetime specifier
  -> expected named lifetime parameter
```

Fix: Change `Vec<Line>` to `Vec<Line<'static>>` and `Vec<Span>` to `Vec<Span<'static>>`.

## Adding a New Language

1. Add `highlight_my_lang(lines: &[&str]) -> Vec<Line<'static>>` function
2. Define `keywords`, `types`, `builtins` arrays
3. Call `tokenize_and_highlight(line, &keywords, &types, &builtins)`
4. Add case to `highlight_code_block()` match statement
5. Update this reference doc

## Files

- `src/tui/syntax_highlight.rs` — Full implementation
- `src/tui/mod.rs` — `mod syntax_highlight;` declaration
