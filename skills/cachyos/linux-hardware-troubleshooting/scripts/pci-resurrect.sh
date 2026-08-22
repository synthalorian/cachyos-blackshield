#!/bin/sh
# PCI device resurrection — <date>
# Generic template for a PCI device that does not survive the kernel's
# normal boot-time enumeration and must be re-discovered via a bus rescan.
#
# Verifies by vendor/device ID so it never touches anything else.
# Undo: systemctl disable --now <service-name>.service
#
# Requirements: the device must be physically present and powered (not dead).
# If the device is dead (probe errors -114/-16, "failed to power on"),
# this script will log the failure and exit — it will not loop or hang.
#
# CUSTOMIZE BEFORE DEPLOYING:
#   - Replace <slot>, <VENDOR>, <DEVICE>, <BUS> for the target device.
#   - Replace <log-tag> with a meaningful logger tag (e.g. wifi-resurrect).
#   - Adjust the sleep/poll loop timeout to taste.
#   - If the device also needs a D3cold wake, leave the unbind/rebind in place
#     ONLY if you have verified it works in your service context (see pitfall
#     in SKILL.md). Otherwise remove it — the power-lock udev rule handles the
#     power-state correction on every PCI add event regardless.

set -e

# ---- device identity (CUSTOMIZE) ----
VENDOR=0x10ec        # from lspci -nn: [VVVV:DDDD]
DEVICE=0xb822        # from lspci -nn: [VVVV:DDDD]
BUS="pci"            # usually "pci"; other buses vary
SLOT="0000:04:00.0"  # hardcoded slot for this device
RESCAN="/sys/bus/${BUS}/rescan"
LOGTAG="pci-resurrect"

log() { logger -t "$LOGTAG" "$1"; }

dev_path="/sys/bus/${BUS}/devices/${SLOT}"

# ---- device already present: verify and exit ----
if [ -d "$dev_path" ]; then
    log "slot ${SLOT} already present, verifying vendor/device"
    ven=$(cat "${dev_path}/vendor" 2>/dev/null || echo "")
    dev=$(cat "${dev_path}/device" 2>/dev/null || echo "")
    if [ "$ven" = "$VENDOR" ] && [ "$dev" = "$DEVICE" ]; then
        log "slot ${SLOT} is ${VENDOR}:${DEVICE} — OK"
        exit 0
    else
        log "ERROR: slot ${SLOT} is not ${VENDOR}:${DEVICE} (got ${ven}:${dev}) — refusing to touch it"
        exit 1
    fi
fi

# ---- slot missing: trigger PCI rescan ----
log "slot ${SLOT} not found — triggering PCI bus rescan"
echo 1 > "$RESCAN" 2>/dev/null || {
    log "ERROR: cannot write to ${RESCAN} — PCI bus unavailable"
    exit 1
}

# ---- poll until the device appears (up to 60s by default) ----
for i in $(seq 1 12); do
    if [ -d "$dev_path" ]; then
        break
    fi
    sleep 5
done

if [ ! -d "$dev_path" ]; then
    log "ERROR: slot ${SLOT} did not reappear after rescan — device may be dead or BIOS-disabled"
    exit 1
fi

# ---- verify identity again ----
ven=$(cat "${dev_path}/vendor" 2>/dev/null || echo "")
dev=$(cat "${dev_path}/device" 2>/dev/null || echo "")
if [ "$ven" = "$VENDOR" ] && [ "$dev" = "$DEVICE" ]; then
    log "slot ${SLOT} (${VENDOR}:${DEVICE}) resurrected via PCI rescan"
    exit 0
else
    log "ERROR: slot ${SLOT} is not ${VENDOR}:${DEVICE} (got ${ven}:${dev}) — refusing to touch it"
    exit 1
fi
