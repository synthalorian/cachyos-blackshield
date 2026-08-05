# Context Compression System

## Overview

When a session's context approaches the model's limit, OpenShark automatically compresses older messages into summaries to keep the conversation alive. This prevents context window exhaustion during long sessions.

## How It Works

1. **Monitor** — Track estimated token usage against `model_context_length`
2. **Threshold** — User-configurable `compression_threshold` (0.0–1.0, default 0.8)
3. **Trigger** — When `tokens_used / context_length >= threshold`, compress
4. **Compress** — Group old messages into chunks, summarize each chunk
5. **Replace** — Old messages → summary message(s) in `model_messages`

## Config

```toml
[context_compression]
enabled = true
threshold = 0.8          # Trigger at 80% of context window
summary_model = "kimi-k2.6"  # Model to use for summarization (currently uses local fallback)
preserve_recent = 4      # Keep N most recent exchanges verbatim
max_summary_tokens = 512 # Max tokens per summary chunk
```

## Algorithm

```
[system] + [compressible messages] + [preserved recent exchanges]
                ↓
        Split into chunks of ~6 messages
                ↓
        Summarize each chunk locally
                ↓
[system] + [summary_1] + [summary_2] + ... + [preserved recent]
```

## Local Summarizer (Current Implementation)

The current implementation uses a local summarizer that extracts:
- **Topics** — first sentence of each message
- **Code blocks** — language tags from ``` blocks
- **Decisions** — imperative statements ("Set...", "Changed...", "Fixed...", "Added...", "Removed...")

This avoids an extra API call. Future versions may use the LLM for richer summaries.

## TUI Wiring

Compression triggers in `process_user_input()` before each API call:

```rust
// In src/tui/mod.rs::process_user_input()
let compression_notice = if let Some(ref mut compressor) = app.compressor {
    let estimated = crate::memory::compression::estimate_tokens(&model_messages);
    if compressor.should_compress(estimated, app.model_context_length) {
        match compressor.compress(&mut model_messages, &app.provider) {
            Ok(true) => {
                let stats = compressor.stats();
                Some(format!("🗜 Context compressed: {} messages → summaries", ...))
            }
            Ok(false) => None,
            Err(e) => Some(format!("⚠️ Context compression failed: {}", e)),
        }
    } else { None }
} else { None };

// Apply notice AFTER compressor borrow ends (borrow safety)
if let Some(notice) = compression_notice {
    app.add_system_message(notice);
}
```

**Critical borrow-safety pattern:** The `compressor` is borrowed mutably, but `add_system_message` needs `&mut app`. The solution: collect the notice string while the compressor is borrowed, then call `add_system_message` after the borrow ends.

## Files

- `src/memory/compression.rs` — Core compression engine
- `src/memory/mod.rs` — Exports
- `src/config/mod.rs` — `ContextCompressionConfig` struct + default
- `src/tui/mod.rs` — Trigger wiring in `process_user_input()`

## Tests

The compression module includes tests for:
- `test_estimate_tokens` — Token estimation heuristic
- `test_should_compress_triggered` — Threshold logic
- `test_should_compress_disabled` — Disabled state
- `test_chunk_messages` — Message chunking
- `test_local_summarize` — Summary extraction
- `test_compression_preserves_system` — End-to-end compression with system prompt preservation

## Future Enhancements

- [ ] LLM-based summarization (currently uses local extraction)
- [ ] `/compress` manual command for testing
- [ ] Sidebar indicator showing compression stats
- [ ] Configurable summary style (bullet points vs paragraphs)
