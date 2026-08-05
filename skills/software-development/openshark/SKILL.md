---
name: openshark
title: OpenShark harness configuration
description: Configure OpenShark providers, models, Kimi, and llama-swap.
trigger: "configuring, verifying, building, or diagnosing OpenShark; wiring llama-swap or Kimi into OpenShark"
---

# OpenShark

OpenShark is a local AI coding harness. Live config lives at `~/.config/openshark/config.toml`. Build/install from `/home/synth/Projects/active/openshark` via `cargo install --path . --force`.

OpenShark reads provider/model config strictly from `config.toml`. It does not honor `env_file` on providers in the current build.

## Config anatomy

```toml
version = "1.1.0"
default_model = "k3"
weak_model = "synthclaw-fast"
architect_model = "k3"
editor_model = "k3"

[providers.kimi]
base_url = "https://api.kimi.com/coding/v1"
api_key = "sk-..."
kind = "open_ai_compatible"

[[providers.kimi.models]]
name = "k3"
context_length = 1048576
capabilities = ["code", "chat", "analysis", "reasoning", "vision"]

[providers.llama-swap]
base_url = "http://127.0.0.1:8080/v1"
api_key = "llama-swap-local"
kind = "open_ai_compatible"

[[providers.llama-swap.models]]
name = "synthclaw"
context_length = 131072
capabilities = ["code", "chat", "vision"]
```

## Critical routing facts

- **Router is exact name match.** `find_provider_for_model` compares `model.name` literally.
- **llama-swap aliases are NOT inherited.** Every desired model name must be listed as its own entry in `providers.llama-swap.models`.
- **`:think` suffixes are literal model IDs passed through.**

## Verification

1. `openshark doctor` — validates config and env-file presence.
2. `openshark doctor --fix` — attempts auto-repair.
3. `curl http://127.0.0.1:8080/v1/models` — live registry must match `providers.*.models[].name` exactly.
4. After code+binary changes, run `cargo install --path . --force` from the repo.

## Kimi env file — CURRENT BUILD DOES NOT SUPPORT IT

`openshark doctor` warns when no `~/.config/openshark/*.env` file exists. This build does **not** implement `env_file` on providers. Using `env_file = "kimi.env"` causes a TOML parse failure: `missing field 'api_key'`.

Keep the Kimi API key inline:
```toml
api_key = "sk-kim...uZ8r"
```

The doctor env-file warning cannot be silenced in this build. Treat it as informational, not a failure.

## Pitfalls

- **Alias sync with llama-swap is manual.** OpenShark's router does not expand aliases.
- **`:think` does NOT auto-enable thinking.** The actual flag is in llama-swap's `setParamsByID` map.
- **`cargo build` does not install.** Run `cargo install --path . --force` to replace `~/.cargo/bin/openshark`.
- **`env_file` is not supported.** Adding it to provider config breaks TOML validation. Keep `api_key` inline.
- **qwen3-embed is not in the `gpu` swap group.** It is CPU-only, persistent. List it if you need embedding access, but don’t expect it to compete for VRAM with chat models.

## References

- `references/config-shape.md` — provider/model schema, fields, and defaults
- `references/router-behavior.md` — exact-match routing internals and fallback behavior
- `references/llama-swap-integration.md` — local model wiring and alias sync strategy
- `references/doctor-checks.md` — doctor inspection points and warning cleanup
