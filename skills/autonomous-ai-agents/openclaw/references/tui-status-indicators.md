# OpenClaw TUI Status Indicators — Decoded

The OpenClaw TUI status bar can be misleading. This reference explains what each indicator actually means.

## Status Bar Format

```
∴ <activity> • <elapsed> | <connection>
```

Example:
```
∴ pondering.. • 27s | local ready
```

## Connection Status (Right Side)

| Text | Meaning | Trigger |
|------|---------|---------|
| `local ready` | TUI connected to gateway in **local mode** | `gateway.mode: "local"` in config |
| `local stopped` | TUI in local mode, gateway disconnected | Gateway not running |
| `connected` | TUI connected to **remote** gateway | `gateway.mode: "remote"` or not set |
| `disconnected` | TUI in remote mode, gateway disconnected | Gateway not running |
| `gateway connected` | Brief flash after reconnect | Connection restored |
| `gateway reconnected` | Brief flash after reconnect | Connection restored after disconnect |

**CRITICAL:** `local ready` does NOT mean "using a local model." It means the gateway is configured with `mode: "local"` (binds to loopback, no Tailscale). The actual model being used is shown separately in the detailed status line below.

## Activity Status (Left Side)

| Text | Meaning |
|------|---------|
| `idle` | No active run |
| `sending` | Message being sent to gateway |
| `waiting` | Message sent, waiting for first token — shows random phrases like "pondering...", "conjuring...", "noodling..." |
| `streaming` | First token received, streaming response |
| `error` | Run failed |
| `disconnected` | Lost connection during run |
| `auth` | Authentication flow in progress |

**CRITICAL:** The random phrases ("pondering", "conjuring", etc.) are just idle animations while `waiting`. They do NOT indicate which model is running or whether it's local vs cloud.

## Detailed Status Line (Below Main Status)

```
agent synthclaw (synthclaw) | session tui-xxx | kimi/kimi-k2.6 | think medium | tokens ?/200k
```

This line shows the **actual model** in use. Always check this line, not the connection status, to verify which model is running.

## Common Misconceptions

1. **"local ready" + "pondering" = using local model?** ❌ NO. "local ready" is gateway mode. "pondering" is just a waiting animation. Check the detailed line for `kimi/kimi-k2.6` vs `llama-swap/synthclaw-35b`.

2. **"streaming" only appears for cloud models?** ❌ NO. "streaming" appears when the first token arrives, regardless of whether it's from Kimi or llama-swap. If you see "pondering" for 30+ seconds, the model is just slow or stalled — not necessarily local.

3. **"This response is taking longer than expected" means it switched to local?** ❌ NO. This is the streaming watchdog (default ~30s). It fires when no token has been received within the timeout. The model is still the same — it's just slow or hung.

## Diagnosing "Hanging" Responses

If the TUI shows "pondering... • 60s | local ready" and the detailed line shows `kimi/kimi-k2.6`:

1. **Kimi is just slow** — K2.6 can take 20-60s for first token under load. Wait longer.
2. **Kimi auth failed** — The request may be failing with 401 but OpenClaw doesn't surface it clearly. Test directly:
   ```bash
   curl -H "Authorization: Bearer $KIMI_API_KEY" \
        https://api.kimi.com/coding/v1/chat/completions \
        -d '{"model":"kimi-k2.6","messages":[{"role":"user","content":"hi"}]}'
   ```
3. **Fallback chain is empty** — If you set `fallbacks: []`, OpenClaw won't switch to another model. It'll just wait forever (or until the streaming watchdog fires).
4. **Gateway log** — Check `journalctl --user -u openclaw-gateway -f` for actual errors.
