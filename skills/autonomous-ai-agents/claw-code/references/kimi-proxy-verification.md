# Kimi Proxy Verification Script

Quick diagnostic to verify the Kimi proxy is running and the key is valid.

## Check proxy process

```bash
ps aux | grep -i kimi
```

Should show `python3 /home/synth/.local/bin/kimi-proxy` running.

## Test proxy directly (scripted verification)

Use the verification script for a clean test that avoids shell masking issues:
```bash
python3 ~/.hermes/skills/autonomous-ai-agents/claw-code/scripts/verify-kimi-proxy.py
```

Or manually with curl:
```bash
# Read key from env file and test
bash -c 'source ~/.config/claw/kimi.env 2>/dev/null || source ~/.hermes/.env 2>/dev/null; curl -s http://127.0.0.1:8699/v1/models -H "Authorization: Bearer $KIMI_API_KEY" | head -c 200'
```

Expected: `{"data":[{"id":"kimi-for-coding"...`

If 401: key is missing, invalid, or expired. Check:
- `~/.config/claw/kimi.env` exists and has `KIMI_API_KEY="sk-k..."`
- `~/.hermes/.env` exists and has `KIMI_API_KEY=sk-k...`
- Key hasn't expired (Kimi keys are time-limited)

If connection refused: proxy is not running. Start it:
```bash
python3 /home/synth/.local/bin/kimi-proxy &
```

## Check wrapper script for literal `***` bug

```bash
python3 -c "
with open('/home/synth/.local/bin/claw') as f:
    for i, line in enumerate(f, 1):
        if 'OPENAI_API_KEY' in line:
            print(f'{i}: {line.rstrip()}')
"
```

All lines should show `$_KIMI_KEY` or similar variable reference.
If any line shows literal `***` (not a variable), the wrapper is broken.

## Check Hermes config (separate issue)

If Hermes (not claw) gets 401, check:
```bash
hermes config show | grep -i base_url
```

If it shows `https://api.kimi.com/coding` instead of `http://127.0.0.1:8699/v1`,
Hermes is bypassing the proxy. Update `base_url` in `~/.hermes/config.yaml`.
