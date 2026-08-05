# claw wrapper — shortcut routing table (as of 2026-05-28)

## Wrapper Script Location
`/home/synth/synthclaw-ai-setup/configs/wrappers/claw`

## Model Resolution
Sourced from: `synthclaw-resolve.sh` (same directory)

## Current Shortcuts

### Cloud Shortcuts

| Arg | Model | Provider | Base URL | Auth |
|---|---|---|---|---|
| (no args) | `openai/glm-5.1` | Z.AI | `https://api.z.ai/api/coding/paas/v4` | hardcoded key |
| `glm` | `openai/glm-5.1` | Z.AI | `https://api.z.ai/api/coding/paas/v4` | hardcoded key |
| `ds` / `deepseek` | `deepseek/deepseek-v4-flash` | Nous | `http://127.0.0.1:8645/v1` | `hermes-proxy-auth` |
| `mm` / `minimax` | `minimax/minimax-m2.5` | Nous | `http://127.0.0.1:8645/v1` | `hermes-proxy-auth` |
| `v4pro` / `dspro` | `deepseek/deepseek-v4-pro` | OpenRouter | `https://openrouter.ai/api/v1` | `~/.config/claw/openrouter.env` |

### Local Shortcuts (via llama-swap on `http://127.0.0.1:8080/v1`)

| Shortcut | Resolved Model | Context |
|---|---|---|
| `35b` | `synthclaw-35b-128k` | 128K |
| `35bmax` | `synthclaw-35b-256k` | 256K |
| `35bultra` | `synthclaw-35b-512k` | 512K |
| `35bkimi` | `synthclaw-35bkimi-128k` | 128K |
| `35bkimimax` | `synthclaw-35bkimi-256k` | 256K |
| `35bkimiultra` | `synthclaw-35bkimi-512k` | 512K |
| `14b` | `synthclaw-14b-128k` | 128K |
| `14bmax` | `synthclaw-14b-256k` | 256K |
| `14bultra` | `synthclaw-14b-512k` | 512K |
| `9b` | `synthclaw-9b-128k` | 128K |
| `9bmax` | `synthclaw-9b-256k` | 256K |
| `9bultra` | `synthclaw-9b-512k` | 512K |
| `local` | `$SYNTHCLAW_MODEL` or `synthclaw-35b-128k` | env/default |

### Local Model Bases
- `35b` → Qwen3.6-35B-A3B (MoE, IQ3_S, 13GB) — coding + vision
- `14b` → Qwen3-14B (dense, Q4_K_M, 8.4GB) — general
- `9b` → Qwen3.5-9B (dense, Q4_K_M, 5.3GB) — gaming/lightweight

## Credential Files

| File | Permissions | Purpose |
|---|---|---|
| `~/.config/claw/openrouter.env` | 600 | OpenRouter API key (`OPENROUTER_API_KEY`) |

## Binary Candidate Paths (searched in order)
1. `~/claw-code/rust/target/release/claw`
2. `~/claw-code/target/release/claw`
3. `/usr/local/bin/claw`
4. `/usr/bin/claw`
