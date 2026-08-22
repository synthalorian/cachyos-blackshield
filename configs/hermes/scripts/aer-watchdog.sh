#!/usr/bin/env bash
# AER storm watchdog — synthesis
# Silent when healthy (empty stdout = no message). On burst: notify + report.
# Tracks TOTAL_ERR_COR across all PCIe devices; flags delta > THRESHOLD per tick.
set -u
STATE="${XDG_CACHE_HOME:-$HOME/.cache}/aer-watchdog.state"
THRESHOLD=50

current=$(cat /sys/bus/pci/devices/*/aer_dev_correctable 2>/dev/null | awk '/^TOTAL_ERR_COR/ {s+=$2} END {print s+0}')
previous=$(cat "$STATE" 2>/dev/null || echo "$current")
echo "$current" > "$STATE"

delta=$((current - previous))
if [ "$delta" -gt "$THRESHOLD" ]; then
    ports=$(for f in /sys/bus/pci/devices/*/aer_dev_correctable; do
        t=$(awk '/^TOTAL_ERR_COR/ {print $2}' "$f")
        [ "${t:-0}" -gt 0 ] && echo "$(dirname "$f" | grep -oP '[^/]+$')=$t"
    done | tr '\n' ' ')
    # Local desktop notification (best-effort)
    DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/1000/bus" \
        notify-send -u critical "⚡ PCIe AER storm" "+${delta} correctable errors since last check: ${ports}" 2>/dev/null || true
    echo "⚡ PCIe AER storm detected on synthesis: +${delta} correctable errors in 5 min (lifetime: ${ports}). WiFi card is at 04:00.0 — check which port is climbing. Mask state: $(setpci -s 00:1c.6 ECAP_AER+0x14.l 2>/dev/null || echo 'needs sudo')"
fi
exit 0
