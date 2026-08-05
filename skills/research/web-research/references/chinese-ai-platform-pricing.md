# Chinese AI Platform Pricing Research (May 2026)

## GLM Coding Plan (bigmodel.cn)

Direct from Zhipu AI (bigmodel.cn) — not Z.AI Pro reseller pricing.

| Tier | Monthly (CNY) | Monthly (~USD) | Quota | Concurrency |
|------|:---:|:---:|:---|:---|
| Lite | ¥49 | ~$7 | 3x Claude Pro | Multiple (lowest) |
| Pro | ¥149 | ~$20.50 | 5x Lite usage | Multiple (mid) |
| Max | ¥469 | ~$64.50 | 20x Lite usage | Multiple (highest) |

**Models included:** GLM-5.1, GLM-5-Turbo, GLM-4.7, GLM-4.5-Air

**Quota consumption rules:**
- GLM-5.1/GLM-5-Turbo: 3x quota during peak, 2x off-peak
- Promo until end of June: off-peak consumption is only 1x
- Peak hours: 14:00-18:00 UTC+8 (overnight for Eastern US — synth is always off-peak)

**Concurrency:** All tiers have "multiple concurrent requests" but exact numbers are unpublished. Max > Pro > Lite. Dynamic throttling during peak cluster load.

**Critical finding:** Concurrency and rate limit details are deliberately vague — published as "Max > Pro > Lite" with no hard numbers. The FAQ explicitly says concurrency varies with cluster load during peak hours.

**Access note:** bigmodel.cn is a Chinese platform with heavy bot detection. Pages may render blank (JS-heavy, anti-scraping). If it fails, try Z.AI platform instead.

**Source:** bigmodel.cn/glm-coding FAQ expanded via browser_console JS evaluation.

---

## Z.AI Coding Plan (z.ai / api.z.ai / chatglm.cn)

The coding-specific subscription from Zhipu AI — this is what shows Lite/Pro/Max tiers. Separate from the consumer chat product (智谱清言).

| Tier | Monthly | Description |
|:----:|:------:|:------------|
| **Lite** | **$18/mo** | 3x Claude Pro usage limits, supports 20+ coding tools |
| **Pro** | **$72/mo** | 5x Lite usage, faster speeds, MCP tools, priority access |
| **Max** | **$160/mo** | 20x Lite usage, first access to models, dedicated peak resources |

**Key features:**
- Supports Claude Code, OpenCode, OpenClaw, Cline, Kilo Code, and 20+ other tools
- Pro includes "curated selection of MCP tools"
- Max includes "dedicated resources during peak times"
- The user's screenshot showed Pro marked as "Popular" with "My Subscription" badge

**Note:** This is DIFFERENT from the GLM Coding Plan (bigmodel.cn). They offer the same models but different pricing tiers, access mechanisms, and feature sets. Z.AI Coding Plan is the English-friendly alternative.

---

## Z.AI Pro (chatglm.cn / consumer chat)

The consumer chat product from Zhipu — separate from the Coding Plan.

- **Z.AI Pro: $72/mo** — gives access to GLM-5.1 through the web/chat interface
- **Not interchangeable** with the GLM Coding Plan or Z.AI Coding Plan
- Best for: chat, research, deep research, document analysis via web UI

---

## Kimi Code Subscription Plans (kimi.com/code)

Monthly subscription plans for Kimi's CLI/IDE coding tool (powered by kimi-k2.6):

| Tier | Discounted | Full Price | Description |
|:----:|:---------:|:---------:|:------------|
| **Moderato** | **$15/mo** | $19/mo | Advanced Flow — weekly refreshed quotas, multi-device |
| **Allegretto** | **$31/mo** | **$39/mo** | Pro Choice — Recommended — increased concurrency caps |
| **Allegro** | **$79/mo** | **$99/mo** | Premium Mode — expansive quota for intensive dev |
| **Vivace** | **$159/mo** | **$199/mo** | Ultimate Boost — highest weekly plan quotas, max concurrency |

**Annual billing available:** Save ~$20/mo on higher tiers (e.g., Allegro $79/yr vs $99/mo).

**Key notes:**
- All plans include Kimi membership benefits (other Kimi products)
- Plans are for the Kimi Code CLI tool specifically (not the API)
- Concurrency details not published per-tier (like GLM)
- Allegretto ($31/mo) is the sweet spot — marked "Pro Choice Recommended"
- For multi-agent (11+ parallel agents): Allegro ($79/$99) or Vivace ($159/$199) recommended

**Source:** kimi.com/code — subscription page.

---

## Kimi K2.6 Direct API (platform.kimi.ai)

**Pricing model:** Pay-as-you-go, no subscriptions.

**Token pricing (K2.6):**
- Input: $0.95/MTok
- Output: $4.00/MTok
- Cache hit: $0.16/MTok

**Rate limits (by cumulative spend):**

| Tier | Spend | Concurrency | RPM | TPD |
|:---:|:---:|:---:|:---:|:---:|
| 0 | $1 | 1 | 3 | 1.5M |
| 1 | $10 | 50 | 200 | Unlimited |
| 2 | $20 | **100** | 500 | Unlimited |
| 3 | $100 | 200 | 5K | Unlimited |

**Key insight:** At $20 cumulative spend, you get **100 concurrent connections** — dramatically better for multi-agent workflows than GLM's vague "multiple" concurrency. At $40, still at 100 concurrency with more RPM.

**Source:** platform.kimi.ai/docs/pricing.

---

## Qwen 3.7 Max (Alibaba Cloud 百炼)

**Access:** Through Alibaba Cloud's 百炼 (Bailian / Model Studio) platform at help.aliyun.com/zh/model-studio

