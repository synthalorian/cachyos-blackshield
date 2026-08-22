# RTL8822BE Known Issues

## Module Stack (verified on this system)

```
rtw88_8822be       12288  0
rtw88_8822b        233472  1 rtw88_8822be
rtw88_pci          45056  1 rtw88_8822be
rtw88_core         356352  2 rtw88_pci,rtw88_8822b
mac80211           1859584  2 rtw88_pci,rtw88_core
cfg80211           1614752  2 rtw88_core,mac80211
```

Note: `rtw88` is NOT a loadable module — it's a built-in component of the other modules. `modinfo rtw88` fails. Don't chase a non-existent module.

## Verified Parameters

```
/sys/module/rtw88_core/parameters/debug_mask:     0
/sys/module/rtw88_core/parameters/disable_lps_deep: Y
/sys/module/rtw88_core/parameters/support_bf:     Y
/sys/module/rtw88_pci/parameters/disable_aspm:   Y
/sys/module/rtw88_pci/parameters/disable_msi:    N
```

## Storm-Proofing Checklist

1. **Kernel cmdline**: `pcie_aspm=off` — must be present in `/proc/cmdline`
   - Set via `/etc/default/limine` (persistent across kernel updates)
   - Survives kernel-update regen via limine-entry-tool

2. **rtw88_pci.disable_aspm**: Y — disable PCIe ASPM at the driver level
   - Loads from `/sys/module/rtw88_pci/parameters/disable_aspm`

3. **rtw88_core.disable_lps_deep**: Y — disable deep low-power state
   - Prevents the card from powering down during idle periods

4. **rtw88_pci.disable_msi**: N — MSI is fine, leave it

## Known Failure Mode

The card holds connections stably until the wireless environment hiccups (signal dip, interference burst, AP load spike). Then it autonomously disconnects (reason 3 = DEAUTH_LEAVING) and reconnects on its own. This is the card's behavior, not NM dropping it.

Power management fixes prevent some cases, but when signal quality is marginal (-70 dBm or worse on 5GHz), the card will still drop under game load.

## Recovery After State Corruption

When the card enters a bad state (NM stuck in "connecting (configuring)", scans hanging):

```bash
# Reset interface and MAC
nmcli dev disconnect wlan0
ip link set wlan0 down
# Check MAC — must match permaddr
ip link show wlan0 | grep permaddr
# If MAC was randomized, reset it
ip link set wlan0 address <permaddr>
ip link set wlan0 up
```

NM's `dev wifi rescan` can hang on this card — run in background or skip it.

## When to Consider USB Tether

If the card continues dropping despite the storm-proofing checklist and signal quality is poor on both bands, USB tethering to a phone provides a hardwired connection that won't drop. This is the definitive fix when WiFi cannot be stabilized.

See also: `references/networkmanager-state-machine.md` for NM recovery paths.
