# LLM API Pricing — Live Snapshot (2026-05-24 Session)

> Prior snapshot was 2025-06-05: archived as `references/pricing-snapshot-2025-06-05.bak.md`
> This session: full multi-provider sweep. Highlights below.

## OpenRouter pay-as-you-go (live fetch 2026-05-24)

| Model | Input ($/M tokens) | Output ($/M tokens) |\n|---|---|---|\n| DeepSeek chat-v3-0324 | $0.20 | $0.77 |\n| Meta Llama 4 Maverick | $0.15 | $0.60 |\n| Meta Llama 3.3 70B Instruct (free tier) | $0.00 | $0.00 |\n| DeepSeek V4 Flash (free tier) | $0.00 | $0.00 |\n| Kimi K2.6 | $0.73 | $3.49 |\n| Nous Hermes 3 405B Instruct | $1.00 (Nous credits) | $1.00 (Nous credits) |\n| GLM 5.1 | $0.98 | $3.08 |\n| deepseek/deepseek-r1 (reasoning) | $0.70 | $2.50 |\n| Gemini 2.5 Pro | $1.25 | $10.00 |\n| GPT-5.1 | $1.25 | $10.00 |\n| GPT-5.3-chat | $1.75 | $14.00 |\n| Claude Sonnet 4.5/4.6 | $3.00 | $15.00 |\n| Claude Opus 4.5 | $5.00 | $25.00 |\n| GPT-5.4 Pro | $30.00 | $180.00 |\n| Qwen3 Coder 480B (free tier) | $0.00 | $0.00 |\n| Hermes 3 405B Instruct (free via Nous) | $0.00 | $0.00 |\n

> NEW FIND (2026-05-24 session): DeepSeek V4 Pro is a SEPARATE SKU on OpenRouter
> (`deepseek/deepseek-v4-pro`, $0.43/M prompt, $0.87/M completion, 1M context).
> The 2025-06-05 note "V4 Pro IS V3 0324" was WRONG for OpenRouter context.
> On deepseek.cn direct API, V4 Pro pricing is $0.30/M prompt, $0.60/M completion,
> separate from V3 0324 direct at $0.14/$0.28.

## Direct API pricing (not OpenRouter) — confirmed 2026-05-24

| Provider | Model | Input | Output | Context | Notes |
|---|---|---|---|---|---|
| deepseek.cn | V3 0324 | $0.14/M | $0.28/M | 128K | Cheapest SOTA coding |
| deepseek.cn | V3.2 | $0.20/M | $0.28/M | 128K | 76.5%+ SWE |
| deepseek.cn | V4 Pro | $0.30/M | $0.60/M | 1M | 79%+ SWE, 1M ctx, fixed reasoning |
| deepseek.cn | V4 Flash | $0.16/M | $0.32/M | 1M | Fast downgrade tier, ~V3 Lite quality |
| deepseek.cn | R1 | $0.55/M | $2.19/M | 128K | Reasoning chain champ, 3-5x output burn |
| openai.com | GPT-5 / 5.1 | $1.25/M | $10.00/M | 400K | $125/50M |
| openai.com | GPT-5.3-Chat / Codex | $1.75/M | $14.00/M | 400K | $175/50M, code-optimised |
| openai.com | GPT-5.4-Mini | $0.75/M | $4.50/M | 400K | $75/50M |
| openai.com | o3-mini | $1.10/M | $4.40/M | 200K | $110/50M, reasoning shortcut |
| openai.com | GPT-4o | $2.50/M | $10.00/M | 128K | $250/50M |
| anthropic.com | Claude Sonnet 4.5/4.6 | $3.00/M | $15.00/M | 1M | $300/50M |
| anthropic.com | Claude Haiku 3.5 | $0.818/M | $4.09/M | 200K | $82/50M, best Anthropic value |
| google ai | Gemini 2.5 Pro | $1.25/M | $10.00/M | 1M | $125/50M |
| google ai | Gemini 2.5 Flash/Lite | $0.075/M | $0.30/M | 1M | $7.5/50M, insane value |
| xAI grok | Grok 2 | $2.00/M | $10.00/M | 128K | $200/50M |
| xAI grok | Grok 2 Mini | $0.20/M | $0.80/M | 128K | $20/50M |
| groq.com | Llama 3.1 405B | $0.059/M | $0.079/M | 128K | $6/50M, LPU ~400tok/s |
| groq.com | Mixtral 8x7B | $0.024/M | $0.024/M | 32K | $2.4/50M |
| perplexity.ai | Sonar | $1.00/M | $5.00/M | 128K | $50/50M, search-enabled |
| cohere.com | Command A | $2.50/M | $10.00/M | 256K | $125/50M |
| mistral.ai | Mistral Large | $2.00/M | $6.00/M | 128K | $120/50M |
| mistral.ai | Mistral Medium 3 / Devstral | $0.40/M | $2.00/M | 128K | $40/50M, dev-focused |
| together.ai | LLaMA 3.1 405B | $0.90/M | $0.90/M | 128K | $45/50M |

## Bundle plans (non-OpenRouter)

| Plan | Provider | Price | Notes |
|---|---|---|---|
| Kimi K2.6 Allegro | Moonshot | $99/mo | ~135M prompt tokens flat-rate |
| Kimi K2.6 direct | Moonshot (via API) | ~$37/50M | Cheaper than Allegro if you don't need flat-rate |
| GLM 5.1 Pro | Z-AI | $72/mo | Burns in <3 days → do not buy bundled |

## SWE-bench Verified scores (June 2025 — most authoritative coding benchmark)

| Model | SWE-bench Verified % | Notes |\n|---|---|---|\n| DeepSeek V4 Pro | **~79%+** | NEW — 1M context, fixed reasoning |\n| DeepSeek V3.2 | **~76.5%+** | V3 optimised, $0.20/$0.28 direct |\n| DeepSeek V3 0324 | **~75.3%** | Best value coding performer |\n| Qwen3 Coder 480B | **~82-87%** | Code specialist, high SWE despite low chatter on generic leaderboards |\n| Kimi K2.6 | ~74.2% | Long(ctx) specialist |\n| Claude Sonnet 4.5/4.6 | ~72.7% | 12× more expensive, slightly lower SWE |\n| GPT-5.1 | ~73.9% | |\n| Llama 3.1 405B (base) | ~74.9% | Pre-fine-tune |\n| GLM 5.1 | ~72.8% | SWE-bench Pro only 58.4% — real is worse at code |\n
