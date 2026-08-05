# llama-swap ↔ OpenShark integration

## Registry as source of truth

`http://127.0.0.1:8080/v1/models` is the authoritative model list. Every `id` returned here must be mirrored into `openshark/config.toml` for selection to work.

Current registry IDs:
- `qwen3-embed`
- `synthclaw`
- `synthclaw-262k`
- `synthclaw-fast`
- `synthclaw-fast-262k`
- `synthclaw-glm`
- `synthclaw-glm-262k`

## Mirroring aliases

llama-swap exposes aliases in `/v1/models` `meta.llamaswap.aliases`, but OpenShark does not read them. Re-register alias names explicitly in OpenShark config when you want to route to them by alias.

Alias map to mirror:
- `gemma-4-12b`, `synthclaw-131k` -> `synthclaw`
- `gemma-4-12b-262k` -> `synthclaw-262k`
- `qwen3.5-9b` -> `synthclaw-fast`
- `synthclaw-fast-131k` -> `synthclaw-fast`
- `glm5.2-distill` -> `synthclaw-glm`
- Thinking variants: `*:think`, `*131k:think`, `*262k:think`

## Thinking toggles

llama-swap enables thinking via chat-template kwargs:

```yaml
filters:
  setParamsByID:
    "synthclaw-fast:think":
      chat_template_kwargs:
        enable_thinking: true
    "synthclaw-fast":
      chat_template_kwargs:
        enable_thinking: false
```

OpenShark does not parse or inject `enable_thinking`. It sends the model id as-is. The filter side must exist in `llama-swap/config.yaml` for `:think` variants to actually reason.

## Verification after changes

```bash
openshark doctor
curl -s http://127.0.0.1:8080/v1/models | python3 -m json.tool
cargo install --path /home/synth/Projects/active/openshark --force
```