**Subscription model:** Token Plan (prepaid tokens via Alibaba Cloud), not a monthly flat rate. Also offers "Qwen Code" CLI tool.

**Pricing:** Pay-as-you-go via Alibaba Cloud billing. No published flat-rate subscription tiers like Kimi Code or GLM Coding Plan.

**Note:** Alibaba Cloud 百炼 also hosts Kimi K2.6, GLM-5.1, MiniMax-M2.7, and DeepSeek V4 as third-party models — could be a consolidation point.

---

## Model Benchmark Comparison

### LiveBench (2026-01-08) — Full Comparison

| Category | **Qwen 3.7 Max** | **Kimi K2.6 Thinking** | **GLM 5.1** |
|:---------|:----------------:|:---------------------:|:-----------:|
| **Global Average** | **74.29** 🏆 | 72.17 | 70.18 |
| **Coding** | 74.22 | **78.57** 🏆 | 75.37 |
| **Agentic Coding** | 51.67 | **58.33** 🏆 | 55.00 |
| **Reasoning** | **83.34** 🏆 | 79.38 | 72.52 |
| **Math** | 84.28 / **85.25** 🏆 | 84.28 | 84.89 |
| **Data Analysis** | **71.79** 🏆 | 65.13 | 63.23 |
| **Language** | **79.74** 🏆 | 75.14 | 71.78 |
| **IF** | **74.04** 🏆 | 64.36 | 68.45 |

**Key takeaways:**
- Qwen 3.7 Max wins Global Average and most general categories
- Kimi K2.6 wins **Coding** (78.57) and **Agentic Coding** (58.33) — the two most important metrics for AI coding agent work
- GLM-5.1 sits between them on coding but below Kimi on agentic

### Artificial Analysis — Intelligence Index

| Model | Score | Rank (of 87) |
|-------|:----:|:-----------:|
| GPT-5.5 (xhigh) | 60 | — |
| Claude Opus 4.7 (max) | 57 | — |
| Gemini 3.1 Pro Preview | 57 | — |
| **Kimi K2.6** | **54** | **#1** |
| MiMo-V2.5-Pro | 54 | — |
| Grok 4.3 (high) | 53 | — |
| DeepSeek V4 Pro (Max) | 52 | — |
| **GLM-5.1** | **51** | **#4** |
| Qwen 3.7 Max | Not in top tier | — |

### Speed (tokens/second)

| Model | Speed | Rank |
|-------|:----:|:----:|
| **Kimi K2.6** | **77.6 t/s** | #19/87 |
| **GLM-5.1** | 56.4 t/s | #30/87 |

### API Pricing

| Model | Input | Cache Hit | Output |
|-------|:----:|:---------:|:-----:|
| **Kimi K2.6** | **$0.95** | **$0.16** | **$4.00** |
| **GLM-5.1** | $1.40 | $0.26 | $4.40 |
| Average (87 models) | $0.40 | — | $1.67 |

### Context Window

| Model | Context |
|-------|:-------:|
| **Kimi K2.6** | **256k tokens** |
| **GLM-5.1** | 200k tokens |
| **Qwen 3.7 Max** | Not published on AA |

### Technical Specs

| Spec | Kimi K2.6 | GLM-5.1 |
|------|:--------:|:--------:|
| Parameters | 1,000B (32B active) | 744B (40B active) |
| Reasoning | Yes | Yes |
| Input Modality | Text, Image, Video | Text |
| Output | Text | Text |
| License | Modified MIT | MIT |
| Released | April 2026 | April 2026 |

### SWE-Bench Scores

**SWE-Bench Pro (from z.ai blog):**
- **GLM-5.1: 58.4%** — beats GPT-5.4 (57.7%) and Opus 4.6 (57.3%)
- Kimi K2.6: Not submitted to SWE-Bench Pro
- GLM-5.1 also demonstrated 600+ iteration optimization on VectorDBBench (21.5k QPS, 6× best single-session)

**SWE-Bench Verified (previous gen — GLM-5 vs Kimi K2.5):**
- GLM-5: 72.80%
- Kimi K2.5: 70.80%

---

## Three-Tier Fallback Chain Pattern

For multi-agent coding workflows (11+ agents), a recommended architecture emerged:

| Tier | Role | Example | Budget |
|:----:|:----|:--------|:------:|
| 🥇 Primary | Best coding model, most concurrency | Kimi Code Allegro ($99/mo) | $80-100/mo |
| 🥈 Fallback | Second-best, available when primary capped | GLM Coding Pro ($20/mo) or Z.AI Lite ($18/mo) | $18-20/mo |
| 🥉 Cold backup | Last resort, cheap | MiniMax M2.7 ($20/mo) | $20/mo |

**Key principle:** Put the strongest coder (Kimi K2.6) as primary, not the most expensive subscription. The Z.AI Coding Plan Lite ($18/mo) is sufficient as a GLM-5.1 fallback when Kimi is primary.

---

## General Research Notes

- Chinese AI platforms frequently separate their consumer app (kimi.com) from their API platform (platform.kimi.ai). Always check both.
- bigmodel.cn is the Chinese portal with heavy bot detection — if it renders blank, try Z.AI platform instead
- GLM's Coding Plan is a subscription model. Kimi's API is pay-per-token with rate limits scaling by cumulative spend. These are fundamentally different pricing philosophies.
- For multi-agent setups (11+ agents in OpenCode), **concurrency is the critical metric** — not monthly token quota. Kimi direct API wins here by a wide margin.
- Z.AI Coding Plan ($18/$72/$160) and GLM Coding Plan (¥49/¥149/¥469) are **different products** with different pricing, even though both use GLM models.
- Alibaba Cloud 百炼 hosts Kimi K2.6, GLM-5.1, MiniMax-M2.7, and DeepSeek V4 as third-party models — potential consolidation point
