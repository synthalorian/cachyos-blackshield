# Direct API Chat Handler Pattern

When wrapping an LLM backend, **call the model API directly** instead of going through a CLI shim (`hermes --oneshot`). The CLI shim flattens the response and loses reasoning content.

## Problem

Reasoning models (DeepSeek R1, synthclaw-*) output their chain-of-thought to `reasoning_content` and only emit the final answer to `content`. When the model hits `finish_reason: "length"` during reasoning, `content` is empty even though the model produced valid reasoning.

Using a CLI wrapper (`hermes --oneshot "prompt"`) returns the `content` field only — which is empty for reasoning models that didn't finish. The user sees an empty response.

## Solution: Direct API Call

```rust
fn handle_chat(req: ChatRequest) -> ChatResponse {
    let config = read_config();
    let current_model = config["model"].as_str()
        .or_else(|| config["model"]["default"].as_str())
        .unwrap_or("");

    // Resolve which config provider handles this model prefix
    let prefix = current_model.split('/').next().unwrap_or("");
    let model_short = current_model.split('/').last().unwrap_or(current_model);
    let provider_name = resolve_provider(prefix, &config);
    let base_url = config["providers"][provider_name]["base_url"].as_str()...;
    let api_key = config["providers"][provider_name]["api_key"].as_str()...;

    let payload = serde_json::json!({
        "model": model_short,
        "messages": [{"role": "user", "content": req.message}],
        "max_tokens": 2048,
        "stream": false,
        "temperature": 0.7,
    });

    // Use curl in a subprocess (NEVER reqwest::blocking in tokio handlers)
    let output = std::process::Command::new("curl")
        .args(["-s", "--max-time", "120", "-X", "POST", &chat_url,
               "-H", "Content-Type: application/json",
               "-d", &payload_str])
        .output()?;

    let body = String::from_utf8_lossy(&output.stdout);
    let json: serde_json::Value = serde_json::from_str(&body)?;
    let msg = &json["choices"][0]["message"];

    // Extract both content and reasoning_content
    let content = msg["content"].as_str().unwrap_or("");
    let reasoning = msg["reasoning_content"].as_str().unwrap_or("");

    let response = if !content.is_empty() {
        content.to_string()
    } else if !reasoning.is_empty() {
        format!("[Thinking process omitted]\n{}",
            if reasoning.len() > 500 { format!("{}...", &reasoning[..500]) }
            else { reasoning.to_string() }
        )
    } else {
        String::new()
    };
}
```

## Provider Resolution

Map model prefixes to config provider names:

| Prefix | Config Provider |
|--------|----------------|
| `llama-swap/` | `llama-swap` |
| `x-ai/`, `grok` | `xai-oauth` (or first provider matching `xai`/`grok`) |
| `google/` | `gemini` or `gemini-oauth` |
| `anthropic/`, `claude/` | `anthropic` |
| `openai/` | `openai` |
| `deepseek/` | `nous` or `deepseek` |
| `meta-llama/`, `llama/` | `meta-llama` |
| `mistral/` | `mistral` |
| `qwen/` | `qwen` |

## Fallback

If the direct API call fails (no base_url, curl error, parse error), fall back to `run_hermes(&["-z", &message])` as a CLI shim fallback.

## Key Details

- **max_tokens: 2048** — Enough for reasoning models to produce both reasoning and a short answer
- **temperature: 0.7** — Balanced creativity
- **curl --max-time 120** — Models can take 60s+ to load into VRAM on first request
- **NEVER use reqwest::blocking** — hangs the tokio runtime
