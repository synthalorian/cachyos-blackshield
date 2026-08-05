# Qwen Think-Tag SSE Chunking

## Discovery

Found during Hermes Wingman local model debugging (May 2026). Local Qwen-based models (9B, 32B via llama-swap) were returning "blank" responses — actually full reasoning traces leaking without any visible output.

## Root cause

The `strip_think_tags` function was called per-SSE-chunk and reset `in_think = false` on every invocation:

```rust
// BROKEN: stateless
fn strip_think_tags(s: &str) -> String {
    let mut in_think = false;  // resets every chunk!
    ...
}
```

Qwen models emit their reasoning inside `<think>...</think>` tags that span **multiple SSE chunks**:

```
Chunk 1:  data: {"content":"\n\n"}
Chunk 2:  data: {"content":"<think>"}           ← opens in chunk 2
Chunk 3:  data: {"content":"\n\n"}
Chunk 4:  data: {"content":"1. **Analyze the Request:**"}
Chunk 5:  data: {"content":"   * User says:..."}
... (30+ chunks of reasoning)
Chunk 35: data: {"content":"</think>"}          ← closes in chunk 35
Chunk 36: data: {"content":"\n\n"}
Chunk 37: data: {"content":"🎹"}                ← actual response starts
Chunk 38: data: {"content":"🦞"}
Chunk 39: data: {"content":" Synthclaw online..."}
```

With the stateless filter:
- Chunk 2's `<think>` is caught and `in_think` flips to `true` — but the function returns and the state is **lost**
- Chunks 3-34 pass through as regular content (in_think was reset to `false`)
- Chunk 35's `</think>` is passed through as text (no opening tag seen in this call)
- Chunks 36+ pass through normally

## The fix

Track `in_think` as `&mut bool` outside the per-chunk call:

```rust
let mut in_think: bool = false;  // lives across the entire stream loop

while let Some(chunk_result) = stream.next().await {
    // ...
    let delta = strip_think_stream(raw, &mut in_think);
    // ...
}
```

The function mutations persist across calls because `in_think` lives in the `while` loop's scope.

## Cloud vs Local delta fields

| Field | Cloud APIs | Local GGUF (Qwen) |
|---|---|---|
| `delta.content` | The response text | Response text + `<think>...</think>` reasoning |
| `delta.reasoning_content` | The reasoning text | Not present |

**Rule**: For cloud models, skip `reasoning_content` entirely. For local models, use only `content` and strip `<think>` tags via the stateful filter.

## Testing

```bash
# Watch raw SSE to see the chunk boundaries
timeout 30 curl -s -N "http://127.0.0.1:9120/chat/stream?message=hi" 2>&1

# Look for patterns:
# BROKEN: data: {"content":"<think>"} ... data: {"content":"</think>"} ... response
# FIXED:  (no think tags at all) data: {"content":"🎹🦞 response"}
```

The telltale sign of the bug: if you see `</think>` (closing tag only, no opening) in the output, the stateful filter IS running but the state isn't persisting across calls.
