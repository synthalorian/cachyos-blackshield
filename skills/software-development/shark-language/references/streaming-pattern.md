# Streaming Pattern in OpenShark TUI

How streaming responses are wired in `src/tui/mod.rs`.

## Provider Side

`src/providers/mod.rs` has `chat_stream()` which returns `Result<Vec<String>>`:

```rust
pub async fn chat_stream(
    &self, request: ChatRequest
) -> Result<Vec<String>> {
    // Sends stream=true to API
    // Parses SSE data: lines
    // Extracts delta.content from each chunk
    // Returns Vec of token strings
}
```

## TUI Side

In `src/tui/mod.rs`, the main loop:

```rust
// Print prefix
print!("🦞 ");
io::stdout().flush()?;

// Stream chunks
let request = ChatRequest {
    model: model.clone(),
    messages: messages.clone(),
    stream: true,
};

match provider.chat_stream(request).await {
    Ok(chunks) => {
        let mut full_content = String::new();
        for chunk in chunks {
            print!("{}", chunk);
            io::stdout().flush()?;
            full_content.push_str(&chunk);
        }
        println!();
        // full_content now has the complete response
    }
    Err(e) => { /* ... */ }
}
```

## Tool Follow-ups Also Stream

After a tool executes, the follow-up request also uses `chat_stream()`:

```rust
let follow_up = ChatRequest {
    model: model.clone(),
    messages: messages.clone(),
    stream: true,
};
if let Ok(resp_chunks) = provider.chat_stream(follow_up).await {
    // Same streaming print loop
}
```

## Key Points

- Always `flush()` after `print!()` or tokens batch up
- Accumulate into `full_content` for saving to memory + tool detection
- Tool detection (`content.starts_with("TOOL:")`) happens AFTER the stream completes
- The old `chat()` method still exists for non-streaming use cases
