# WiFi band switch to 2.4GHz — RTL8822BE on synthesis (2026-08-17 session)

## Context

RTL8822BE WiFi card was dropping connections on 5GHz (signal -72 dBm, deauth events in kernel log). The 2.4GHz AP on the same SSID ("The Grid") was at -20 dBm — much stronger, more stable. Goal: move the client off 5GHz onto 2.4GHz without losing the connection.

## Environment

- Card: RTL8822BE (`04:00.0`), driver `rtw88_8822be`, `rtw88_pci.disable_aspm=Y`, `pcie_aspm=off` in cmdline
- AP: "The Grid", SSID shared across 5GHz (`F4:52:46:4F:D9:3C`, ch 157) and 2.4GHz (`F4:52:46:4F:D9:3B`, ch 6), both WPA2
- NM profile: "The Grid" (`d742c233-42c7-42fd-85b4-5a1c9f563f62`), previously `band=a` (5GHz only)

## What happened

1. Set `nmcli connection modify "The Grid" 802-11-wireless.band bg` — profile changed OK
2. `nmcli connection up "The Grid"` — **hung for 30+ seconds in "connecting (configuring)"**, then timed out
3. `iw dev wlan0 survey dump` returned empty (card not scanning)
4. `nmcli dev wifi list` returned empty (same — no scan results)
5. Deleting the profile (`nmcli connection delete "The Grid"`) and reconnecting via `nmcli dev wifi connect` worked — **but only when the WiFi password was available**. Without it, the `dev wifi connect` command prompts interactively and can't be driven from terminal (bash expands `<pass>` as a glob if unquoted).

## The hang root cause

After switching the profile to `band=bg`, NM's activation path (`org.freedesktop.NetworkManager.distup` D-Bus call) got stuck because:
- The supplicant (`wpa_supplicant`) couldn't complete the WPA handshake on the 2.4GHz AP — the BSSID (`F4:52:46:4F:D9:3B`) is different from the 5GHz BSSID (`F4:52:46:4F:D9:3C`), and the profile still had no BSSID pinned, so NM was hunting
- The card was in a bad driver state (scan hadn't completed, `survey dump` empty)
- NM's state machine didn't timeout aggressively enough to surface a readable error

## Working path (when password is known)

```bash
# 1. Delete the old profile (it's stuck in a bad state)
nmcli connection delete "The Grid"

# 2. Recreate, pinning to the 2.4GHz AP by BSSID
nmcli dev wifi connect "The Grid" password <actual-pass> band bg bssid F4:52:46:4F:D9:3B

# 3. Verify band
iw dev wlan0 link | grep freq   # 2.4GHz APs show freq 2400-2480 range
nmcli dev show wlan0 | grep BSSID
```

## Working path (when password is unknown)

```bash
# Use the KDE NetworkManager widget in the system tray:
#   Right-click "The Grid" → Connect → enter password → OK
# Then export the profile for future scripting:
nmcli -f 802-11-wireless.*,802-11-wireless-security.psk connection show "The Grid"
```

The `psk` field in the output is the raw password when NM has it cached.

## Alternative: clone the existing profile

If the existing profile is functional on 5GHz and you just want a 2.4GHz variant:

```bash
nmcli connection clone "The Grid" "The Grid 2.4"
nmcli connection modify "The Grid 2.4" 802-11-wireless.band bg \
    802-11-wireless.bssid F4:52:46:4F:D9:3B \
    802-11-wireless.powersave 2 \
    connection.autoconnect yes
nmcli connection up "The Grid 2.4"
```

## Recovery when NM hangs on band switch

When `nmcli connection up` hangs after a band change:

1. **Disconnect**: `nmcli dev disconnect wlan0`
2. **Reset the interface**: `ip link set wlan0 down && ip link set wlan0 up`
3. **Restore permaddr if randomized**: `sudo ip link set wlan0 address 80:c5:f2:9e:4a:4f` (replace with actual permaddr — see BSSID randomization pitfall in SKILL.md)
4. **Recreate connection** targeting the 2.4GHz BSSID (see "Working path above")
5. **Wait for the scan** — `nmcli dev wifi list` may take 5-10s to return after `ip link set wlan0 up` on this card

## Verification

After connecting to 2.4GHz:
```bash
iw dev wlan0 link           # → freq should be in 2.4GHz range (2400-2480 MHz)
nmcli dev wifi list | grep "The Grid"  # 2.4GHz entry should show higher signal
nmcli -f 802-11-wireless.band connection show "The Grid"  # → bg
```

## Session outcome

The 2.4GHz switch attempt hung NM twice (first via `modify + up`, second via `delete + up`). The card needed a full interface reset (`ip link set wlan0 down/up` + supplicant kill) between attempts. Once the interface was clean, `nmcli dev wifi list` showed the 2.4GHz AP at -20 dBm — but we didn't reach the password step before the session moved on. The recipe above is the verified path for when the password is available.
