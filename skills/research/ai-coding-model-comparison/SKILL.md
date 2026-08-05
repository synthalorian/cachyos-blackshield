---
name: ai-coding-model-comparison
description: >-
  Systematic methodology for researching, benchmarking, and comparing coding AI
  models across multiple benchmark sources, pricing pages, and real-world
  performance data. Produces actionable recommendations.
triggers:
  - User asks which model is better for coding between two or more
  - User wants to evaluate or switch their primary or backup coding model
  - User asks for pricing research on coding AI subscriptions
  - Researching benchmark scores for any coding LLM
workflow:
  - Step 1: Check Artificial Analysis for intelligence index, speed, price, context per model.
  - Step 2: Check LiveBench for contamination-free coding and agentic coding scores.
  - Step 3: Check SWE-Bench Verified for real-world software engineering task resolution rates.
  - Step 4: Read official blog posts for model-specific custom benchmarks and capabilities.
  - Step 5: Research pricing pages for subscription tiers and pay-per-token API costs.
  - Step 6: Synthesize head-to-head across all metrics and match recommendation to workload.
---
# AI Coding Model Comparison

A systematic process for researching and comparing coding AI models.

## Source Tiers (Priority Order)

### 1. Artificial Analysis (artificialanalysis.ai)
The best single source. Model summary pages show:
- **Intelligence Index** — overall quality ranking (higher is better)
- **Speed** — output tokens per second
- **Input/Output Price** — cost per million tokens
- **Context Window** — max tokens supported
- **Total/Active Parameters** — model architecture data
- **Verbosity** — how many tokens the model generates on average

Navigate to /models/<model-name> for each candidate. The comparison page at / also shows all models on a single chart.

### 2. LiveBench (livebench.ai)
Objective, contamination-free. Questions refresh every 6 months. Key columns:
- **Global Average** — overall ranking
- **Coding Average** — direct programming ability
- **Agentic Coding Average** — multi-step tool-use coding
- **Reasoning Average** — logical reasoning

**Extraction trick:** The JS-rendered table truncates in snapshots. Use browser_console:
```js
Array.from(document.querySelectorAll('tr')).slice(1, 100).map(tr => {
  const cells = Array.from(tr.querySelectorAll('td')).map(td => td.textContent.trim());
  return cells.join(' | ');
}).filter(row => row).join('\n')
```

### 3. SWE-Bench (swebench.com)
Real software engineering tasks. Check:
- **Verified tab** — human-filtered 500 instances, consistent mini-SWE-agent v2 harness
- **% Resolved** — percentage of issues the model solved
- **Avg. $** — average cost per evaluation run

### 4. OpenRouter Model Pages (openrouter.ai/models/<slug>)
Each model's page has an Artificial Analysis section with benchmarks you can scrape without leaving OpenRouter. Fastest path when you already know the model IDs.

**Data available:** AA Intelligence/Coding/Agentic Index, GPQA Diamond, HLE, IFBench, τ²-Bench, AA-LCR (long context), GDPval, CritPt, SciCode, Terminal-Bench Hard, knowledge hallucination rates.

**Extraction via browser_console:**
```js
// Get all benchmark section text from a model page
let benchText = []; let capturing = false;
document.querySelectorAll('p, h3, h2').forEach(el => {
  const text = el.textContent.trim();
  if (text.includes('Benchmarks for')) capturing = true;
  if (text.includes('Activity') && capturing) capturing = false;
  if (capturing) benchText.push(el.tagName + ': ' + text);
});
benchText.join('\n');
```

Navigate to `https://openrouter.ai/<provider>/<model-slug>`, click the Benchmarks tab, then extract. Pricing and provider details are on the same page — no need to cross-reference separately.

### 5. Official Blog Posts
Model publishers release their own benchmarks. Common ones:
- **SWE-Bench Pro** — harder SWE tasks than standard Verified
- **VectorDBBench** — long-horizon optimization (GLM-5.1 hit 21.5k QPS over 600 iterations)
- **Terminal-Bench 2.0** — real-world terminal task completion
- **NL2Repo** — natural language to full repository generation

