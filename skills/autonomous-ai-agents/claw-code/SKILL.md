---
name: claw-code
description: "Configure and use claw-code CLI — model shortcuts, provider routing, wrapper script, credential management."
version: 1.0.0
author: synthclaw
metadata:
  hermes:
    tags: [claw-code, configuration, providers, models, openrouter, shortcuts]
---

# claw-code — Configuration & Shortcuts

claw-code is the Rust-based CLI coding agent from upstream `ultraworkers/claw-code` (public Rust implementation of the `claw` harness). Fresh setup 2026-08-01: cloned to `~/claw-code/`, release binary at `~/claw-code/rust/target/release/claw` (v0.1.3). Build: `cd ~/claw-code/rust && cargo build --release --workspace` (~2.5 min on i7-8700K). First-run check: `claw doctor`. NOT the same as claude-code (Anthropic's official tool) — the user will correct you if you confuse them.

## Architecture

```
~/.local/bin/claw                    → symlink → synthclaw-ai-setup/configs/wrappers/claw (canonical)
~/claw-code/rust/target/release/claw → the real Rust binary (upstream ultraworkers/claw-code)
~/.config/claw/                      → claw-code config directory
~/.config/claw/kimi.env              → Kimi K3 API key (600 perms, copied from ~/.hermes/.env)
~/.claw/CLAUDE.md                    → synthclaw identity (user-level instructions, via local patch)
```

Fresh-machine bootstrap: `synthclaw-ai-setup/configs/claw-code/setup.sh` (private repo) — clones, applies the identity patch, builds, links the wrapper, installs identity, imports the Kimi key from Hermes, verifies. Tested idempotent 2026-08-01.

## Local Patches (this clone diverges from upstream)

- **User-level instruction files** (`rust/crates/runtime/src/prompt.rs`, uncommitted, 2026-08-01): `discover_instruction_files` now loads `$CLAW_CONFIG_HOME/CLAUDE.md` (= `~/.claw/CLAUDE.md`), `~/.claw/instructions.md`, and `~/.claude/CLAUDE.md` BEFORE project files. Upstream v0.1.3 only walks cwd→git-root, so there was no global identity vector. Test: `prompt::tests::discovers_user_level_instruction_files_from_config_home`. A `git pull` on upstream may conflict in `prompt.rs` — rebase carefully.
- **synthclaw identity lives at `~/.claw/CLAUDE.md`** (adapted copy of Hermes `SOUL.md`). Verify: `claw system-prompt | grep synthclaw`, or ask any route "what is your name and signature emojis?" → expect `synthclaw 🎹🦞`.
- Pre-existing clippy failures in `trident.rs`/`compact.rs` are upstream's — `cargo clippy --workspace -- -D warnings` was already red before our patch. Our changes are clippy-clean.
- `/output-style` slash command is parsed but NOT implemented in v0.1.3 — don't try to use it for identity injection.

## How the Wrapper Script Works

The wrapper at `synthclaw-ai-setup/configs/wrappers/claw`:

1. Resolves the real claw binary from several candidate paths
2. Checks the first positional arg against a `case` statement for model shortcuts
3. For local models (`35b`, `14b`, `9b`, etc.): calls `resolve_model()` from `synthclaw-resolve.sh`, sets `OPENAI_BASE_URL` to llama-swap, runs with `--model "openai/<resolved>"`
4. For cloud shortcuts (`kimi`, `glm`, `ds`, `mm`, `v4pro`): sets provider-specific env vars and runs with provider-prefixed model name
5. Default (no args): Kimi K2.6 Vivace

## Adding a New Model Shortcut

Add a new `case` branch in the wrapper script before the `local)` case:

```bash
        <shortcut>|<altname>)
            shift
            echo "🎹🦞 Cloud: <model> via <provider>"
            source "$HOME/.config/claw/<creds-file>"
            # Use 'env' not 'export' to prevent bash $ expansion in keys
            _KEY="$<VAR_NAME>"
            export OPENAI_BASE_URL="<base-url>"
            # CRITICAL: use openai/ prefix for OpenAI-compatible endpoints
            # Other prefixes route to hardcoded providers (kimi/→DashScope, anthropic/→Anthropic, etc.)
            env OPENAI_API_KEY=*** "$REAL_CLAW" --model "openai/<model-slug>" "$@"
            ;;
```

**Prefix selection is critical:**
- `openai/<slug>` → OpenAI-compatible backend (respects `OPENAI_BASE_URL`)
- `kimi/<slug>` or `qwen/<slug>` → DashScope (Alibaba), requires `DASHSCOPE_API_KEY`
- `anthropic/<slug>` → Anthropic API, requires `ANTHROPIC_API_KEY`
- `xai/<slug>` or `grok*` → X.AI, requires `XAI_API_KEY`

**For OpenRouter specifically:**
- Base URL: `https://openrouter.ai/api/v1`
- Model prefix: `openai/` (OpenRouter is OpenAI-compatible)
- API key format: `sk-or-v1-...`
- Store the key in `~/.config/claw/openrouter.env` with `OPENROUTER_API_KEY="sk-or-v1-..."` and `chmod 600`

## Credential Management Pattern

NEVER hardcode API keys in the wrapper script. The script lives in `synthclaw-dotfiles` and is version-controlled. Instead:

1. Create a separate env file in `~/.config/claw/<provider>.env` (claw-code config space only)
2. `chmod 600` the file
3. The wrapper script `source`s it at runtime, reads the env var, and exports it as `OPENAI_API_KEY`
4. After setup, clear shell history so the key isn't in `.bash_history`

## Config Files

| File | Purpose |
|---|---|
| `~/.claw.json` | User-level aliases |
| `~/.config/claw/settings.json` | User-level settings |
| `~/.config/claw/kimi.env` | Kimi K2.6 API key (600 perms) |
| `~/.config/claw/openrouter.env` | OpenRouter API key (600 perms) |
| `<repo>/.claw.json` | Project aliases |
| `<repo>/.claw/settings.json` | Project settings (shared) |
| `<repo>/.claw/settings.local.json` | Project settings (personal) |
## Related

- `references/kimi-coding-plan.md` — full Kimi provider config for all harnesses
- `references/proxy-routing.md` — routing blocked providers through Nous/Hermes proxy
- `references/kimi-proxy-verification.md` — quick diagnostic: verify proxy is running and key is valid
- `scripts/verify-kimi-proxy.py` — automated verification script (proxy health + Hermes config drift check)
- `references/session-2026-05-28-kimi-403.md` — error transcript: why Kimi direct fails for claw-code and the revert procedure
- `references/session-2026-05-29-dashscope-routing.md` — error transcript: why `kimi/` prefix routes to DashScope and the `openai/` prefix fix
- `references/session-2026-05-29-hermes-kimi-401.md` — error transcript: Hermes 401 when `base_url` points to direct Kimi instead of local proxy
- `references/session-2026-05-29-wrapper-key-literal.md` — error transcript: literal `***` passed as API key due to missing variable reference
- `references/kimi-api-routing-map.md` — which tools use direct vs proxy routing to Kimi (openshark skill)
- `shark-language` — OpenShark harness; provider system derived from claw-code patterns (see `references/provider-config.md`)

## Known Shortcuts (Current — 2026-08-01)

| Shortcut | Model sent | Provider | Notes |
|---|---|---|---|
| (none/default), `kimi`, `k3` | `local/k3` | Kimi for Coding (direct) | base `https://api.kimi.com/coding/v1`, key from `~/.config/claw/kimi.env` |
| `sc` / `synthclaw` | `synthclaw` | local llama-swap | |
| `scmax` / `synthclaw-262k` | `synthclaw-262k` | local llama-swap | |
| `35b` | `synthclaw-35b` | local llama-swap | |
| `35bmax` / `35b-262k` | `synthclaw-35b-262k` | local llama-swap | |
| `fast` | `synthclaw-fast` | local llama-swap | |
| `fastmax` / `fast-262k` | `synthclaw-fast-262k` | local llama-swap | |
| `glm` | `synthclaw-glm` | local llama-swap | local GLM quants, NOT Z.AI cloud |
| `glmmax` / `glm-262k` | `synthclaw-glm-262k` | local llama-swap | |
| `local <model-id>` | `<model-id>` | local llama-swap | explicit passthrough for unlisted ids |
| `list` / `models` | — | utility | prints llama-swap `/v1/models` roster (`qwen3-embed` exists but is embeddings-only — no shortcut) |

claw's own subcommands (`doctor`, `prompt`, `init`, `state`, `skills`, `status`, `sandbox`, `version`, `config`, `mcp`, `help`, flags) pass through to the real binary untouched. Any other first arg is treated as a prompt shorthand on the default (Kimi K3) route. llama-swap: `http://127.0.0.1:8080/v1`, key `llama-swap-local`, systemd user service `llama-swap.service`.

## Provider Routing (CRITICAL — v0.1.3 behavior)

**EMPIRICAL (2026-08-01, upstream v0.1.3): claw sends `openai/<slug>` to the server VERBATIM — the prefix is NOT stripped.** Kimi rejected it with `Your model id does not exist, recognized as other:openai/k3. Please set model id as 'k3'`. The working form for ANY custom OpenAI-compatible endpoint (llama-swap AND Kimi) is **`local/<slug>`**, which routes through OpenAI-compatible transport and sends `<slug>` verbatim:

```bash
# WORKS — server receives model id "k3"
OPENAI_BASE_URL=https://api.kimi.com/coding/v1 claw --model local/k3 ...
# FAILS — server receives literal "openai/k3"
claw --model openai/k3 ...
# FAILS at claw's own parser — bare slugs rejected, requires provider/model syntax
claw --model k3 ...
```

Docs claim `openai/` strips the prefix for OpenRouter — not verified on this build; `local/` is the proven path for every custom endpoint here.

**Kimi K3 works DIRECT (no proxy) as of 2026-08-01:** base `https://api.kimi.com/coding/v1`, model `local/k3`, key from `~/.hermes/.env` (`KIMI_API_KEY`, same key Hermes' `kimi-coding` provider uses). The old K2.6 403 whitelist block does not apply to this endpoint. Raw curl smoke test: POST `$KIMI_BASE/chat/completions` with `{"model":"kimi-k3",...}` also works (`kimi-k3` slug valid via curl; through claw use `local/k3`).

`claw` uses **prefix-based provider routing**. The model string prefix determines which backend is used, NOT just the env vars:

| Prefix | Backend | Credentials |
|--------|---------|-------------|
| `anthropic/` | Anthropic API | `ANTHROPIC_API_KEY` |
| `openai/` | OpenAI-compatible | `OPENAI_API_KEY` + `OPENAI_BASE_URL` |
| `xai/` or `grok*` | X.AI | `XAI_API_KEY` |
| `kimi/` or `qwen/` | **DashScope** (Alibaba) | `DASHSCOPE_API_KEY` |

**This is NOT overridden by `OPENAI_BASE_URL`.** If you pass `--model kimi/kimi-k2.6` with `OPENAI_BASE_URL=http://127.0.0.1:8699/v1`, `claw` still routes to DashScope and ignores your base URL. You MUST use the `openai/` prefix for custom endpoints:

```bash
# WRONG — routes to DashScope, ignores OPENAI_BASE_URL
claw --model kimi/kimi-k2.6 ...

# CORRECT — routes through OpenAI-compatible backend to your proxy
claw --model openai/kimi-k2.6 ...
```

The wrapper script's job is to set the right prefix + env vars. It does NOT "override" provider routing — it must speak the prefix language that `claw` understands.

## Pitfalls

- **DO NOT confuse claw-code with claude-code.** Claude Code is Anthropic's official tool (npm package `@anthropic-ai/claude-code`). claw-code is synth's Rust fork at `~/claw-code/`. Loading the claude-code skill is wrong for claw-code tasks.
- **Wrapper script is the source of truth for shortcuts.** Don't look for model configs inside the Rust source — all routing happens in the bash wrapper.
- **API keys go in `~/.config/claw/*.env`, NOT in the wrapper script.** The wrapper is in dotfiles and version-controlled.
- **Every cloud shortcut needs its own `exec`.** A `case` branch that only does `shift` + `echo` without `exec` will fall through to the default else branch. This caused `claw glm` to silently route to Kimi until the `glm` case got its own `export + exec` block. When adding new cloud shortcuts, always include the full `source`/`export`/`exec` pattern inside the case — don't rely on the default branch.
- **The patch artifact `;;[/DONE]`** — when patching the wrapper with `patch`, the `[/DONE]` string at the end of the replacement may accidentally be included. Always re-read the file to verify.
- **`local)` case must stay intact.** When adding new shortcuts, add them between the existing cloud shortcuts and the `local)` case. Accidentally removing the `local)` label breaks all local model shortcuts.
- **API key variables are masked in tool output.** `read_file`, `terminal`, `write_file`, and `execute_code` mask `$KIMI_API_KEY` (and other secrets) as `***` when the env var exists, making diffs look truncated and causing `write_file` to literally write `***` into the file. The file is NOT correct after a masked write — verify with `wc -c` (real key is ~95 chars) or `python3 -c "print(open(path).read())"`. If the key was mangled, the user must manually edit the file.
- **Tool output masking corrupts env files too.** The same masking that affects the wrapper script also corrupts `.env` files. If you use `write_file` or `patch` on `~/.config/claw/kimi.env`, the tool may write literal `***` instead of the real key. Always verify with `wc -c` (~95 bytes for Kimi keys). If corrupted, the user must recreate the file manually — tools cannot write unmasked secrets.
- **Bash `$` expansion in API keys corrupts the key at runtime.** If a key contains `$` characters (common in `sk-kimi-...` keys), bash interprets them as variable references during `export OPENAI_API_KEY="$KIMI_API_KEY"`. The fix: use `env OPENAI_API_KEY="$_KIMI_KEY" <command>` instead of `export` + `exec`, which passes the value without re-parsing by the shell. Alternatively, use single quotes around the literal key value if hardcoding (not recommended), or ensure the key file uses single quotes: `KIMI_API_KEY='...'`.
- **Wrapper script can drift from skill docs.** The live file at `~/.local/bin/claw` is a symlink to `synthclaw-ai-setup/configs/wrappers/claw`. During troubleshooting it may get patched directly. Always verify the live wrapper matches the skill's documented routing before concluding "the skill is wrong." If the user explicitly wants to change routing (e.g., from proxy to direct), check the provider's agent whitelist first — some endpoints (Kimi coding) block non-approved clients regardless of valid credentials.
- **Kimi direct API blocks non-approved agents with 403.** Kimi for Coding returns `access_terminated_error` for agents not on their whitelist (Claude Code, Roo Code, etc.). claw-code is NOT whitelisted. The fix: route Kimi through the Nous/Hermes proxy at `http://127.0.0.1:8645/v1` using model slug `moonshotai/kimi-k2.6` and auth key `hermes-proxy-auth`. The proxy uses Nous OAuth credentials and presents as an approved client.
- **Nous proxy requires credits for paid models.** Even after fixing the 403, Nous returns 404 with "account balance is too low" if you have $0. Only `openrouter/owl-alpha` is free through the proxy. DeepSeek V4 Flash is cheap ($0.10/M tokens) but not free. To use Kimi through the proxy, add credits at https://portal.nousresearch.com.
- **Proxy model slugs differ from direct API slugs.** Direct Kimi API uses `kimi-k2.6`; the Nous proxy uses `moonshotai/kimi-k2.6`. Using the wrong slug gives a model-not-found error.
- **Tool output masking can corrupt the wrapper script.** When the wrapper contains `env OPENAI_API_KEY="$_KIMI_KEY"`, tool output may display it as `env OPENAI_API_KEY=***` (masking the variable reference). If you then patch or copy-paste from tool output, you may accidentally write `env OPENAI_API_KEY=***` (literal asterisks) instead of the variable reference. The script will then pass `***` as the actual API key, causing 401. Always verify the wrapper script with `python3 -c "print(open('/home/synth/.local/bin/claw').read())"` after any edit.
- **Literal `***` in wrapper script from copy-paste.** The most common cause of 401 is the wrapper containing `env OPENAI_API_KEY=***` (literal asterisks) instead of `env OPENAI_API_KEY="$_KIMI_KEY"`. This happens when patching from masked tool output or when the `_KIMI_KEY` variable reference is accidentally omitted. The fix: ensure the wrapper reads the key from the sourced env file into a variable, then passes that variable via `env`: `source "$KIMI_API_KEY_SOURCE"; _KIMI_KEY="$KIMI_API_KEY"; env OPENAI_API_KEY="$_KIMI_KEY" "$REAL_CLAW" --model ...`.
