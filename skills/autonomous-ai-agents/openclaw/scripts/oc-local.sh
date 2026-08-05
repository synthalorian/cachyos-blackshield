#!/bin/bash
# oc-local — Switch OpenClaw to local model (Qwen 35B)
# Usage: oc-local [model_id]
# Default: synthclaw-35b
#
# Copy this to ~/.local/bin/oc-local and chmod +x
# Requires: ~/.openclaw/openclaw.json.local (template config)

set -e

MODEL="${1:-synthclaw-35b}"
CONFIG_DIR="${HOME}/.openclaw"
LOCAL_CONFIG="${CONFIG_DIR}/openclaw.json.local"
ACTIVE_CONFIG="${CONFIG_DIR}/openclaw.json"

if [[ ! -f "$LOCAL_CONFIG" ]]; then
    echo "Error: Local config not found at $LOCAL_CONFIG"
    echo "Create it first: cp ~/.openclaw/openclaw.json ~/.openclaw/openclaw.json.local"
    exit 1
fi

# If a specific model is requested, patch the local config on the fly
if [[ "$MODEL" != "synthclaw-35b" ]]; then
    python3 -c "
import json, sys
with open('${LOCAL_CONFIG}', 'r') as f:
    d = json.load(f)
d['agents']['defaults']['model']['primary'] = 'llama-swap/${MODEL}'
for a in d['agents']['list']:
    if a.get('default'):
        a['model']['primary'] = 'llama-swap/${MODEL}'
with open('${ACTIVE_CONFIG}', 'w') as f:
    json.dump(d, f, indent=2)
" 2>/dev/null || {
        echo "Error: Failed to set model '${MODEL}'"
        exit 1
    }
    echo "Switched to LOCAL model (${MODEL})"
else
    cp "$LOCAL_CONFIG" "$ACTIVE_CONFIG"
    echo "Switched to LOCAL model (${MODEL})"
fi

echo "   Primary: llama-swap/${MODEL}"
echo "   Fallbacks: none"
echo ""
echo "Restarting OpenClaw gateway..."

if systemctl --user is-active --quiet openclaw-gateway 2>/dev/null; then
    systemctl --user restart openclaw-gateway
    echo "Gateway restarted. New sessions will use ${MODEL}."
else
    echo "Gateway not running. Start with: systemctl --user start openclaw-gateway"
fi
