# Kimi Proxy Quirks for OpenShark

Discovered during 2026-05-30 session.

## Model Slug

The Kimi proxy at `http://127.0.0.1:8699/v1` uses model slug **`kimi-for-coding`**, NOT `kimi-k2.6`.

Direct curl verification:
```bash
curl -s http://127.0.0.1:8699/v1/models \
  -H "Authorization: Bearer $KIMI_API_KEY"
```

Returns:
```json
{"data":[{"id":"kimi-for-coding","display_name":"Kimi-k2.6",...}]}
```

Using `kimi-k2.6` as the model name results in 0 tokens returned (model not found silently).

## reasoning_content Field

Kimi returns thinking/reasoning content in a **separate field** from the regular content:

**Non-streaming response:**
```json
{
  "choices": [{
    "message": {
      "role": "assistant",
      "content": "Hi",
      "reasoning_content": "The user wants me to say hi in one word..."
    }
  }]
}
```

**Streaming SSE:**
```
data:{"delta":{"reasoning_content":"The"}}
data:{"delta":{"reasoning_content":" user"}}
data:{"delta":{"content":"Hi"}}
```

**Critical:** The SSE format uses `data:{...}` (no space after colon). See `references/sse-parser-fix.md`.

## Parser Fix

The streaming parser must check `delta.reasoning_content` BEFORE `delta.content`:

```rust
event.get("choices")
    .and_then(|c| c.get(0))
    .and_then(|c| c.get("delta"))
    .and_then(|d| d.get("reasoning_content"))  // Try thinking first
    .and_then(|c| c.as_str())
    .or_else(|| {
        event.get("choices")
            .and_then(|c| c.get(0))
            .and_then(|c| c.get("delta"))
            .and_then(|d| d.get("content"))     // Fallback to content
            .and_then(|c| c.as_str())
    })
```

For non-streaming, wrap reasoning in `<think>` tags so the TUI can display it:
```rust
if let Some(reasoning) = raw["choices"][0]["message"]["reasoning_content"].as_str() {
    content = format!("<think>\n{}\n</think>\n\n{}", reasoning, content);
}
```

## Context Length

The proxy reports `context_length: 262144` (256k). OpenShark config should use `256000` or `262144`.

## Authentication

The proxy validates the Kimi API key. A 401 with "Invalid Authentication" means the key is missing or wrong. A 200 with empty response means the model slug is wrong.

**Env file corruption check:**
```bash
# Verify key is actually present (should be ~70+ chars)
cat ~/.config/openshark/kimi.env | cut -d= -f2 | wc -c
# If ~4, file is corrupted with literal `***` — copy from ~/.config/claw/kimi.env
```
