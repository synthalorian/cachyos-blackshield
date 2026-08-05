#!/bin/bash
# Hermes OAuth Keepalive
# Runs every 10 minutes to refresh short-lived OAuth tokens before they expire.
# Tokens last ~15 minutes, so a 10-minute interval keeps them fresh.

AUTH_FILE="$HOME/.hermes/auth.json"

if [ ! -f "$AUTH_FILE" ]; then
    exit 0
fi

# Check if nous token is expiring soon (less than 6 minutes)
TOKEN_EXPIRY=$(python3 -c "
import json, datetime
with open('$AUTH_FILE') as f:
    auth = json.load(f)
nous = auth.get('providers', {}).get('nous', {})
exp = nous.get('agent_key_expires_at') or nous.get('expires_at', '')
if exp:
    dt = datetime.datetime.fromisoformat(exp.replace('Z','+00:00'))
    now = datetime.datetime.now(datetime.timezone.utc)
    remaining = (dt - now).total_seconds()
    print(int(remaining))
else:
    print('-1')
" 2>/dev/null)

# If expiry check failed or token is fine, skip
if [ "$TOKEN_EXPIRY" = "" ] || [ "$TOKEN_EXPIRY" -lt 0 ]; then
    exit 0
fi

# Only refresh if less than 6 minutes remaining
if [ "$TOKEN_EXPIRY" -lt 360 ]; then
    # Lightweight ping to force token refresh
    hermes auth status nous > /dev/null 2>&1
    echo "[$(date '+%H:%M:%S')] OAuth keepalive: token had ${TOKEN_EXPIRY}s remaining — refreshed"
else
    echo "[$(date '+%H:%M:%S')] OAuth keepalive: token healthy (${TOKEN_EXPIRY}s remaining) — skipped"
fi
