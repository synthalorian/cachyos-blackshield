---
name: llm-provider-strategy
description: Multi-provider LLM API strategy — cost comparison, model selection, fallback architecture, and benchmark-based quality ranking for commercial LLM providers (OpenRouter, Kimi/Moonshot, GLM, etc.). Use when deciding which models to use as primary vs fallback, estimating API burn, comparing provider costs, or architecting dual-provider LLM setups that won't run out of tokens.
---

# LLM Provider Strategy

## When to use this skill

- User asks which LLM model(s) or provider(s) to pay for
- Comparing costs between bundled plans vs pay-as-you-go APIs
- Setting up primary + fallback LLM architecture
- Estimating monthly API burn from observed token consumption
- Deciding whether a cheaper model is actually a downgrade in quality
- Token budget planning, rate-limit mitigation, or cost optimization
- Mid-session provider failure (401/429/503) killing conversations
- Configuring Hermes fallback behavior (`fallback_providers` vs `fallback_model` vs credential pooling)
- Diagnosing why a provider exhausts mid-stream and how to prevent it

---

## ⚡ synth's Current Stack (May 2026)

This is the FINAL provider stack. Recommend changes only if the user asks.

| Role | Model | Provider | Cost | Monthly |
|------|-------|----------|:----:|:-------:|
| **Daily driver** | Kimi K2.6 | Kimi Allegro | **$99/mo flat** | $99 |
| **Cloud secondary** | DeepSeek V3/V4 + free fallbacks | OpenRouter ($50 credit) | **~$50/mo** | ~$50 |
| **Local / offline** | 35b Kimi K2.6 distilled + 14b + 9b | llama-swap | **$0** | $0 |
| **Downtime** | FreeBuff | FreeBuff | **$0** | $0 |
| **Total** | | | | **~$149/mo** |

$50 OpenRouter credits are pay-per-token with free model fallbacks — no arbitrary rate limits. Credits last based on usage; free fallbacks extend them further.

**Removed from rotation (May 2026):** GLM 5.1 ($72/mo — hit 5-hour rate limit in 4 hours of full-time use; not open-weight; trails Kimi/DeepSeek on coding benchmarks), GPT Codex (not needed with Kimi + DeepSeek), DeepSeek V4 Flash free tier (lost access).

**Decision reasoning:** GLM was $72/mo for a model that rate-limits in 4 hours and isn't genuinely open-source. Swapping for DeepSeek on OpenRouter supports the open-source ecosystem (DeepSeek is fully open-weight), has no hard rate caps, and codes better. Kimi K2.6 is also open-weight. Every dollar now goes to open-source projects.

---

## Fallback Architecture (synth's setup)

```yaml
# Kimi Allegro is always primary. OpenRouter is the flexible backup with free fallbacks.
primary:   Kimi K2.6 (Allegro, $99/mo) — all harnesses (claw-code, Hermes, OpenCode)
backup:    DeepSeek on OpenRouter ($50 credit, pay-per-token) — overflow + free model fallbacks
downtime:  FreeBuff (5 × 1-hour free sessions) — batch work during off-hours
local:     llama-swap (35b Kimi K2.6 distilled + 14b + 9b) — offline, private, always available
```

### When Local Models Work vs Don't

| Use case | Local ok? | Best local pick |
|----------|:---------:|-----------------|
| Standalone coding (claw-code) | ✅ | 35b Kimi distilled (~40 tok/s) |
| Quick scaffolding / bash / configs | ✅ | 35b Base or 14b |
| Hermes full session | ❌ | Local <70B degrades within 5 turns at ~150K sys-prompt |
| OpenCode multi-agent | ✅ | 35b Kimi for reasoning agent, 14b for quick agent |

### Local Model Constraints (discovered 2026-05-25)

- ALL Qwen3.x models output ` thinking` blocks — they are reasoning-distilled, not base models
- Custom Jinja templates BREAK reasoning extraction — must use GGUF built-in template only
- Kimi K2.6 distilled: NO `--flash-attn on` or `--cont-batching` (hybrid memory → silent hang)
- Use `--parallel 1`, no evict wrapper, no reasoning flags (server defaults handle it)
- Model paths are NOT in the directories the config says — verify actual file locations (`find /home/synth -name "*.gguf"`)

### Prefix-Based Provider Routing (claw-code, some other tools)

Some CLI tools (notably `claw-code`) use **model string prefixes** for hard provider routing that env vars cannot override:

