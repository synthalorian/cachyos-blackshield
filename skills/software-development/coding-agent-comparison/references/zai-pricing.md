# Z.AI Pricing & GLM Model Access

> As of May 2026. Verify at [z.ai/pricing](https://z.ai/pricing) — pricing and model access tiers change.

## Pro Plan ($72/mo)

This is synth's plan. The value prop: A-tier coding performance for 64% less than Claude Max or Codex.

### Included models (all accessible via zai-coding-plan provider)

| Model | Params | Active | Best For |
|-------|--------|--------|----------|
| `glm-5.1` | 744B | 40B | Primary coding, SWE-Bench Pro 58.4 (beats Opus 4.6's 57.3) |
| `glm-5-turbo` | ? | ? | Faster responses, lighter tasks |
| `glm-5v-turbo` | ? | ? | Vision (multimodal-looker in OmO) |
| `glm-4.7` | ? | ? | Legacy, fallback |
| `glm-4.5-air` | ? | ? | Lightweight, non-coding tasks |

### Note on model availability

Z.AI's coding-paas endpoint (`api.z.ai/api/coding/paas/v4`) serves the Pro-tier models. The regular API endpoint (`api.z.ai/v1`) may have different model availability. The OpenCode OmO provider must use the coding-paas endpoint.

### OmO Cost-Optimized Agent Routing

Synth's configuration routes GLM-5.1 tokens to the agents that need them most:

**GLM-5.1 (paid):** sisyphus (primary coding), oracle (code review), prometheus (docs), metis (task planning), momus (critic), atlas (architecture), visual-engineering, ultrabrain, deep, artistry categories

**Free tier (minimax-m2.5-free):** librarian (search), explore (codebase exploration), sisyphus-junior (lightweight subagent), quick and unspecified-low categories

**GLM-5V-Turbo (paid):** multimodal-looker (vision)

This means most agent interactions (searches, exploration, light queries) cost $0, while complex coding work routes to the GLM-5.1 paid tier. The cost-per-useful-output is significantly lower than a single-agent setup that burns API credits on every interaction.

## Comparison to Other Plans

| Plan | Price | Models | Best For |
|------|-------|--------|----------|
| Pro | **$72/mo** | All GLM-5.x, 4.7, 4.5-air | Serious coding work with agent routing |
| Free / Coding Plan | $10/mo | Limited GLM models | Evaluation, light usage |
| Enterprise | Custom | Custom | Teams, SLA, dedicated infra |

## Why This Matters for Agent Selection

- **OmO + GLM-5.1 at $72/mo** = A-tier coding agent platform for the price of a game console subscription
- **Claude Max at $200/mo** = 2.8x cost for similar-or-slightly-better coding (Opus 4.7 vs GLM-5.1)
- **Codex at $200/mo** = Same pricing, GPT-5.4 may be marginally better but not 3x better
- **Free alternatives** (local models, Nous free tier) = Good for auxiliary tasks but not for primary coding agent loop

The OmO routing pattern (paid model for heavy agents, free models for light agents) is what makes this truly cost-effective — you're not paying GLM-5.1 rates for `grep` and file search.
