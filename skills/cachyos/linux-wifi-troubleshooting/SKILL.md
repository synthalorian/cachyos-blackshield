---
name: linux-wifi-troubleshooting
description: >-
  Fix WiFi dropouts and unstable links on Linux.
tags: [linux, wifi, network, troubleshooting, gaming]
---

# Linux WiFi Troubleshooting

## Trigger Conditions
- WiFi disconnecting during use (especially gaming)
- Link flaky — drops and reconnects autonomously
- Signal quality marginal and causing real-time activity issues
- NetworkManager stuck in "connecting (configuring)" state
- Known problematic cards: RTL8822BE, RTL8822CE, RTL8812AE

## Step 1 — Assess Signal Quality

```bash
iw dev wlan0 link
iw dev wlan0 station dump
```

Signal thresholds:
- **-50 to -60 dBm**: excellent
- **-60 to -65 dBm**: good — stable
- **-65 to -70 dBm**: borderline — may drop under load
- **-70 to -75 dBm**: poor — expect disconnects
- **Below -75 dBm**: unusable for real-time activity

Also check RX/TX bitrates and signal variance (wide variance = unstable).

## Step 2 — Check for Disconnect Events

```bash
journalctl -k --since "30 min ago" | grep -iE "deauth|wlan0.*disconnect|rtw88|rtl8822"
```

Watch for:
- `deauthenticating by local choice (Reason: 3=DEAUTH_LEAVING)` — card dropped itself
- Repeated deauth/reassoc cycles — unstable link or roaming issue

## Step 3 — Verify Driver Power Management

For RTL8822BE and similar Realtek cards, power management is the #1 cause of drops.

```bash
# Kernel cmdline
cat /proc/cmdline | tr ' ' '\n' | grep -i aspm
# Should show: pcie_aspm=off

# Module parameters
for mod in rtw88_pci rtw88_core rtw88_8822be; do
  echo "=== $mod ==="
  find /sys/module/$mod/parameters -type f 2>/dev/null | while read f; do
    echo "$f: $(cat $f 2>/dev/null)"
  done
done
```

Expected for stable operation:
- `rtw88_pci.disable_aspm`: Y
- `rtw88_core.disable_lps_deep`: Y
- Kernel cmdline: `pcie_aspm=off`

See `references/rtl8822be-known-issues.md` for full module stack and details.

## Step 4 — Check Available Networks and Bands

```bash
nmcli dev wifi list
```

Look for the same SSID on both 2.4GHz and 5GHz, and compare signal strength.

Decision:
- 2.4GHz significantly better signal → switch to 2.4GHz
- 5GHz clean and strong → keep 5GHz
- Both marginal → consider USB tether or Ethernet

## Step 5 — Switch Bands (if needed)

```bash
# Force 2.4GHz (more stable, less throughput)
nmcli connection modify "SSID" 802-11-wireless.band bg

# Force 5GHz (faster, more interference-prone)
nmcli connection modify "SSID" 802-11-wireless.band a

# Reconnect
nmcli connection up "SSID"
```

**Pitfall**: Pinning `802-11-wireless.bssid` to a specific AP's MAC can break association if the card's scan doesn't see it. Clear the BSSID and let NM pick. See `references/networkmanager-state-machine.md`.

## Step 6 — NetworkManager State Recovery

When NM is stuck in "connecting (configuring)":

```bash
nmcli dev disconnect wlan0
nmcli connection modify "SSID" 802-11-wireless.bssid ""
ip link set wlan0 down && ip link set wlan0 up
nmcli connection up "SSID"
```

**Pitfalls**:
- **MAC address randomization**: If `ip link show wlan0` shows a MAC different from `permaddr`, the AP won't recognize the card. Reset to permaddr.
- **`nmcli dev wifi rescan` can hang**: On buggy cards (especially RTL8822BE), the scan can deadlock. Run in background or skip.
- **Deleting a NM profile loses the stored password**: The passphrase is in the profile, not wpa_supplicant. Don't delete unless you have the password.

See `references/networkmanager-state-machine.md` for full state machine details.

## Step 7 — Hardening (post-connection)

1. **TX power cap** — lower transmit power to reduce self-interference
2. **Disable WiFi powersave** — stop the card from sleeping between packets: `nmcli connection modify "SSID" 802-11-wireless.powersave 3` (value 3 = disable; 1 = always on, 2 = driver default). Note: for RTL8822BE this is secondary to the driver-level parameters in `references/rtl8822be-known-issues.md` — NM powersave is a belt-and-suspenders layer, not the primary fix.
3. **Reconnect watchdog** — script that re-associates on link drop (see below)
4. **Gamescope buffer** — run games under gamescope with larger buffer to absorb micro-disconnects

### Reconnect Watchdog

```bash
#!/bin/bash
# /usr/local/bin/wifi-watchdog.sh
INTERFACE="wlan0"
SSID="The Grid"
while true; do
    if ! iw dev $INTERFACE link | grep -q "Connected to"; then
        nmcli dev disconnect $INTERFACE
        sleep 2
        nmcli connection up "$SSID"
    fi
    sleep 5
done
```

Run as a systemd service or background process during gaming sessions.

## Step 8 — Last Resort: USB Tether

When WiFi cannot be stabilized:
1. Enable USB tethering on phone
2. Connect via USB
3. `sudo ip link set usb0 up && sudo dhclient usb0`
4. Tethered connection is hardwired and won't drop

## Pitfalls

- **BSSID pinning can break association** — clear it and let NM pick
- **MAC randomization breaks AP association** — reset to permaddr before reconnecting
- **`nmcli dev wifi rescan` can hang on buggy cards** — don't block on it
- **Don't `pkill -f <game>`** — pattern matching can kill the agent session; use exact PIDs
- **Don't retry the same NM operation repeatedly** — if `nmcli connection up` hangs, disconnect, reset interface, and try once more
- **Deleting a NM profile loses the stored password** — have the passphrase ready before deleting

## References

- `references/rtl8822be-known-issues.md` — RTL8822BE module stack, verified parameters, and storm-proofing checklist
- `references/networkmanager-state-machine.md` — NM state machine internals, state transitions, and recovery paths
