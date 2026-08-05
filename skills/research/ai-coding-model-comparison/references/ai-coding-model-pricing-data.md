# AI Coding Model Pricing Data (May 2026)

Gathered from official pricing pages during research session.

## Kimi Code Subscription Plans

Source: kimi.com/code

| Tier | Discounted | Full Price | Annual (per month) | Description |
|------|:----------:|:----------:|:------------------:|-------------|
| Moderato | $15/mo | $19/mo | $180/yr ($15/mo) | Advanced Flow. Weekly refreshed usage quotas, multi-device login. |
| **Allegretto** | **$31/mo** | **$39/mo** | **$372/yr ($31/mo)** | **Pro Choice (Recommended).** Ample weekly limits, increased concurrency caps. |
| **Allegro** | **$79/mo** | **$99/mo** | **$948/yr ($79/mo)** | **Premium Mode.** Expansive quota for daily tasks to intensive development. |
| Vivace | $159/mo | $199/mo | $1,908/yr ($159/mo) | Ultimate Boost. Highest weekly plan quotas for complex projects and large codebases. |

All plans also include other Kimi membership benefits.

## Z.AI Coding Plan (Zhipu AI / bigmodel.cn)

Source: bigmodel.cn (Z.AI Coding Plan page)

| Tier | Price | Description |
|------|:-----:|-------------|
| Lite | $18/mo | 3x Claude Pro usage limits. Built for lightweight iteration on small repos. Rolling access to latest models. Supports 20+ coding tools including Claude Code. |
| Pro | $72/mo | Everything in Lite + 5x Lite usage. Day-to-day development on mid-sized repos. Priority access to latest models. Includes curated MCP tools. Faster generation speeds. |
| Max | $160/mo | Everything in Pro + 20x Lite usage. Advanced users on mid-to-large repos. First access to latest models. Dedicated resources during peak times. |

## GLM-5.1 Pricing Notes

- GLM-5.1 (Reasoning) via Z.AI API: $1.40/M input tokens, $4.40/M output tokens (cache $0.26/M)
- GLM-5.1 is a 744B total / 40B active parameter MoE model
- Context window: 200k tokens
- Released April 2026
- Open weights under MIT license on HuggingFace

## Kimi K2.6 Pricing Notes

- Kimi K2.6 via direct API (platform.kimi.ai): $0.95/M input tokens, $4.00/M output tokens (cache $0.16/M)
- Rate limits by cumulative spend: $10 = 50 concurrency / 200 RPM, $20 = 100 concurrency / 500 RPM, $100 = 200 concurrency / 5,000 RPM
- Kimi K2.6 is a 1,000B total / 32B active parameter MoE model
- Context window: 256k tokens
- Released April 2026
- Open weights under Modified MIT license on HuggingFace

## Qwen 3.7 Max Pricing Notes

- Available via Alibaba Cloud Bailian (百炼) Model Studio API — pay-per-token
- No dedicated coding subscription exists (unlike Kimi Code or Z.AI Coding Plan)
- Alibaba offers a "Token Plan" for teams — prepaid tokens across multiple models
- Qwen 3.7 Max also available via third-party providers (OpenRouter, etc.) at varying markups
- Alibaba Cloud also hosts Kimi K2.6, GLM-5.1, MiniMax-M2.7, and DeepSeek V4 as third-party models on their platform
- Full LiveBench comparison in `references/qwen-models-pricing-and-benchmarks.md`
