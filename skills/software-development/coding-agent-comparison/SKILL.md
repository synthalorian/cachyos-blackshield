---
name: coding-agent-comparison
description: Analysis and recommendation for three AI coding agent setups — claw-code vs Hermes Agent vs OpenCode+OmO. Covers architecture, model strategy (Kimi Vivace, GLM-5.1, local), pricing, OpenRouter pitfalls, and optimal workflow split with decision flowchart.
---

# Coding Agent Comparison: claw-code vs Hermes vs OpenCode+OmO (on GLM-5.1)

## Summary Recommendation

| Use Case | Recommended Tool | Reason |
|----------|-----------------|--------|
| Primary coding (multi-agent) | OpenCode + OmO (glm-5.1) | 11 agents, 54-61 hooks, cost-tiered routing, Team Mode parallelism |
| Primary coding (single-agent) | claw-code (glm-5.1) | Autonomous, async, Rust-fast, single-agent simplicity |
| General assistant | Hermes Agent (Kimi Vivace) | Cross-session memory, skills, cron, 22 platform delivery |

**⚠️ DISAMBIGUATION: claw-code ≠ Claude Code.** claw-code is synth's custom Rust-based OpenShark fork at `~/claw-code/` (binary: `~/.local/bin/claw`). Claude Code is Anthropic's official `claude` CLI agent (`npm install -g @anthropic-ai/claude-code`). They share similar names but are completely different tools. The `claude-code` skill covers Anthropic's tool; this skill covers synth's claw-code.

## Your harnesses as they actually exist:

| Harness | What it is | Best at |
|---------|-----------|---------|
| **Hermes** | This conversation — conversational assistant in Discord | Daily driver, long coding sessions, context persistence, memory across sessions |
| **claw-code** | Rust CLI at `~/claw-code/`, binary `claw` | Autonomous workflows, deep refactors, debugging, architectural vision |
| **OpenShark** | Node.js binary (separate from claw-code) | Finalizations, polish, quick cleanups |
| **OpenCode + OmO** | OpenCode CLI with OhMyOpenAgent swarm | Big planning, initial builds, parallel multi-file feature builds |
| **OpenShark** | Rust CLI at `~/projects/openshark/`, binary `openshark` | Self-improving harness combining best of all above. Persistent memory, TUI, universal routing |

**The rule (as actually practiced):**
- **Hermes** → Daily driver for everything. Long coding sessions where context persistence matters. The "source of truth" that remembers what you did last week. Use for: active development, debugging, architecture decisions, anything needing cross-session memory.
- **OpenCode + OmO** → Big picture planning and initial scaffolding. When you need to architect a new module or feature from scratch. The swarm builds the foundation.
- **claw-code** → Autonomous execution. Big refactors, deep debugging, architectural vision (e.g., conceived the Chronos Engine on a local model, then built the entire foundation). When you need an agent to run independently and produce substantial code.
- **OpenShark** → Final polish. Cleanups, finalizations, one-off edits after the heavy lifting is done.
- **OpenShark** → The unified harness. When you want ONE tool that does it all — chat, memory, tools, routing, self-improvement. Still in development (Phase 2 of 5).

**When to switch:**
- Planning something new, need architecture → OpenCode + OmO
- Building iteratively, need memory of what you did → Hermes
- Deep refactor or complex debug session → claw-code
- Quick polish, cleanup, final pass → OpenShark

**What NOT to do:**
- Don't split your main workflow between harnesses for a single task (fragmentation kills context)
- Don't use Hermes for autonomous long-running builds (it's conversational, not fire-and-forget)
- Don't use OpenCode for quick one-off edits (overhead)
- Don't use claw-code for conversational exploration (it's a builder, not a chat)

**The pipeline pattern (for complex features):**
```
PHASE 1: VISION    → OpenCode + OmO (plan, scaffold, initial build)
PHASE 2: ITERATION → Hermes (continue, refine, remember decisions)
PHASE 3: REFACTOR  → claw-code (deep changes, optimization, debug)
PHASE 4: POLISH    → OpenShark (cleanup, docs, finalization)
```

