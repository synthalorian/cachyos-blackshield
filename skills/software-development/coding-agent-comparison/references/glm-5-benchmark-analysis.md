# GLM-5 / GLM-5.1 Benchmark Analysis

Research date: May 2026

## Key Takeaway

GLM-5.1 is **A-tier for coding-specific work**, not B-tier. General intelligence benchmarks (Artificial Analysis composite score of 51) are misleading for coding agent use cases. On the benchmarks that predict coding agent performance, GLM-5.1 matches or beats Claude Opus 4.6.

## SWE-Bench Pro (the coding-agent benchmark that matters)

Source: Zhipu blog post (z.ai/blog/glm-5.1, April 2026)

| Model | Score |
|-------|-------|
| **GLM-5.1** | **58.4** |
| GPT-5.4 | 57.7 |
| Claude Opus 4.6 | 57.3 |
| GLM-5 | 55.1 |
| Gemini 3.1 Pro | 54.2 |

GLM-5.1 beats Opus 4.6 on this benchmark.

## SWE-Bench Verified (GLM-5 data)

Source: Zhipu blog post (z.ai/blog/glm-5, February 2026)

| Model | Score |
|-------|-------|
| Claude Opus 4.5 | 80.9 |
| GPT-5.2 | 80.0 |
| **GLM-5** | **77.8** |
| Kimi K2.5 | 76.8 |
| Gemini 3.0 Pro | 76.2 |
| GLM-4.7 | 73.8 |
| DeepSeek-V3.2 | 73.1 |

GLM-5 (predecessor) was already competitive. GLM-5.1 is a significant jump.

## SWE-Bench Multilingual

Source: Zhipu blog post

| Model | Score |
|-------|-------|
| Claude Opus 4.5 | 77.5 |
| **GLM-5** | **73.3** |
| Kimi K2.5 | 73.0 |
| GLM-4.7 | 66.7 |
| DeepSeek-V3.2 | 70.2 |
| GPT-5.2 | 72.0 |
| Gemini 3.0 Pro | 65.0 |

## General Intelligence (Artificial Analysis Intelligence Index)

Source: artificialanalysis.ai (May 2026)

| Model | Index |
|-------|-------|
| GPT-5.5 (xhigh) | 60 |
| GPT-5.5 (high) | 59 |
| Claude Opus 4.7 (max) | 57 |
| Claude Opus 4.7 (high) | 52 |
| **GLM-5.1 (reasoning)** | **51** |
| GLM-5.1 (non-reasoning) | 44 |

6-9 point gap behind frontier on general intelligence. This matters for broad tasks but NOT for coding-agent workflows.

## Vellum Coding Leaderboard

GLM-5.1 does NOT appear on vellum.ai/llm-leaderboard coding tab (as of March 2026). The top 5 for SWE-Bench there:
1. Claude Opus 4.7 — 87.6%
2. Claude Sonnet 4.5 — 82%
3. Claude Opus 4.5 — 80.9%
4. Claude Opus 4.6 — 80.8%
5. GPT 5.2 — 80%

Note: These are SWE-Bench (standard), not SWE-Bench Pro. Different benchmarks.

## GLM-5.1 Design Philosophy

From Zhipu's blog: "purpose-built for long-horizon agentic tasks." Tested on:
- 600+ iteration optimization loops with 6,000+ tool calls
- Vector database optimization (21.5k QPS — 6x single-session result)
- Specifically designed to NOT plateau like earlier models

This maps directly to claw-code's agent loop pattern.

## Corrected Tier Ranking (Coding-Specific)

**S-Tier (coding):** Claude Opus 4.7, GPT-5.4
**A-Tier (coding):** GLM-5.1, Claude Opus 4.6, Kimi K2.5, GPT-5.2
**B-Tier (coding):** GLM-5, DeepSeek-V3.2, Gemini 3.0 Pro

## Open Source Status

- GLM-5 base model: MIT license, weights on HuggingFace — genuinely open source
- GLM-5.1: Closed source, proprietary API only (Z.AI endpoint)
- Cannot run GLM-5.1 locally or fine-tune it

## Speed / Price (Artificial Analysis)

| Metric | GLM-5.1 (reasoning) | GLM-5.1 (non-reasoning) |
|--------|---------------------|------------------------|
| Blended price | $0.90/1M tokens | $0.90/1M tokens |
| Speed | 53 tokens/s | 45 tokens/s |
| Latency (TTFT) | 1.53s | 1.78s |
| Context | 200k | 200k |

vs Claude Opus 4.7: $4.10/1M tokens, 51 tokens/s, 25.8s TTFT. GLM-5.1 is 4.5x cheaper and has 17x lower latency.
