#!/usr/bin/env bash
# AER storm watchdog — run on a schedule (cron/systemd timer/Hermes cronjob).
# Silent when healthy (empty stdout). On burst: desktop notification + report.
# Tracks TOTAL_ERR_COR across ALL PCIe devices; flags delta > THRESHOLD per tick.
# State file keeps the previous sum; first run records the baseline and exits quiet.
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
    # Local desktop notification (best-effort; adjust UID/path for the target box)
    DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/1000/bus" \
        notify-send -u critical "⚡ PCIe AER storm" "+${delta} correctable errors: ${ports}" 2>/dev/null || true
    echo "⚡ PCIe AER storm: +${delta} correctable errors since last tick (lifetime: ${ports}). Map the climbing port: lspci -tv | grep -B1 <slot>."
fi
exit 0