**OpenShark vs OpenCode + OmO:** Both do "agent builds." The difference is:
- OpenShark = *one* smart agent with tools, sequential — good for focused tasks
- OpenCode + OmO = *eleven* agents in parallel, coordinated — good for complex multi-facet builds

## Pricing Comparison (as of May 2026)

| Setup | Model Cost | Total Monthly | Notes |
|-------|-----------|---------------|-------|
| Hermes on Kimi K2.6 Vivace | **$199/mo** | **$199/mo** | synth's primary. Flat rate, no per-token surprises. Unlimited inference. |
| OpenCode + OmO on GLM-5.1 | **$72/mo Z.AI Pro** (includes glm-5.1, glm-5-turbo, glm-5v-turbo, glm-4.7, glm-4.5-air) | **$72/mo** | Synth has Z.AI coding plan access via separate key |
| claw-code on GLM-5.1 | Same Z.AI Pro plan or routes through Hermes proxy | $0–$72/mo | Can use Hermes proxy for Nous free tier (DeepSeek) |
| OpenCode + OmO with free models | Free (deepseek-v4-flash-free, minimax-m2.5-free) | $0 | Utility agents (librarian, explore, sisyphus-junior) |
| Local K2.6 35B (all three) | $0 | $0 | Via llama-swap port 8080 or Hermes proxy |
| Claude Max | Claude Opus 4.7 | **$200/mo** | Not in synth's stack |

**Key insight:** Kimi Vivace at $199/mo gives you unlimited high-quality inference for Hermes — your daily driver. Z.AI Pro at $72/mo powers the OpenCode swarm. You're spending $271/mo total for a three-harness setup that outperforms a single $200/mo Claude Max subscription.

### ❌ Dropped: OpenRouter DeepSeek v4 Pro

**Burned $4 in 30 minutes.** DeepSeek v4 Pro via OpenRouter charges per-token at rates that make it completely unsustainable for agentic workloads. A single coding session can burn through $8+/hour. OpenRouter credits (~$50/mo budget) would be gone in under a day. The switch to Kimi Vivace ($199/mo flat) was a direct response — unlimited inference at a predictable price beats metered billing for agent-heavy workloads by an order of magnitude.

## Key Comparison Table

