# SSE Stream Buffering for OpenShark

**Date:** 2026-05-30
**Context:** Fixing 0-token issue with Kimi proxy streaming

## Problem

`reqwest` response `bytes_stream()` chunks can split SSE events mid-line. A single SSE event like:

```
data: {"choices":[{"delta":{"content":"Hello"}}]}
```

Might arrive as:
- Chunk 1: `data: {"choices":[{"delta":{`
- Chunk 2: `"content":"Hello"}}]}`

Without buffering, the parser fails to find complete JSON and returns nothing.

## Solution

Accumulate chunks into a buffer and process only complete lines (ending in `\n`):

```rust
async fn chat_stream(
    &self,
    messages: &[Message],
    model: &str,
    max_tokens: Option<u64>,
) -> Result<impl Stream<Item = Result<String>>> {
    let client = reqwest::Client::new();
    let body = self.build_chat_body(messages, model, max_tokens);
    let request = self.build_request_builder(
        &client, &self.build_url("/chat/completions"))?
        .json(&body)
        .build()?;

    let response = client.execute(request).await?;
    let mut stream = response.bytes_stream();
    let mut buffer = String::new();

    Ok(async_stream::stream! {
        while let Some(chunk) = stream.next().await {
            let chunk = chunk?;
            buffer.push_str(&String::from_utf8_lossy(&chunk));

            // Process complete lines
            while let Some(pos) = buffer.find('\n') {
                let line = buffer[..pos].to_string();
                buffer = buffer[pos + 1..].to_string();

                if line.starts_with("data: ") {
                    let data = &line[6..];
                    if data == "[DONE]" {
                        break;
                    }

                    if let Ok(event) = serde_json::from_str::<Value>(data) {
                        // Try reasoning_content first (Kimi), fallback to content
                        let content = event.get("choices")
                            .and_then(|c| c.get(0))
                            .and_then(|c| c.get("delta"))
                            .and_then(|d| d.get("reasoning_content"))
                            .and_then(|c| c.as_str())
                            .or_else(|| {
                                event.get("choices")
                                    .and_then(|c| c.get(0))
                                    .and_then(|c| c.get("delta"))
                                    .and_then(|d| d.get("content"))
                                    .and_then(|c| c.as_str())
                            });

                        if let Some(text) = content {
                            if !text.is_empty() {
                                yield Ok(text.to_string());
                            }
                        }
                    }
                }
            }
        }
    })
}
```

## Key Points

1. **Buffer accumulates across chunks** — `buffer.push_str()` adds each chunk
2. **Process only complete lines** — `find('\n')` ensures we have a full line
3. **Preserve remainder** — leftover partial line stays in buffer for next chunk
4. **Handle `[DONE]`** — SSE termination marker, stop processing
5. **Try `reasoning_content` first** — Kimi sends thinking content in a separate field before regular content

## Related

- `references/kimi-proxy-quirks.md` — Kimi-specific `reasoning_content` handling
- `references/provider-config.md` — Provider system config
