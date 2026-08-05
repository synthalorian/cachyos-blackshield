# Session: claw-code DashScope Routing Bug (2026-05-29)

## Problem

User ran `claw analyze ~/projects/chronos-engine --depth full` and got:

```
🎹🦞 Cloud: kimi/kimi-k2.6 via Kimi direct
[error-kind: unknown]
error: missing DashScope credentials; export DASHSCOPE_API_KEY before calling the DashScope API
```

The wrapper was configured to use a local Kimi proxy on `127.0.0.1:8699`, but `claw` routed to DashScope instead.

## Root Cause

`claw` uses **prefix-based provider routing** that cannot be overridden by `OPENAI_BASE_URL` alone:

- `--model kimi/kimi-k2.6` → routes to **DashScope** (Alibaba), requires `DASHSCOPE_API_KEY`
- `--model openai/kimi-k2.6` → routes to **OpenAI-compatible** backend, respects `OPENAI_BASE_URL`

The wrapper script was passing `--model kimi/kimi-k2.6` while setting `OPENAI_BASE_URL=http://127.0.0.1:8699/v1`. `claw` ignored the base URL because the `kimi/` prefix hard-routes to DashScope.

## Debugging Path

1. **Confirmed proxy is running** — `kimi-proxy.service` active on `:8699`, curl test with key works
2. **Confirmed key is valid** — direct curl to proxy returns 200 with correct response
3. **Tested claw directly** — `claw --model openai/kimi-k2.6` with env vars works
4. **Identified prefix routing** — `strings ~/claw-code/rust/target/release/claw | grep -i dashscope` shows hardcoded provider backends
5. **Fixed wrapper script** — changed model prefix from `kimi/` to `openai/` in both the `kimi)` case and the default case

## Fix Applied

```bash
# BEFORE (broken — routes to DashScope)
exec "$REAL_CLAW" --model "$KIMI_MODEL" "$@"
# where KIMI_MODEL="kimi/kimi-k2.6"

# AFTER (fixed — routes through OpenAI-compatible backend)
_KIMI_KEY="$KIMI_API_KEY"
env OPENAI_API_KEY=*** "$REAL_CLAW" --model "openai/$KIMI_PROXY_MODEL" "$@"
# where KIMI_PROXY_MODEL="kimi-k2.6"
```

Additional fix: used `env` instead of `export` to prevent bash from expanding `$` characters inside the API key value.

## Key Lesson

When `claw` reports "missing DashScope credentials" despite having set `OPENAI_API_KEY` and `OPENAI_BASE_URL`, the model prefix is wrong. Change `kimi/` → `openai/` (or `qwen/` → `openai/`) to route through the OpenAI-compatible backend.

## Verification

```bash
cd ~/projects/chronos-engine && claw prompt "say hi"
# Expected: success, Kimi K2.6 response via local proxy
```
