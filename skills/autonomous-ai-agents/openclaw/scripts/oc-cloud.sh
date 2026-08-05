#!/bin/bash
# oc-cloud — Switch OpenClaw to cloud model (Kimi K2.6)
# Usage: oc-cloud
#
# Copy this to ~/.local/bin/oc-cloud and chmod +x
# Requires: ~/.openclaw/openclaw.json.cloud (template config)

set -e

CONFIG_DIR="${HOME}/.openclaw"
CLOUD_CONFIG="${CONFIG_DIR}/openclaw.json.cloud"
ACTIVE_CONFIG="${CONFIG_DIR}/openclaw.json"

if [[ ! -f "$CLOUD_CONFIG" ]]; then
    echo "Error: Cloud config not found at $CLOUD_CONFIG"
    echo "Create it first: cp ~/.openclaw/openclaw.json ~/.openclaw/openclaw.json.cloud"
    exit 1
fi

cp "$CLOUD_CONFIG" "$ACTIVE_CONFIG"

echo "Switched to CLOUD model (Kimi K2.6)"
echo "   Primary: kimi/kimi-k2.6"
echo "   Fallbacks: none"
echo ""
echo "Restarting OpenClaw gateway..."

if systemctl --user is-active --quiet openclaw-gateway 2>/dev/null; then
    systemctl --user restart openclaw-gateway
    echo "Gateway restarted. New sessions will use Kimi K2.6."
else
    echo "Gateway not running. Start with: systemctl --user start openclaw-gateway"
fi
