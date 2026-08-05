## Reasoning Budget Flag Behavior

Models loaded via `llama-server` support `--reasoning-budget N` to control chain-of-thought reasoning:

| Value | Behavior |
|-------|----------|
| Not set | Default behavior — Qwen models still produce plain-text chain-of-thought |
| `--reasoning-budget 0` | **Does NOT disable reasoning**. On Qwen, enables reasoning but with effectively unlimited budget. Model may output `<think>` tags with no final answer. |
| `--reasoning-budget 256` | Limited reasoning (default if flag omitted on some builds) |
| `--reasoning-budget -1` | Unlimited reasoning |

**PITFALL:** `--reasoning-budget 0` on Qwen models causes the model to output reasoning tokens inside `<think>...</think>` tags but may NEVER produce a final answer — the response ends with `</think>` and no content. Removing the flag entirely lets the model produce normal direct answers, though it may still output chain-of-thought as plain text (not in think tags).

**PITFALL:** Removing `--reasoning-budget` entirely does NOT eliminate verbose reasoning from Qwen models if the system prompt includes "Think Before Coding" or similar instructions. The model follows the instruction literally and outputs its entire reasoning process. To reduce verbosity, either:
1. Remove "Think Before Coding" from the system prompt
2. Or keep `--reasoning-budget 0` and handle `<think>` tags in the streaming backend via `strip_think_tags()` (see `scripts/strip-think-tags.rs`)

## `<think>` Tag Stripping

When a model outputs reasoning inside `<think>...</think>` tags, use `strip_think_tags()` in the streaming backend to filter them out:

```rust
// In your SSE handler, before sending the event:
let raw = if !content.is_empty() { content } else if !reasoning.is_empty() { reasoning } else { "" };
let delta = strip_think_tags(raw);
if !delta.is_empty() {
    let evt = Event::default().data(json!({"content": delta}).to_string());
    let _ = tx.send(Ok(evt)).await;
}
```

See `scripts/strip-think-tags.rs` for the implementation.
