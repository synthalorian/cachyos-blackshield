# Multimodal Vision Support in OpenShark

## Overview

OpenShark supports image attachments via the OpenAI-compatible multimodal content format. Images are base64-encoded data URLs sent alongside text as content parts.

## Architecture

```
TUI /image command → image_utils::encode_image_to_data_url() → Message::with_image()
    → to_openai_content() → build_chat_body() → Provider API
```

## Key Components

### 1. Message Struct (`src/providers/mod.rs`)

```rust
pub struct Message {
    pub role: String,
    pub content: String,
    #[serde(skip_serializing_if = "Option::is_none", default)]
    pub images: Option<Vec<String>>,
}

impl Message {
    pub fn text(role: impl Into<String>, content: impl Into<String>) -> Self {
        Self { role: role.into(), content: content.into(), images: None }
    }

    pub fn with_image(role: impl Into<String>, content: impl Into<String>, image_data_url: impl Into<String>) -> Self {
        Self { role: role.into(), content: content.into(), images: Some(vec![image_data_url.into()]) }
    }

    pub fn to_openai_content(&self) -> serde_json::Value {
        if let Some(ref images) = self.images {
            let mut parts = vec![json!({"type": "text", "text": self.content})];
            for img in images {
                parts.push(json!({"type": "image_url", "image_url": {"url": img}}));
            }
            json!(parts)
        } else {
            json!(self.content)
        }
    }
}
```

### 2. Image Encoding Utility (`src/image_utils.rs`)

```rust
pub fn encode_image_to_data_url(path: &Path) -> Result<String> {
    let bytes = std::fs::read(path)?;
    let mime_type = detect_mime_type(path);  // From extension: png, jpg, gif, webp, bmp, svg
    let base64 = base64::encode(&bytes);
    Ok(format!("data:{};base64,{}" , mime_type, base64))
}
```

### 3. build_chat_body() — Provider Serialization

**OpenAI-compatible:**
```rust
let messages: Vec<_> = request.messages.iter()
    .map(|m| json!({"role": m.role, "content": m.to_openai_content()}))
    .collect();
```

**Anthropic:** Same as OpenAI — uses `to_openai_content()`.

**Gemini:** Inline data format:
```rust
let mut parts = vec![json!({"text": m.content})];
if let Some(ref images) = m.images {
    for img in images {
        parts.push(json!({
            "inline_data": {
                "mime_type": "image/png",
                "data": img.strip_prefix("data:image/png;base64,").unwrap_or(img)
            }
        }));
    }
}
```

### 4. TUI Integration

**App state:**
```rust
struct App {
    pending_image: Option<String>,  // Queued for next user message
    // ...
}
```

**Command handler:**
```rust
if input.starts_with("/image ") {
    let path = std::path::Path::new(&input[7..]);
    match crate::image_utils::encode_image_to_data_url(path) {
        Ok(data_url) => {
            app.pending_image = Some(data_url);
            app.add_system_message("📎 Image attached...".to_string());
        }
        Err(e) => app.add_system_message(format!("❌ Failed: {}", e)),
    }
    return Ok(());
}
```

**Message construction:**
```rust
fn add_user_message(&mut self, content: String) {
    let images = self.pending_image.take();
    if let Some(img) = images {
        self.model_messages.push(Message::with_image("user", content, img));
    } else {
        self.model_messages.push(Message::text("user", content));
    }
}
```

### 5. Chat Display Indicator

Messages with images show `📎 Image attached` in italic muted style:
```rust
if msg.images.is_some() {
    lines.push(Line::from(vec![
        Span::styled("  📎 Image attached", muted_style().add_modifier(Modifier::ITALIC)),
    ]));
}
```

### 6. System Prompt

Tells the model it can analyze images:
```
You can analyze images when users attach them.
```

## Supported Models

- **Kimi k2.6** — Full vision support via OpenAI-compatible format
- **GPT-4o** — Native multimodal
- **Claude 3** — Native vision via `image_url` content parts
- **Gemini** — Inline data format

## Testing Checklist

- [ ] `/image /path/to/image.png` encodes successfully
- [ ] Confirmation message appears in chat
- [ ] Next message includes image in API request
- [ ] `to_openai_content()` returns array for images, string for text-only
- [ ] Chat display shows `📎 Image attached` indicator
- [ ] `cargo check` clean after all changes
- [ ] Build succeeds: `cargo build --release`

## Pitfalls

1. **Wrong struct type** — `memory::store::Message` has no `images` field. Only `providers::Message` does.
2. **MIME type detection** — Default fallback is `image/png`. Verify extension-based detection covers your use case.
3. **Base64 prefix stripping (Gemini)** — Gemini needs raw base64, not the full data URL. Strip the prefix.
4. **Pending image queue** — `pending_image` must be consumed (`.take()`) on the next message, not every message.
