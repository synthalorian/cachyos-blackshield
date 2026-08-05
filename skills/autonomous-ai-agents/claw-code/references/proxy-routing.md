# Proxy Routing for Blocked Providers

## Problem: Kimi Direct API Rejects claw-code

Kimi for Coding maintains an agent whitelist. claw-code returns:

```
403 Forbidden (access_terminated_error): Kimi For Coding is currently only available for Coding Agents such as Kimi CLI, Claude Code, Roo Code, Kilo Code, etc.
```

## Solution: Route Through Nous/Hermes Proxy

The Hermes gateway runs a local OpenAI-compatible proxy at `http://127.0.0.1:8645/v1`. It authenticates via Nous OAuth and is treated as an approved client by upstream providers.

### Proxy Configuration

```bash
HERMES_PROXY_BASE="http://127.0.0.1:8645/v1"
HERMES_PROXY_KEY="hermes-proxy-auth"
```

### Model Slugs (Proxy vs Direct)

| Provider | Direct Slug | Proxy Slug |
|---|---|---|
| Kimi K2.6 | `kimi-k2.6` | `moonshotai/kimi-k2.6` |
| DeepSeek V4 Flash | `deepseek-v4-flash` | `deepseek/deepseek-v4-flash` |
| DeepSeek V4 Pro | `deepseek-v4-pro` | `deepseek/deepseek-v4-pro` |
| Minimax M2.5 | `minimax-m2.5` | `minimax/minimax-m2.5` |

### Wrapper Script Pattern (Kimi via Proxy)

```bash
        kimi)
            shift
            echo "🎹🦞 Cloud: $KIMI_MODEL via Nous proxy"
            export OPENAI_API_KEY="$HERMES_PROXY_KEY"
            export OPENAI_BASE_URL="$HERMES_PROXY_BASE"
            exec "$REAL_CLAW" --model "$KIMI_PROXY_MODEL" "$@"
            ;;
```

Where `KIMI_PROXY_MODEL="moonshotai/kimi-k2.6"`.

## Credit Requirements

The Nous proxy is NOT a free pass. Nous bills per-token:

- **Kimi K2.6**: ~$0.70/million tokens
- **DeepSeek V4 Flash**: ~$0.10/million tokens
- **DeepSeek V4 Pro**: ~$0.435/million tokens
- **Free models**: `openrouter/owl-alpha` (prompt=$0, completion=$0)

With $0 balance, Nous returns:
```
404 Not Found: Model 'X' requires available credits. Your account balance is too low...
```

Top up at https://portal.nousresearch.com.

## Verifying Proxy Health

```bash
# Check proxy is running
curl -s http://127.0.0.1:8645/v1/models | python3 -c "import sys,json; d=json.load(sys.stdin); print(len(d['data']), 'models available')"

# Check Nous auth status
hermes auth status nous

# List available models (filter by name)
curl -s http://127.0.0.1:8645/v1/models | python3 -c "
import sys, json
d = json.load(sys.stdin)
for m in d['data']:
    if 'kimi' in m['id'].lower():
        print(m['id'], 'prompt=', m.get('pricing',{}).get('prompt','?'))
"
```

## Proxy vs Direct Routing Decision Tree

```
Is the provider blocking non-whitelisted agents?
├── YES (Kimi, some others)
│   └── Route through Nous proxy at :8645
│       └── Do you have Nous credits?
│           ├── YES → Works
│           └── NO  → 404, add credits or use free model
└── NO (Z.AI, OpenRouter, local)
    └── Route direct to provider
```
