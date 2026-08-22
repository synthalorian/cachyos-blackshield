# LLM API Pricing — Live Snapshot (2025-06-05)

## OpenRouter pricing at time of consultation

| Model | Provider | Input ($/M tokens) | Output ($/M tokens) |
|---|---|---|---|
| DeepSeek v4 Pro | deepseek | $0.435 | $0.87 |
| Kimi K 2.6 | moonshotai | $0.73 | $3.49 |
| GLM 5.1 | z-ai | $0.98 | $3.08 |
| GLM 5.1 flash | z-ai | $0.06 | $0.40 |
| Kimi K 2.5 | moonshotai | $0.40 | $1.90 |

## Bundle plans (not OpenRouter)

| Plan | Provider | Price | Notes |
|---|---|---|---|
| Kimi K 2.6 Allegro | Moonshot | $99/mo | Unlimited primary coding workload |
| GLM 5.1 Pro | Z-AI | $72/mo | Not recommended vs pay-per-use |

## User-specific burn data (Confidential — synth/Carter)

- $72 GLM bundle exhausted in <2.5 days → extrapolated ~$200/mo equivalent
- Daily burn: ~14M tokens
- Monthly burn: ~100M tokens
- Fallback coverage needed: Hermes, claw-code, opencode (heavy multi-session coding)

## Decision outcome from this session

Primary: Kimi K 2.6 ($99 Allegro plan)  
Fallback: DeepSeek v4 Pro on OpenRouter (~$30/month estimated)  
Evicted: GLM 5.1 ($72 plan) — third in quality, second in cost

Budget recommendation: $30/mo buffer on OpenRouter (rolls over if unused).

---
Retrieved via: `curl -s https://openrouter.ai/api/v1/models | python3 filter | sort`
