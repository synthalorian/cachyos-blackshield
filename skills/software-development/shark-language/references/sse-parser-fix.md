# SSE Parser Fix: The `data:` Prefix Pitfall

## Problem

OpenShark's streaming chat returned 0 tokens despite the proxy working correctly via direct curl. The connection succeeded, request completed in ~2.8s, but no content was extracted.

## Root Cause

The SSE parser expected `data: ` (with a space after the colon):

```rust
// BROKEN — misses events from proxies that omit the space
if line.starts_with("data: ") {
    let data = &line[6..];
```

But the Kimi proxy at `127.0.0.1:8699` returns `data:{"delta":...}` with **no space** after the colon:

```
data:{"id":"chatcmpl-...","object":"chat.completion.chunk","choices":[...]}
```

This caused every SSE event to be skipped, resulting in 0 tokens.

## Fix

Use `starts_with("data:")` + `trim_start()` to handle both formats:

```rust
// CORRECT — handles "data: {...}" and "data:{...}"
if line.starts_with("data:") {
    let data = line["data:".len()..].trim_start();
    if data == "[DONE]" {
        continue;
    }
    if let Ok(event) = serde_json::from_str::<serde_json::Value>(data) {
        // extract delta content...
    }
}
```

## Lesson

**Never assume SSE `data:` lines have a space after the colon.** The SSE spec (WHATWG) defines the field value as everything after the colon, with optional leading space stripped. Some proxies (including simple Python `http.server` forwarders) omit the space entirely.

Always:
1. Match `starts_with("data:")` not `starts_with("data: ")`
2. Use `trim_start()` to strip optional whitespace
3. Test with raw curl to see the actual SSE format before debugging the parser

## Verification

```bash
# See raw SSE format from proxy
curl -s -N -H "Authorization: Bearer $KIMI_API_KEY" \
  -H "Content-Type: application/json" \
  http://127.0.0.1:8699/v1/chat/completions \
  -d '{"model":"kimi-for-coding","messages":[{"role":"user","content":"hi"}],"stream":true}' \
  | head -5

# If output shows "data:{...}" (no space), parser MUST use trim_start()
# If output shows "data: {...}" (with space), both parsers work
```

## Related

- `references/kimi-proxy-quirks.md` — Kimi-specific proxy behavior
- `references/sse-stream-buffering.md` — Handling chunks split mid-line