## Pricing Research

Subscription plans charge a fixed monthly fee with tiered usage quotas. Pay-per-token APIs charge per million tokens and unlock rate limits based on cumulative spend.

### Known Plan Structures (May 2026)
**Kimi Code (kimi.com/code):**
| Tier | Discounted | Full Price |
|------|:----------:|:----------:|
| Moderato | $15/mo | $19/mo |
| Allegretto | $31/mo | $39/mo |
| Allegro | $79/mo | $99/mo |
| Vivace | $159/mo | $199/mo |

**Z.AI Coding Plan (z.ai/coding):**
| Tier | Price |
|------|:-----:|
| Lite | $18/mo |
| Pro | $72/mo |
| Max | $160/mo |

## Synthesis

Compare across all metrics. Note unique strengths:
- **Kimi K2.6:** Higher LiveBench scores (72.17 global vs 70.18), faster output (77.6 vs 56.4 t/s), bigger context (256k vs 200k), cheaper
- **GLM-5.1:** Long-horizon endurance, 600+ iteration capability on VectorDBBench, SWE-Bench Pro 58.4% beating GPT-5.4
- **Qwen 3.7 Max:** Highest LiveBench Global Average (74.29) of the three, strongest reasoning (83.34) and math (85.25), but trails Kimi on coding (74.22 vs 78.57) and agentic coding (51.67 vs 58.33)

Match to workload:
- 5-15 agent workflows: prioritize concurrency over per-token price
- Single-agent deep tasks: prioritize intelligence and endurance
- Budget constraint: determine if subscription or pay-per-token is cheaper at expected volume

## Output Format Preference

Present comparisons as:
1. **Ranked table** with winner badges (🏆)
2. **Short recommendation** at the bottom — one sentence for why
3. **Tiered model lists** with shortcuts and descriptions when local models are involved
4. **Cost breakdowns** with total monthly in bold

## Local Model Cleanup Pattern

When trimming a local model lineup:
1. Remove duplicate quants of the same base model (keep higher quality, drop the lower)
2. Remove lightweight models that overlap with better lightweight alternatives (keep ds14b over 9b)
3. Keep the multimodal model as the only vision-capable option
4. Each base model kept should have a clear role in the fallback chain
5. Delete config entries first from llama-swap config.yaml, then delete GGUF files
6. Update memory afterward

## Absorbed Skill: coding-stack-tier-list (Consolidated 2026-05-27)

The `coding-stack-tier-list` skill captured the current model stack configuration (May 2026): cloud models, local models, harness configs, and monthly costs. This is time-sensitive data that supplements the methodology above.

**Current stack snapshot:** Kimi K2.6 Allegro primary ($99/mo), DeepSeek V4 Pro backup (~$50/mo), local 35b Kimi K2.6 distilled + 14b Qwen3 + 9b Qwen3.5 via llama-swap. Total ~$149/mo.

## Pitfalls

- Chinese AI platforms (bigmodel.cn, kimi.com, z.ai) use JS-heavy SPAs. Use browser_vision if snapshot renders empty. curl-based DuckDuckGo HTML search can find links browser can't load.
- Older benchmarks (pre-2026) only cover predecessor models, not current releases.
- Pay-per-token API rate limits unlock at cumulative spend thresholds, not monthly. Kimi direct API: $40 = 100 concurrent connections — often beats any subscription for multi-agent use.
- Subscription plans advertise vague weekly quotas. FAQ may hide actual concurrency numbers.
  • Reddit and Zhihu aggressively block automated access. Old Reddit (old.reddit.com) and non-JS search are often blocked too. Use DuckDuckGo HTML search as an alternative.

## Reference Files

- `references/ai-coding-model-pricing-data.md` — Kimi Code, Z.AI, GLM, Kimi API pricing
- `references/kimi-k26-vs-glm-51-comparison.md` — Full head-to-head across all benchmarks
- `references/qwen-models-pricing-and-benchmarks.md` — Qwen 3.7 Max pricing, access, and LiveBench comparison
