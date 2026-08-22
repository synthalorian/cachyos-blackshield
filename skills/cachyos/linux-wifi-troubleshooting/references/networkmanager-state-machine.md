# NetworkManager State Machine — Recovery Paths

## States (as observed on this system)

```
  disconnected
      |
  prepare  — NM setting up the connection (hw addr, secrets check)
      |
  config   — config phase (bgscan, key_mgmt, auth_alg, psk)
      |
  need-auth — auth required (secrets missing or WPA negotiation)
      |
  connecting (configuring) — active association attempt
      |
  activated — connected
```

## State Transitions Seen

### Normal connect
```
disconnected → prepare → config → need-auth → prepare → config → connecting → activated
```

### Association failure (self-disconnect)
```
connecting (configuring) → need-auth
supplicant: interface_disabled → disconnected → inactive
NM: disconnected during association, retrying connection
```

### NM stuck in "connecting (configuring)"
NM believes it's activating, but the supplicant can't complete association. Common causes:
- MAC address was randomized — AP doesn't recognize the card
- BSSID pinned to an AP the card can't see in scan
- Band mismatch — card trying 5GHz when only 2.4GHz is reachable
- WPA negotiation mismatch (WPA3 SAE on WPA2-only AP)

## Recovery Sequences

### Standard recovery (MAC correct, BSOD cleared)
```bash
nmcli dev disconnect wlan0
nmcli connection modify "SSID" 802-11-wireless.bssid ""
ip link set wlan0 down && ip link set wlan0 up
nmcli connection up "SSID"
```

### MAC was randomized (most common failure mode)
```bash
nmcli dev disconnect wlan0
ip link set wlan0 down
ip link set wlan0 address <permaddr>   # from `ip link show wlan0 | grep permaddr`
ip link set wlan0 up
nmcli connection up "SSID"
```

The AP won't associate with a different MAC — always verify MAC before reconnecting.

### BSSID was pinned and breaks association
```bash
nmcli connection modify "SSID" 802-11-wireless.bssid ""
nmcli connection up "SSID"
```

Clear the BSSID and let NM's scan find the AP. Pinning to a specific AP MAC works only when the card's scan can see it — on buggy cards this often fails.

### Profile deletion (last resort — requires password)
```bash
nmcli connection delete "SSID"
nmcli dev wifi connect "SSID" password <passphrase> band bg
```

**Warning**: Deleting a NM profile removes the stored passphrase. The password is NOT cached in wpa_supplicant separately. Have the passphrase ready before deleting.

### NM hangs on `connection up` (don't retry)
If `nmcli connection up "SSID"` times out (15-30s), do NOT retry:
```bash
nmcli dev disconnect wlan0
ip link set wlan0 down && ip link set wlan0 up
nmcli connection up "SSID"   # try once more
```

If it still hangs, the card is in a bad state. Reset wpa_supplicant and the interface:
```bash
nmcli dev disconnect wlan0
kill $(pgrep -f "wpa_supplicant.*wlan0") 2>/dev/null
ip link set wlan0 down && ip link set wlan0 up
nmcli connection up "SSID"
```

### `nmcli dev wifi rescan` hangs
On RTL8822BE and similar cards, the scan can deadlock. Run in background:
```bash
nmcli dev wifi rescan &
# or skip it — NM can often associate without a fresh scan if it has the profile
```

## Band Selection

```bash
# Force 2.4GHz
nmcli connection modify "SSID" 802-11-wireless.band bg

# Force 5GHz
nmcli connection modify "SSID" 802-11-wireless.band a

# Clear band restriction (auto)
nmcli connection modify "SSID" 802-11-wireless.band ""
```

After changing band, reconnect:
```bash
nmcli connection up "SSID"
```

If NM refuses (network not found), clear BSSID first — the band change can break BSSID lookup.

## WPA Negotiation

If association fails during config phase and the log shows WPA negotiation issues:

```bash
nmcli connection modify "SSID" \
  802-11-wireless-security.key-mgmt wpa-psk \
  802-11-wireless-security.auth-alg open
```

Force WPA-PSK (not SAE/WPA3) and open auth algorithm. Some APs advertise WPA3 but don't support it properly — forcing WPA2-PSK avoids the negotiation failure.

## Pitfalls

- **BSSID pinning + band change = broken association**: The BSSID you pinned is on a different band than what you're forcing. Clear BSSID before changing band.
- **NM "success" + `iw link` shows no connection**: NM's D-Bus state can be "activated" while the card never actually associated. Always verify with `iw dev wlan0 link` after NM says success.
- **Profile deletion loses password**: NM stores the passphrase in the connection profile. Deleting it wipes the password. Have it ready.
- **`nmcli dev wifi list` can show the AP but NM can't associate**: Signal quality, band mismatch, or MAC mismatch. Verify with `iw dev wlan0 station dump`.
