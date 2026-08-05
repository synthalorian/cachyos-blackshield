# Session 2026-05-29 — Hermes Kimi 401 Diagnostic

## Symptom

Hermes returns 401 "API Key invalid or may have expired" when using Kimi K2.6.

## Diagnostic Steps

1. **Check proxy is running:** `ps aux | grep kimi-proxy`
   - Process found: `python3 /home/synth/.local/bin/kimi-proxy` running as user service

2. **Test proxy without auth:** `curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:8699/v1/models`
   - Returns `401` — proxy is reachable but rejecting (expected without key)

3. **Check key file exists and has content:**
   - `cat ~/.config/kimi-proxy/key.txt` → empty (0 bytes) — WRONG LOCATION
   - Actual key is in `~/.hermes/.env` as `KIMI_API_KEY=***   - Key length: 72 chars, prefix `sk-kimi-...`, valid format

4. **Test proxy WITH key:** `curl -H "Authorization: Bearer *** http://127.0.0.1:8699/v1/models`
   - Returns model list with `kimi-for-coding` → proxy + key are fine

5. **Check Hermes config:** `hermes config show | grep -i kimi`
   - `base_url: https://api.kimi.com/coding` — **DIRECT ENDPOINT, NOT PROXY**
   - This is the root cause: Hermes bypasses the proxy entirely

## Root Cause

Hermes `config.yaml` had `base_url: https://api.kimi.com/coding` (direct Kimi API) instead of `http://127.0.0.1:8699/v1` (local proxy). Kimi for Coding requires `claude-code/1.0` User-Agent; without the proxy, Hermes gets 401 even with a valid key.

## Fix

Change Hermes config:
```yaml
model:
  default: kimi-k2.6
  provider: kimi-coding
  base_url: http://127.0.0.1:8699/v1
```

Ensure `KIMI_API_KEY` is set in `~/.hermes/.env`.

## Key Insight

The proxy is a **transparent forwarder** — it only spoofs User-Agent. It does NOT inject or manage the API key. Both the proxy AND the key must be correctly configured. A 401 from the proxy means the key reached Kimi and Kimi rejected it (missing/invalid key). A 401 from direct endpoint means Kimi rejected the client identity (missing proxy).
