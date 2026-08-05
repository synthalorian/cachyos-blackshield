# CLI Thinking Text Handling

## Problem

After implementing `StreamChunk::Reasoning` for the TUI, the CLI `openshark chat` path still shows raw `<think>` tags because `chat_stream()` returns `Vec<String>` (raw text), not structured `StreamChunk` events.

## Root Cause

kimi-k2.6 emits reasoning in TWO ways simultaneously:
1. `reasoning_content` delta field (structured, parsed into `StreamChunk::Reasoning`)
2. `<think>...</think>` blocks inside `content` (raw text, leaks through in CLI)

## Fix Options

### Option A: Strip before display (clean output, good for scripting)

```rust
let clean_response = strip_think_tags(&full_response);
println!("{}", clean_response);
```

### Option B: Dim with ANSI (preserves transparency)

```rust
for chunk in &chunks {
    if chunk.contains("<think>") || chunk.contains("</think>") {
        print!("\x1b[2m{}\x1b[0m", chunk);  // dim
    } else {
        print!("{}", chunk);
    }
}
```

### Option C: Deduplicate in provider parser (preferred)

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
        let clean = strip_think_tags(c);
        if !clean.is_empty() {
            let _ = tx.send(StreamChunk::Content(clean));
        }
    }
}
```

## Current State (2026-06-01)

- TUI: Handles reasoning via `StreamChunk::Reasoning` -> `StreamEvent::ReasoningChunk` -> muted 💭 display
- CLI: Raw `<think>` tags print to stdout. No reasoning display implemented.
- Commit `c465666` has the infrastructure but not the CLI display polish.