| Factor | claw-code | Hermes | OpenCode+OmO |
|--------|-----------|--------|----------|
| Already wired for GLM-5.1 | Full | Full | **Full (primary)** |
| Fits synth workflow | Autonomous async | Daily driver | Terminal-first, multi-agent |
| Config exists | claw wrapper live | Hermes live | **Live at ~/.config/opencode/** |
| Multi-project workspaces | 8 configured | Manual setup | Per-project .opencode/ |
| GLM-5.1 as first-class | Through wrapper | Native support | **Native, all heavy agents** |
| Cost optimization | Single model all-in | Provider routing | **Free tier for light agents** |
| Performance | Rust binary | Python | TypeScript (Bun) |
| Community velocity | 192K stars | Active development | 58.7K stars, MIT license |
| Cross-session memory | No | Yes | No |
| Multi-agent/parallel | No | Delegate only | **Team Mode (8 parallel)** |
| Agent specialization | Single agent | Single agent | **11 specialized agents** |
| Hook sophistication | Basic | Moderate | **54-61 hooks, 5 tiers** |

## Provider Wiring in claw-code

claw-code supports multiple cloud providers through the `claw` wrapper at `~/synthclaw-ai-setup/configs/wrappers/claw`. Each provider is a case in the wrapper's shorthand resolver that sets `OPENAI_API_KEY` and `OPENAI_BASE_URL` before launching the Rust binary.

### Kimi K2.6 Vivace Setup

**Endpoint:** `https://api.kimi.com/coding/v1` (OpenAI-compatible) OR `http://127.0.0.1:8699/v1` (local proxy)
**Model:** `kimi/kimi-k2.6` (upstream requires `provider/model` syntax)
**Auth:** Static API key in `~/....env` (sourced by wrapper)
**Headers required:** `x-kimi-agent-name:Kimi-CLI`, `x-kimi-agent-version:1.0.0`

The wrapper sources `KIMI_API_KEY` from `~/....env` and exports it as `OPENAI_API_KEY` (claw-code's OpenAI-compat provider reads this). The `x-kimi-*` headers are required for Kimi API compliance.

**⚠️ Critical pitfall #1 — Missing env file:** If `~/....env` is missing or contains a placeholder (`***`), the wrapper exports a literal `OPENAI_API_KEY="***"`, which claw-code rejects. It then falls back to other providers (typically Nous proxy), which fails with 404 "model requires available credits" because Nous doesn't route `moonshotai/kimi-k2.6`.

**Fix:** Create `~/....env` with the real key:
```bash
echo 'KIMI_API_KEY=*** > ~/....env
chmod 600 ~/....env
```

**⚠️ Critical pitfall #2 — Model syntax change:** Upstream claw-code now requires `provider/model` format. Bare `kimi-k2.6` fails with:
```
error: invalid model syntax: 'kimi-k2.6'. Expected provider/model (e.g., anthropic/claude-opus-4-7)
```

**Fix:** Update `KIMI_MODEL` in the wrapper:
```bash
# In ~/synthclaw-ai-setup/configs/wrappers/claw
KIMI_MODEL="kimi/kimi-k2.6"  # was "kimi-k2.6"
```

**⚠️ Critical pitfall #3 — reasoning_content 400 error:** Kimi K2.6 sends `reasoning_content` in responses and expects it preserved in conversation history. claw-code's `model_requires_reasoning_content_in_history()` only handles `deepseek-v4` by default. When the field is stripped, Kimi returns:
```
error: api returned 400 Bad Request: thinking is enabled but reasoning_content is missing
```

**Fix:** Patch `~/claw-code/rust/crates/api/src/providers/openai_compat.rs`:
```rust
pub fn model_requires_reasoning_content_in_history(model: &str) -> bool {
    let lowered = model.to_ascii_lowercase();
    let canonical = lowered.rsplit('/').next().unwrap_or(lowered.as_str());
    canonical.starts_with("deepseek-v4") || canonical.starts_with("kimi-k2")
}
```

See `references/kimi-reasoning-content-error.md` for full details and verification steps.

**Local Kimi Coding Plan Proxy**  
If the direct API fails or you need the Coding Plan (requires `claude-code/1.0` User-Agent), use the local proxy:
- **Service:** `~/.config/systemd/user/kimi-proxy.service` (auto-starts at login)
- **Binary:** `~/.local/bin/kimi-proxy` (Python3, spoofs UA as `claude-code/1.0`)
- **Listen:** `127.0.0.1:8699`
- **Upstream:** `https://api.kimi.com/coding`

Update the wrapper to use it:
```bash
# In ~/synthclaw-ai-setup/configs/wrappers/claw
KIMI_BASE_URL="http://127.0.0.1:8699/v1"
```

**Verification:** After all fixes, `claw` (no args) should print `🎹🦞 Cloud: kimi/kimi-k2.6 via Kimi direct` and succeed.

### Routing Architecture

claw-code's Rust binary (`crates/api/src/providers/mod.rs`) resolves model names to providers:

1. **Prefix matching** — `openai/` → OpenAI-compat, `grok` → xAI, `claude` → Anthropic, `gemini-` → Google, `qwen-` → DashScope
2. **Env var fallback** — if `OPENAI_BASE_URL` + `OPENAI_API_KEY` both set, ANY unprefixed model routes to OpenAI-compat provider
3. **Auth sniffer** — checks ANTHROPIC_API_KEY, OPENAI_API_KEY, XAI_API_KEY in order

The env var fallback (item 2) is the key: it means you can pass ANY model name without a provider prefix as long as the env vars are set. The `openai/` prefix in the GLM-5.1 setup is technically redundant.

### Available Shorthands

| Command | Model | Endpoint | Auth |
|---------|-------|----------|------|
| `claw` (default) | `kimi-k2.6` | `api.kimi.com/coding/v1` OR `127.0.0.1:8699/v1` (proxy) | Kimi API key (static) |
| `claw kimi` | `kimi-k2.6` | `api.kimi.com/coding/v1` OR `127.0.0.1:8699/v1` (proxy) | Kimi API key (static) |
| `claw glm` | `glm-5.1` | `api.z.ai/api/coding/paas/v4` | Z.AI API key (static) |
| `claw ds` | `deepseek/deepseek-v4-flash` | `localhost:8645/v1` (Hermes proxy) | Nous OAuth (auto-refreshed) |
| `claw mm` | `minimax/minimax-m2.5` | `localhost:8645/v1` (Hermes proxy) | Nous OAuth (⚠️ needs paid tier) |
| `claw <size>` | Local llama-swap model | `localhost:8080/v1` | `llama-swap-local` (no-op) |

### Handling Short-Lived OAuth Tokens

Some providers (Nous, xAI) use OAuth tokens that expire every 15 minutes. claw-code's `OpenAiCompatClient` reads the API key at startup and **never refreshes it** — it only auto-refreshes gcloud tokens.

**Solution: Hermes OAuth Proxy** — a local HTTP server (`hermes proxy start --provider nous`) that:
- Exposes an OpenAI-compatible endpoint at `localhost:8645/v1`
- Accepts any bearer token (the wrapper uses a dummy)
- Handles OAuth refresh internally via Hermes credential pool
- Runs as a systemd user service (`hermes-proxy.service`) — auto-starts at login

The wrapper sets `OPENAI_API_KEY` and `OPENAI_BASE_URL` to point at the proxy, making claw-code think it's talking to any OpenAI-compatible API. The proxy handles the upstream auth lifecycle transparently.

### MiniMax M2.5 Status

Confirmed unavailable on all free tiers:
- Nous free tier: returns 404 *"Model not available on Free Tier"*
- Z.AI coding plan: returns 1211 *"Unknown Model"* (only 7 GLM models)
- No OpenCode Go/Zen API key in environment

## Benchmark Data

See `references/glm-5-benchmark-analysis.md` for detailed GLM-5/GLM-5.1 benchmark numbers, tier rankings, source URLs, and the coding-vs-general intelligence distinction.

## GLM-5.1 Benchmark Tier (Coding-Specific)

**A-tier for coding.** GLM-5.1 beats Claude Opus 4.6 on SWE-Bench Pro (58.4 vs 57.3) and is purpose-built for the long-horizon agentic tasks that coding agents run. General intelligence benchmarks (Artificial Analysis composite 51) underrepresent its coding capability — that composite dilutes coding scores with reasoning/writing/knowledge tasks that don't matter for `claw glm` workflows.

GLM-5 base model is genuinely open source (MIT, HuggingFace weights). GLM-5.1 is closed/proprietary API only.

**Coding tier ranking:**
- S-Tier: Claude Opus 4.7, GPT-5.4
- **A-Tier: GLM-5.1, Claude Opus 4.6, Kimi K2.5, GPT-5.2**
- B-Tier: GLM-5, DeepSeek-V3.2, Gemini 3.0 Pro

GLM-5.1 is 4.5x cheaper ($0.90 vs $4.10/1M tokens) and 17x lower latency than Claude Opus 4.7. The value proposition for coding is exceptional.

See `references/glm-5-benchmark-analysis.md` for full benchmark data, sources, and reasoning.

## Optimal Workflow Split

```
Multi-agent coding  ->  OpenCode + OmO (GLM-5.1 primary, free tier for light agents)
Single-agent coding ->  claw-code (GLM-5.1, autonomous, async, Rust-fast)
DeepSeek coding     ->  claw-code (claw ds, via Hermes proxy)
Everything else     ->  Hermes (Kimi Vivace, memory, research, cron, multi-platform)
```

**The shared backbone:** All three harnesses route through the **Hermes proxy** (port 8645) for OAuth-protected providers (Nous, xAI) and **llama-swap** (port 8080) for local models. They're not siloed — they share infrastructure. claw-code's model shorthands (`claw glm`, `claw ds`, `claw 35b`) are just convenience wrappers over this shared routing layer.

The multi-agent system builds. The single agent builds fast. The brain remembers.

## When to Pick Which

### Decision Flowchart

```
"What am I doing right now?"
          │
    ┌─────┼─────┐
    ▼     ▼     ▼
  Chat   Code   Schedule
    │     │       │
    ▼     └───┬───┘
  Hermes      │
          ┌───┼───┐
          ▼   ▼   ▼
      Simple  Big  Parallel
       fix   refactor  swarm
        │      │        │
        ▼      ▼        ▼
     Hermes  claw-code  OpenCode
     tools   (claw)     + OmO
```

**If chatting, planning, researching, system config → Hermes (always).** You're already there. This is home base. Use built-in tools for simple file edits (1-3 files, straightforward changes).

**If coding and...**
- 1-3 files, simple edits → **Hermes tools** (patch, read_file, write_file). Don't reach for another agent.
- 3-10 files, complex logic → **claw-code** (`claw glm "refactor auth module"`). Faster than OmO for focused work. `/ultraplan` for architecture, `/bughunter` for scans.
- 10+ files OR need parallelism → **OpenCode + OmO** (`ultrawork`). 11 agents attacking different facets simultaneously. Sisyphus builds, Oracle reviews, Prometheus docs, Momus criticizes — all in parallel.
- Want free compute → **OpenCode** with free models (deepseek-v4-flash-free), or **claw-code** (`claw ds` via Hermes proxy free tier).
- Local privacy → **claw-code** (`claw 35bkimi` via llama-swap) or **OpenCode** (`--model local/synthclaw-35bkimi-128k`).
- VS Code inline → **OpenCode** via OhMyOpenAgent extension.

**If scheduling/running cron → Hermes.** Cron jobs, recurring tasks, multi-platform delivery. Neither claw-code nor OpenCode have persistence layers.

### Per-Agent Detail

**Hermes (Kimi Vivace, $199/mo)** — Your daily driver. Chat, planning, research, system admin, cron jobs, platform delivery. Simple 1-3 file code fixes with built-in tools. Orchestrates the other two via delegate_task or tmux spawning. Use liberally — flat rate, no per-token anxiety.

**OpenCode + OmO (GLM-5.1, Z.AI Pro)** — Complex features, multi-file refactors, PRs needing review+implementation, tasks benefiting from agent specialization (planning → coding → review pipeline), anything where Team Mode parallelism helps. The 11-agent swarm catches what a single agent misses.

**claw-code (Kimi K2.6 Vivace, GLM-5.1, or local)** — Quick one-shot coding tasks, autonomous "set and forget" jobs, deep codebase analysis (`claw analyze`, `/map`, `/bughunter`), when you need speed over sophistication. Rust-native. See `references/kimi-reasoning-content-error.md` for the K2.6 `reasoning_content` 400 fix.

**Local (K2.6 35B)** — Privacy-sensitive work, offline coding, fallback when cloud quota is exhausted. All three harnesses can route to it via llama-swap.

### Routing Quick-Reference

| Command | What it does |
|---------|-------------|
| `claw glm` | claw-code → Z.AI GLM-5.1 (cloud) |
| `claw ds` | claw-code → DeepSeek V4 Flash (Hermes proxy, free) |
| `claw 35b` | claw-code → local K2.6 35B (llama-swap) |
| `claw 35bkimi` | claw-code → local Kimi distilled 35B |
| `opencode run '...'` | OpenCode one-shot (GLM-5.1 default) |
| `opencode` + `ultrawork` | OpenCode TUI → OmO multi-agent swarm |
| `hermes` | Hermes interactive (Kimi Vivace) |
| `hermes chat -q '...'` | Hermes one-shot |
| `hermes -s opencode "refactor auth"` | Hermes delegates to OpenCode skill

## Version Checking

See `references/claw-code-version-checking.md` for the update-check workflow, upstream noise profile, and filter commands.