| Prefix | Backend | Notes |
|--------|---------|-------|
| `kimi/` or `qwen/` | DashScope (Alibaba) | Requires `DASHSCOPE_API_KEY`; ignores `OPENAI_BASE_URL` |
| `openai/` | OpenAI-compatible | Respects `OPENAI_API_KEY` + `OPENAI_BASE_URL` |
| `anthropic/` | Anthropic API | Requires `ANTHROPIC_API_KEY` |
| `xai/` or `grok*` | X.AI | Requires `XAI_API_KEY` |

**Pitfall:** Setting `OPENAI_API_KEY` and `OPENAI_BASE_URL` to point at a Kimi proxy, then passing `--model kimi/kimi-k2.6`, will still route to DashScope and fail with "missing DashScope credentials." The fix is to use `--model openai/kimi-k2.6` so the tool routes through the OpenAI-compatible backend to your custom endpoint.

This pattern applies whenever a tool has hardcoded provider backends selected by model prefix rather than by ambient configuration.

### Harness → Model Routing

| Harness | Kimi K2.6 | DeepSeek V4 Pro | Local llama-swap | DeepSeek Flash (free) |
|---------|:---------:|:---------------:|:----------------:|:---------------------:|
| **claw-code** | `claw kimi` (needs provider config) | Needs provider config | `claw 35bkimi` | ❌ |
| **Hermes** | `--provider openrouter -m kimi/kimi-k2.6` | `--provider openrouter -m deepseek/deepseek-v4-pro` | `hermes 35bkimi` | `hermes ds` |
| **OpenCode + omyopenagent** | "oracle" / "prometheus" role | "sisyphus" / "explore" role | "quick" role | Not typically used |

---

## Workflow: Live Pricing + Cost Estimation

### Pitfall: Brand Name Case Sensitivity

