# Session: claw wrapper passes literal `***` instead of key value

**Date:** 2026-05-29
**Symptom:** `claw` (default, no args) fails with 401 "The API Key appears to be invalid"
**Root cause:** Line 140 in `~/.local/bin/claw` had `env OPENAI_API_KEY=***` (missing `$_KIMI_KEY` reference)

## Diagnosis steps

1. Verified proxy is running: `ps aux | grep kimi` → proxy process active on PID 1396
2. Tested proxy directly with curl + key from `~/.hermes/.env` → works, returns model list
3. Checked Hermes config → `base_url` points to direct Kimi, not proxy (separate issue, not the cause)
4. Examined wrapper script → found line 140: `env OPENAI_API_KEY=***` (literal string, not variable)
5. Line 84 (explicit `claw kimi`) was correct: `env OPENAI_API_KEY="$_KIMI_KEY"`

## Why this happened

The wrapper script was likely edited with a tool that masks secrets. When the key value is masked as `***` in tool output, a copy-paste or patch operation can accidentally write the literal string `***` into the file instead of the variable reference. The bash script then passes `***` as the actual API key to claw-code.

## Fix

```bash
# Before (broken):
env OPENAI_API_KEY=*** "$REAL_CLAW" --model "openai/$KIMI_PROXY_MODEL" "$@"

# After (fixed):
env OPENAI_API_KEY="$_KIMI_KEY" "$REAL_CLAW" --model "openai/$KIMI_PROXY_MODEL" "$@"
```

## Verification

```bash
# Check the actual bytes in the wrapper
python3 -c "
with open('/home/synth/.local/bin/claw') as f:
    for i, line in enumerate(f, 1):
        if 'OPENAI_API_KEY' in line:
            print(f'{i}: {line.rstrip()}')
"

# Should show: env OPENAI_API_KEY=*** ...
# NOT:        env OPENAI_API_KEY=*** ...
```

## Related

- `references/session-2026-05-29-dashscope-routing.md` — similar prefix routing issue
- `references/kimi-coding-plan.md` — full Kimi provider setup
