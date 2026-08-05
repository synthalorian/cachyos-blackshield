# OpenAI Codex Pro: Auth Model & Tool Compatibility

## Codex Pro Is a ChatGPT Subscription, Not an API Plan

**Codex Pro ($100/mo)** is a **ChatGPT subscription tier** — it uses **OAuth (Sign in with ChatGPT)**, not an API key. Authentication works through:

- `codex login` → opens browser → OAuth flow → caches token in `~/.codex/auth.json`
- Token is refreshed automatically during active sessions
- Two auth methods: "Sign in with ChatGPT" (OAuth, uses Pro quota) or "Sign in with an API key" (standard API pricing, loses Pro perks)

Perks only available via ChatGPT OAuth:
- Higher rate limits (5x or 20x Plus baseline)
- Fast mode
- Cloud features (GitHub code review, Slack integration)
- GPT-5.3-Codex-Spark (research preview)
- Promo: 2x usage through May 31, 2026 (10x vs standard 5x)

## The OAuth Token Cannot Be Shared

The `~/.codex/auth.json` token is an **OpenAI ChatGPT OAuth token**, not an OpenAI API key. It is:

- Bound to the official Codex CLI's internal protocol
- Formatted for Codex-specific API endpoints
- Not compatible with the standard OpenAI REST API format

## Tool-by-Tool Auth Compatibility

| Tool | What Auth It Needs | Can Use Codex Pro? | Notes |
|:-----|:-------------------|:------------------|:------|
| **Codex CLI** (official) | ChatGPT OAuth or API key | ✅ Yes — OAuth uses Pro plan | This is where your $100 goes |
| **Codex IDE Extension** | ChatGPT OAuth or API key | ✅ Yes — same auth cache | Shares `~/.codex/auth.json` with CLI |
| **opencode** | OPENAI_API_KEY | ❌ No — needs standard API key | Can use an API key with standard pricing |
| **hermes** | Provider-configured API key | ❌ No — needs standard API key | Can use OpenAI provider with API key |
| **claw-code** | ANTHROPIC_API_KEY + OPENAI_API_KEY | ❌ No — different providers | Anthropic for Claude, OpenAI API key for compat layers |
| **ohmyopenagent** | OPENAI_API_KEY (via opencode) | ❌ No — same limitation as opencode | |

## What You Actually Get

If you buy Codex Pro ($100/mo):
- **Only the official Codex CLI, IDE extension, and web app** get Pro benefits
- Any tool that needs an OpenAI API key (opencode, hermes, etc.) must use a **separate OpenAI Platform API key** with **standard pay-per-token pricing**
- These two billing systems (ChatGPT subscriptions vs OpenAI Platform API) are completely separate

## API Key Option (Workaround)

The Codex CLI/tools **also support API key authentication**. But:
- You generate the key at [platform.openai.com/api-keys](https://platform.openai.com/api-keys) — not from your ChatGPT account
- Usage bills through your OpenAI Platform account at standard API rates
- **You lose Pro perks**: no fast mode, no cloud features, delayed model access
- The auth page explicitly says: "Features that rely on ChatGPT credits, such as fast mode, are available only when you sign in with ChatGPT"

## Recommended Multi-Tool Strategy

Given Codex Pro is walled to official tooling:

```
Primary CLI coding  → official Codex CLI (Pro subscription, OAuth auth)
Secondary coding    → Codex CLI (API key mode) or opencode (API key)
Heavy refactoring   → claw-code (Anthropic, separate billing)
General assistant   → hermes (whatever provider configured)
Kimi K2.x coding    → Kimi Code Allegro ($99/mo) or Kimi API (pay-per-token)
```

**Key principle:** Don't try to force Codex Pro into tools that can't use it. Either use the official Codex CLI for Pro benefits, or accept that API-key tools burn separate budget.

## Source

- developers.openai.com/codex/pricing — plan tiers, Pro details
- developers.openai.com/codex/auth — OAuth vs API key, token caching, credentials