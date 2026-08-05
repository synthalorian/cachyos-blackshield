# API Key Debugging Workflow — Cloud Provider Auth Issues

When a cloud provider (Kimi, Z.AI, Anthropic, etc.) works in one tool but fails in another, use this systematic workflow to isolate the issue.

## Symptom: "Works in Tool A, fails in Tool B"

Example: Hermes successfully calls Kimi K2.6, but OpenClaw hangs with "pondering..." indefinitely.

## Step 1: Verify the Key Exists in Both Configs

```bash
# Check Tool A's config (Hermes)
python3 -c "
import json
with open('/home/synth/.hermes/auth.json') as f:
    d = json.load(f)
for cred in d.get('credential_pool', {}).get('kimi-coding', []):
    print('Source:', cred.get('source'))
    print('Fingerprint:', cred.get('secret_fingerprint'))
"

# Check Tool B's config (OpenClaw)
python3 -c "
import json
with open('/home/synth/.openclaw/openclaw.json') as f:
    d = json.load(f)
kimi = d['models']['providers']['kimi']
print('Key present:', bool(kimi.get('apiKey')))
print('Key prefix:', kimi.get('apiKey', '')[:15] if kimi.get('apiKey') else 'NONE')
"
```

## Step 2: Extract the Actual Key Value

Credential files mask keys in tool output. Use direct file reads:

```bash
# From Hermes .env (where Hermes loads its keys)
grep KIMI_API_KEY /home/synth/.hermes/.env | cut -d= -f2 > /tmp/key_from_hermes.txt

# From OpenClaw config
python3 -c "
import json
with open('/home/synth/.openclaw/openclaw.json') as f:
    d = json.load(f)
with open('/tmp/key_from_openclaw.txt', 'w') as f:
    f.write(d['models']['providers']['kimi']['apiKey'])
"

# Compare fingerprints
python3 -c "
import hashlib
for name in ['hermes', 'openclaw']:
    with open(f'/tmp/key_from_{name}.txt', 'r') as f:
        key = f.read().strip()
    fp = hashlib.sha256(key.encode()).hexdigest()
    print(f'{name}: prefix={key[:15]}, fingerprint={fp[:16]}')
"
```

## Step 3: Test the Key Directly Against the Provider

Use Python (not curl) to avoid shell escaping issues with long keys:

```python
import urllib.request
import json

with open('/tmp/key_from_openclaw.txt', 'r') as f:
    api_key = f.read().strip()

# Test with the EXACT endpoint and headers the tool uses
req = urllib.request.Request(
    'https://api.kimi.com/coding/v1/messages',  # or whatever endpoint
    data=json.dumps({
        'model': 'kimi-k2.6',
        'max_tokens': 10,
        'messages': [{'role': 'user', 'content': 'Say hello'}]
    }).encode(),
    headers={
        'Authorization': f'Bearer {api_key}',
        'Content-Type': 'application/json',
        'User-Agent': 'hermes-agent/1.0',  # match the tool's UA
        'anthropic-version': '2023-06-01'   # match the tool's headers
    },
    method='POST'
)

try:
    with urllib.request.urlopen(req, timeout=30) as resp:
        print('Status:', resp.status)
        print('Response:', resp.read(200).decode())
except urllib.error.HTTPError as e:
    print('HTTP Error:', e.code)
    print('Body:', e.read(200).decode())
except Exception as e:
    print('Error:', e)
```

## Step 4: Compare Endpoint Behavior

Different tools may use different endpoints for the same provider:

| Endpoint | Used By | Notes |
|----------|---------|-------|
| `api.kimi.com/coding` | Hermes, openclaw | Anthropic-messages API |
| `api.kimi.com/coding/v1` | opencode | OpenAI-compatible |
| `api.kimi.com/v1` | claw-code (proxy) | Proxied |
| `api.moonshot.ai/v1` | Hermes (legacy) | OpenAI-compatible |

A key valid on one endpoint may fail on another. Always test the exact endpoint.

## Step 5: Check for Literal `***` in Configs

Tool output masking can corrupt config files if copy-pasted from masked terminal output:

```bash
# Check if the config contains literal asterisks
grep -n '\*\*\*' ~/.openclaw/openclaw.json
```

If found, the key was copy-pasted from masked output. Replace with the actual key.

## Step 6: Verify Gateway Restart

After fixing the key, restart the gateway:

```bash
systemctl --user restart openclaw-gateway
# Wait 2-3 seconds for startup
sleep 3
systemctl --user status openclaw-gateway --no-pager
```

## Common Failure Modes

| Symptom | Root Cause | Fix |
|---------|-----------|-----|
| "pondering..." forever | Invalid key + empty fallbacks | Fix key or add fallback |
| 401 on direct test, 200 on Hermes | Different endpoints or headers | Match exact endpoint + headers |
| Key prefix matches but auth fails | Key expired or revoked | Generate new key |
| Fingerprint mismatch | Different keys in different tools | Sync keys across configs |
| "resource_not_found" (404) | Wrong model ID for endpoint | Use correct model slug |

## Shell Escaping Warning

**Never use `curl` with inline key variables in bash.** Shell escaping breaks on long API keys with special characters. Always:
1. Write key to a temp file
2. Use Python's `urllib` for testing
3. Or use `curl -H @headers_file` with headers in a file
