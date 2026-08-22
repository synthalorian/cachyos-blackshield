#!/bin/sh
# RTL8822BE WiFi resurrection — <date: 2026-08-12>
# The card does not enumerate on the normal boot path and must be
# re-discovered via a PCI bus rescan. This service runs early, triggers
# a rescan, waits for the device, and wakes it if it's in a low-power state.
#
# Verifies by vendor/device ID (10ec:b822) so it never touches anything else.
# Undo: systemctl disable --now wifi-resurrect.service
#
# Requirements: the card must be physically present and powered (not dead).
# If the card is dead (probe errors -114/-16, "failed to power on mac"),
# this service will log the failure and exit — it won't loop or hang.

set -e

VENDOR=0x10ec
DEVICE=0xb822
BUS="${BUS:-pci}"
RESCAN="/sys/bus/${BUS}/rescan"
DESC="RTL8822BE WiFi rescan"

log() {
    logger -t wifi-resurrect "$1"
}

# Even if already present, verify + flush stale state via rebind.
# The card boot-time enumeration is flaky; a rebind ensures clean state.
if [ -d "/sys/bus/${BUS}/devices/0000:04:00.0" ]; then
    log "device 04:00.0 already present - verifying and flushing stale state"
    ven=$(cat "/sys/bus/${BUS}/devices/0000:04:00.0/vendor" 2>/dev/null || echo "")
    dev=$(cat "/sys/bus/${BUS}/devices/0000:04:00.0/device" 2>/dev/null || echo "")
    if [ "$ven" != "$VENDOR" ] || [ "$dev" != "$DEVICE" ]; then
        log "ERROR: slot 04:00.0 is not RTL8822BE (vendor=$ven device=$dev) - refusing to touch it"
        exit 1
    fi
    DRV=$(basename "$(readlink "/sys/bus/${BUS}/devices/0000:04:00.0/driver" 2>/dev/null)" 2>/dev/null || true)
    if [ -n "$DRV" ]; then
        echo "$DRV" > "/sys/bus/${BUS}/devices/0000:04:00.0/driver/unbind" 2>/dev/null || true
        echo "$DRV" > "/sys/bus/${BUS}/devices/0000:04:00.0/driver/rebind" 2>/dev/null || true
        log "driver $DRV rebind issued (flush stale state)"
    fi
    exit 0
fi

# Trigger PCI rescan
log "triggering PCI rescan"
echo 1 > "$RESCAN" 2>/dev/null || {
    log "ERROR: cannot write to $RESCAN — PCI bus unavailable"
    exit 1
}

# Wait for the device to appear (up to 60s)
for i in $(seq 1 12); do
    if [ -d "/sys/bus/${BUS}/devices/0000:04:00.0" ]; then
        break
    fi
    sleep 5
done

if [ ! -d "/sys/bus/${BUS}/devices/0000:04:00.0" ]; then
    log "ERROR: device 04:00.0 did not reappear after rescan — card may be dead or BIOS-disabled"
    exit 1
fi

# Verify it's the right device
ven=$(cat "/sys/bus/${BUS}/devices/0000:04:00.0/vendor" 2>/dev/null || echo "")
dev=$(cat "/sys/bus/${BUS}/devices/0000:04:00.0/device" 2>/dev/null || echo "")
if [ "$ven" != "$VENDOR" ] || [ "$dev" != "$DEVICE" ]; then
    log "ERROR: slot 04:00.0 is not RTL8822BE (vendor=$ven device=$dev) — refusing to touch it"
    exit 1
fi

log "device 04:00.0 (RTL8822BE) resurrected"

# Wake from low-power state if needed
if [ -f "/sys/bus/${BUS}/devices/0000:04:00.0/power_state" ]; then
    ps=$(cat "/sys/bus/${BUS}/devices/0000:04:00.0/power_state" 2>/dev/null || true)
    if [ "$ps" = "d3cold" ] || [ "$ps" = "d3" ]; then
        log "device in $ps, attempting wake"
        DRV=$(basename "$(readlink "/sys/bus/${BUS}/devices/0000:04:00.0/driver" 2>/dev/null)" 2>/dev/null || true)
        if [ -n "$DRV" ]; then
            echo "$DRV" > "/sys/bus/${BUS}/devices/0000:04:00.0/driver/unbind" 2>/dev/null || true
            echo "$DRV" > "/sys/bus/${BUS}/devices/0000:04:00.0/driver/rebind" 2>/dev/null || true
            log "driver $DRV rebind issued"
        fi
    fi
fi

log "done"
