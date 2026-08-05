# Qwen Models & Alibaba Cloud Bailian — Pricing & Access (May 2026)

Source: help.aliyun.com/zh/model-studio/models, livebench.ai, artificialanalysis.ai

## Qwen 3.7 Max

- **Available via:** Alibaba Cloud Bailian (百炼) platform — Model Studio API
- **Pricing:** Pay-per-token via Alibaba Cloud (no dedicated coding subscription)
- **Token Plan:** Alibaba offers a "Token Plan" subscription for teams — prepaid tokens across multiple models
- **Also available as third-party model on:** Alibaba Cloud directly (they host Kimi K2.6, GLM-5.1, MiniMax-M2.7, DeepSeek V4 as third-party models too)

## Subscription Model

Qwen does NOT have a dedicated coding subscription like Kimi Code or GLM Coding Plan. Access is through:
1. **Alibaba Cloud Bailian API** — pay-per-token, rate limits based on account tier
2. **Token Plan** — prepaid token subscription for teams, not a flat monthly quota plan
3. **Qwen Code** — CLI tool similar to Kimi Code, but subscription structure is not well documented

## LiveBench Comparison (2026-01-08) — Qwen 3.7 Max vs Kimi K2.6 vs GLM 5.1

| Category | Qwen 3.7 Max | Kimi K2.6 | GLM 5.1 |
|----------|:------------:|:---------:|:-------:|
| Global Average | **74.29** 🏆 | 72.17 | 70.18 |
| Coding | 74.22 | **78.57** 🏆 | 75.37 |
| Agentic Coding | 51.67 | **58.33** 🏆 | 55.00 |
| Reasoning | **83.34** 🏆 | 79.38 | 72.52 |
| Math | **85.25** 🏆 | 84.28 | 84.89 |
| Data Analysis | **71.79** 🏆 | 65.13 | 63.23 |
| Language | **79.74** 🏆 | 75.14 | 71.78 |
| IF | **74.04** 🏆 | 64.36 | 68.45 |

Qwen 3.7 Max wins global and most categories, but for **code-specific agent work**, Kimi K2.6 is significantly better (+4.3 coding, +6.6 agentic).

## Key Takeaway

For a user running 11 coding agents, Kimi K2.6 (via Kimi Code subscription) is the better primary despite Qwen 3.7 Max's higher global average. Qwen excels at reasoning/math but for pure coding agent work, Kimi is the right choice. Qwen is not available as a flat-rate subscription — only pay-per-token through Alibaba Cloud.