When researching models, **brand name casing matters enormously.** Example: "Mimo" (generic) returns nothing; "MiMo" (Xiaomi's brand) is the correct capitalization and finds the model. When a user says "mimo" or "kimi" in lowercase, ALWAYS check both the literal form and common brand capitalizations before concluding a model doesn't exist. Chinese AI companies in particular use mixed-case branding (MiMo, DeepSeek, Kimi, Qwen).

**Research sequence for model comparison:**
1. **OpenRouter** — `openrouter.ai/models?q=<name>` — confirms pricing, providers, weekly token volume
2. **HuggingFace** — `huggingface.co/models?search=<org>+<name>` — confirms license, weights, community size, distilled variants
3. **License file** — click through to actual LICENSE text (not just the badge). "modified-mit" can have branding clauses or usage caps
4. **Ecosystem depth** — check for: distilled models at smaller sizes, native Transformers support vs custom_code, GGUF/MLX quants available, community discussions

### Multi-Provider Sweep (required when user says "look it up")

Sweep across ALL providers, not just OpenRouter.

| Source | Pull method | Coverage |
|---|---|---|
| OpenRouter live API | `curl -s https://openrouter.ai/api/v1/models \| python3 filter` | 450+ models, unified pricing |
| DeepSeek direct | api.deepseek.com | Distinct from OR markup; V3 0324, V3.2, V4 Pro, V4 Flash, R1 |
| OpenAI direct | platform.openai.com/pricing | `gpt-5*`, `o3*`, `o4*` series |
| Anthropic direct | console.anthropic.com/pricing | `claude-sonnet-4*`, `claude-opus-4*`, `haiku-*` |
| Google AI Studio | aistudio.google.com/pricing | `gemini-*` series |
| xAI direct | console.x.ai | `grok-2*`, `grok-3*` |
| Groq | groq.com/pricing | LPU — cheapest SOTA |
| Moonshot direct | moonshot.cn API / Allegro | Kimi K2.x |
| Together AI | together.ai/pricing | Hosted open-source |
| Mistral | mistral.ai/pricing | `mistral-*` |

**OpenRouter prices are markups.** Try direct API prices first.

#### Cost estimation formula

```
weighted_cost_per_M = prompt_cost * frac_input + completion_cost * frac_output
```

| Workload | Input frac | Output frac |
|---|---|---|
| Pure coding | ~70% | ~30% |
| Heavy reasoning / freeform | ~50% | ~50% |

Report **cost per 50M tokens** — the only number power users map to monthly budget.

#### Output format: punchy table, no prose padding

User burning tokens: **table + 3-sentence verdict max.**
"Just look it up" / "why are you explaining" → just the table.

---

## Model Quality Benchmark Hierarchy

| Tier | Signal | Sources |
|---|---|---|
| **Elite** | LiveCodeBench top-5, HumanEval >90% | lmarena.ai, paperswithcode |
| **Strong** | MMLU >88%, MBPP >85% | LiveCodeBench, academic papers |
| **Capable** | MMLU 82-88%, basic code tasks | Vendor benchmarks (skepticism required) |

## Known rankings (May 2026 — Artificial Analysis Intelligence Index)

| Model | AA Score | Context | Architecture | Speed |
|-------|:--------:|:-------:|:------------:|:-----:|
| Kimi K2.6 (full) | **54** | 256k | Dense | 73 tok/s |
| MiMo-V2.5-Pro (Xiaomi) | **53.8** | 1M | MoE | 27 tok/s |
| DeepSeek V4 Pro | **51.5** | 1M | MoE (49B active / 1.6T total) | varies |
| Qwen3.6 35B A3B | **43** | 262k | MoE (3B active) | 179 tok/s |
| Gemma 4 31B (dense) | **39** | 256k | Dense | 35 tok/s |
| Gemma 4 26B A4B (MoE) | **31** | 256k | MoE (4B active) | -- |

### Budget spotlight: MiMo-V2.5 (non-Pro)

At **$0.14/$0.28 per M tokens** (1/3 of Pro-tier pricing), the non-Pro MiMo-V2.5 is omnimodal (text + image + video + audio + file) with 1M context. AA Intelligence Index ~53 (est). Worth considering for high-volume agent tasks that don't need max reasoning. Model ID: `xiaomi/mimo-v2.5`.

### Open Source Commitment Hierarchy (synth values this)

| Rank | Model Family | License | Small Models? | Community |
|:----:|---|---|:---:|---|
| 1 | **DeepSeek** | Pure MIT | ✅ 7B–70B distills | 133k HF followers |
| 2 | **Kimi (Moonshot)** | modified-mit (branding clause for >100M MAU) | ⚠️ No small text chat | 10.1k HF followers |
| 3 | **MiMo (Xiaomi)** | Pure MIT | ❌ Smallest is 311B | 3.3k HF followers |

See `references/mimo-v25-vs-deepseek-v4-pro.md` for full head-to-head including open source breakdown.

Artificial Analysis Intelligence scores are a composite benchmark. Kimi K2.6 leads the local-comparable models significantly.

---

## Free Tier Architecture (fallbacks only, never primary)

| Provider | Free model | Notes |
|---|---|---|
| Nous Research | DeepSeek V4 Flash | 1M ctx, fast, downgraded quality — Hermes agents only |
| Nous Research | Hermes 3 405B | Hermes-native, ~55% SWE |

**Local models <70B do NOT work as Hermes primary.** ~150K sys-prompt per call degrades them within 5 turns. Use only for standalone tasks.

---

## Preventing Mid-Session Provider Failures

### Error Code Taxonomy

| Code | Meaning | Hermes Behavior |
|------|---------|-----------------|
| 401 | Auth/Funds exhausted | **Kills session** — no retry, API key invalid |
| 429 | Rate limited | `fallback_model` triggers if configured |
| 503/529 | Service unavailable | `fallback_model` triggers if configured |

### Mitigation Strategies

| Strategy | Reliability | Notes |
|----------|:-----------:|-------|
| **1. Paid subscription** | ★★★★★ | Kimi Allegro — flat rate, no exhaustion |
| **2. OpenRouter backup** | ★★★★☆ | DeepSeek V4 Pro as fallback when Kimi down |
| **3. Credential pooling** | ★★★★☆ | Multiple keys via `hermes auth add` |
| **4. Enable `fallback_model`** | ★★★☆☆ | Catches 429/503/529, not 401 |
| **5. Local as primary** | ★★★★☆ | Only for standalone tasks, not Hermes |

---

## OpenRouter-Specific Notes

- Credits roll over month-to-month; no hard rate limit on **paid credits**
- **Free tier (`:free` suffix) DOES have rate limits** and account-level lockouts
- Model ID format: `provider/model-name` (e.g. `deepseek/deepseek-v4-pro`)
- $50 seed deposit → months of DeepSeek V4 Pro usage at ~$2-5/mo burn

---

## Kimi-Specific Notes

- Kimi K2.6 on Allegro ($99/mo) is synth's daily driver for ALL coding work
- Do NOT recommend downgrading to DeepSeek-only unless user asks about cost savings
- Kimi outranks DeepSeek on Artificial Analysis intelligence score (54 vs ~50)
- Kimi's strength is structured reasoning — claw-code/Hermes/OpenCode all benefit from this
- Native Kimi API is cheaper than OpenRouter passthrough when direct access is available