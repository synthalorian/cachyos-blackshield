# Identity Rebrand Sweep — Local LLM Stack

When renaming the AI assistant identity across a local LLM serving stack (e.g., synthclaw → synthclaw, 🦞 → 🦞), the change must propagate through multiple layers. Missing any layer causes the model to respond with the old identity or no identity at all.

## Layers to sweep (checklist)

1. **Jinja chat templates** (`~/llm/*.jinja`)
   - Rename files: `synthclaw-base.jinja` → `synthclaw-base.jinja`
   - Replace name AND emoji in template content
   - The identity string is usually in the system prompt block near the top

2. **llama-swap config** (`~/llama.cpp/llama-swap/config.yaml`)
   - Model aliases: `synthclaw-35b-128k` → `synthclaw-35b-128k`
   - `--alias` flag in each `cmd:` block
   - Any `--chat-template-file` or `--system-prompt-file` paths

3. **llama-swap auxiliary files** (`~/llama.cpp/llama-swap/`)
   - Template files referenced by config (`.jinja`, `.txt`)
   - Test configs (`config.yaml.test` — easy to miss)
   - System prompt text files

4. **CLI wrapper scripts** (`~/.local/bin/`)
   - `claw` — model shorthand resolver, echo messages, `LOCAL_DEFAULT`
   - `hermes` — `SHORTHAND_MAP`, echo messages, provider routing
   - `openclaw`, `oc-local` — if still present
   - Shared resolver script (`synthclaw-resolve.sh` → `synthclaw-resolve.sh`)
   - Any proxy scripts (`kimi-proxy`, etc.) with emoji in output

5. **systemd units** (`~/.config/systemd/user/`)
   - Service descriptions in `[Unit]` blocks
   - Any pre-warm scripts that reference model names

6. **Hermes config** (`~/.hermes/config.yaml`)
   - `fallback_providers` entries
   - Model aliases in provider blocks

7. **Memory / persistent state**
   - `~/.hermes/memories/MEMORY.md` — identity line
   - Not critical for model responses but affects agent self-reference

## Pitfalls

- **The resolver script rename** — `claw` and `openclaw` source a shared resolver. Renaming the file without updating the `source` line breaks the wrapper.
- **Stale test configs** — `config.yaml.test` or `.bak` files in the llama-swap directory may still reference old names. They don't affect runtime but cause confusion.
- **Emoji-only grep misses** — Searching for `synthclaw` won't find lines that only have the old emoji (`🦞`). Always grep for both:
  ```bash
  grep -r "synthclaw\|🦞" ~/.local/bin/ ~/llm/ ~/llama.cpp/llama-swap/
  ```
- **Jinja template format** — The model's response format is determined by its TRAINING, not the template. The template only formats the INPUT. If you change the template to use a format the model wasn't trained on, the model will echo template tokens back as garbage. Always match the template format to the model architecture (ChatML for Qwen, Llama-3 format for Gemma/Llama, plain text for DeepSeek Coder).
- **systemd socket activation trap** — Don't try socket activation with llama-swap. It binds its own port and doesn't support `LISTEN_FDS`. See [socket-activation-failure.md](socket-activation-failure.md).

## Verification

After the sweep, verify with a direct request:
```bash
# Start llama-swap if needed
systemctl --user start llama-swap

# Test a local model
curl -s http://127.0.0.1:8080/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model":"synthclaw-35bkimi-128k","messages":[{"role":"user","content":"Who are you?"}],"max_tokens":50}'
```

The response should contain the new identity name and emoji, not the old ones.
