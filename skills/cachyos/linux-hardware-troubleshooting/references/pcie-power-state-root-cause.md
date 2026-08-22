# PCIe power state as PCI device ghost root cause

Use when a PCI device (WiFi card, NIC, USB controller, etc.) vanishes from `lspci` on every reboot despite:
- No persistent kill files (no `ATTR{remove}` udev rule, no modprobe blacklist)
- No rfkill block (the device is absent from the bus entirely, so no rfkill node exists)
- A boot-time resurrection service that either didn't fire or didn't bring it back

The device is not "not enumerated" — it **is enumerated but asleep forever**, so the kernel's probe finds nothing responding.

## Diagnostic

Check the device's PCIe power sysfs (replace `<slot>` with the device's bus slot, e.g. `0000:04:00.0`):

```bash
# If device is present right now:
cat /sys/bus/pci/devices/0000:<slot>/power/control   # "auto" = can autosuspend
cat /sys/bus/pci/devices/0000:<slot>/power/wakeup     # "enabled" or "disabled"

# If device is ghosted (not present), check a known-present device's sysfs
# to confirm the pattern, then infer the ghosted device had the same defaults.
```

**The ghost signature:** `power/control = auto` AND `power/wakeup = disabled`.

This means:
- The device is permitted to enter a low-power state (D3cold) on idle or suspend
- The device **cannot wake itself** from that state — no wakeup event is wired
- Once it goes to D3cold, it stays there until the system loses power or a hard reset forces re-initialization
- On the next boot, the PCI enumeration probe sends configuration cycles to the slot; the device doesn't respond because it's asleep — **the kernel reports the slot as empty**

This is why a `echo 1 > /sys/bus/pci/rescan` sometimes brings it back (the rescan forces a fresh probe that may catch the device if it's already woken for some other reason) and sometimes doesn't (the device is still dead asleep).

## Root cause vs. superficial cause

| Superficial cause | What you see | Root cause (this document) |
|---|---|---|
| Kernel didn't scan the bus | Device absent from lspci, no rfkill | Device slept to D3cold and never woke; kernel's probe found nothing |
| Flaky boot enumeration | Device present but driver won't bind / connectivity broken | Enumeration succeeded but driver state is stale from the flaky window |
| Persistent kill file | Device absent, rfkill shows Hard blocked or driver missing | A udev `ATTR{remove}` rule or modprobe blacklist is actively hiding it |

All three look the same from the outside (no wlan0, no lspci entry) but have different fixes. Check power sysfs **first** — it's the cheapest probe and rules out the most common real root cause.

## Fix

Deploy a udev rule that locks the power state every time the PCI device appears on the bus. This survives reboot and corrects the state even if the device enumerates in a bad power state during boot.

```bash
# /etc/udev/rules.d/99-<dev>-power-lock.rules
ACTION=="add", SUBSYSTEM=="pci", ATTR{vendor}=="0xVVVV", ATTR{device}=="0xDDDD",
RUN+="/bin/sh -c 'echo on > /sys$devpath/power/control; echo enabled > /sys$devpath/power/wakeup'"
```

Replace `VVVV` and `DDDD` with the device's vendor/device IDs from `lspci -nn` (e.g. `10ec:b822` for RTL8822BE). The `$devpath` variable expands to the device's sysfs path (e.g. `/devices/pci0000:00/0000:00:1c.2/0000:04:00.0`).

Deploy:
```bash
sudo cp /path/to/99-<dev>-power-lock.rules /etc/udev/rules.d/
sudo udevadm control --reload-rules
```

Verify immediately (even before reboot) by triggering a rebind or checking the live sysfs:
```bash
# Force the rule to fire by rebinding the driver
DRV=$(basename $(readlink /sys/bus/pci/devices/0000:<slot>/driver))
echo "$DRV" | sudo tee /sys/bus/pci/devices/0000:<slot>/driver/unbind
echo "$DRV" | sudo tee /sys/bus/pci/devices/0000:<slot>/driver/rebind
sleep 2
cat /sys/bus/pci/devices/0000:<slot>/power/control   # should be "on"
cat /sys/bus/pci/devices/0000:<slot>/power/wakeup     # should be "enabled"
```

## Combination with other fixes

This power lock is **not a replacement** for a resurrection service or `pci=rescan`. It addresses a different failure mode:

| Fix | Failure mode it addresses |
|---|---|
| Resurrection service (PCI rescan) | Kernel's boot enumeration misses the device slot entirely |
| `pci=rescan` kernel cmdline | Kernel's default probe window is too short for the device to respond |
| PCIe power lock udev rule | Device enumerates but is asleep (D3cold) and never wakes |
| Driver rebind in resurrection service | Device enumerates but driver state is stale from flaky boot |
| Powersave udev rule (net subsystem) | WiFi driver re-enables powersave after boot |

Deploy all applicable layers. The power lock is the cheapest and most-often-missing one.

## Verification after reboot

After a reboot, confirm the fix held:

```bash
# 1. Card present
lspci -nnk | grep -A3 -i "<slot>"

# 2. Power state locked
cat /sys/bus/pci/devices/0000:<slot>/power/control    # "on"
cat /sys/bus/pci/devices/0000:<slot>/power/wakeup      # "enabled"

# 3. No rfkill block (for WiFi)
rfkill list | grep -i "phy\|wifi"

# 4. Interface UP
ip -br link show wlan0   # UP, LOWER_UP when connected

# 5. Journal for the udev rule firing
journalctl -t udev surv 2>/dev/null | grep -i "<dev>-power-lock\|power/control\|power/wakeup" | tail -5
```

## When power lock doesn't fix it

If `power/control=on` and `power/wakeup=enabled` but the device still ghosts, the root cause is elsewhere:
- **Flaky boot enumeration** → add `pci=rescan` to kernel cmdline + ensure resurrection service rebinds even when present
- **Hardware failure** → device probe errors in dmesg (`-114`, `-16`, "failed to power on mac"), resurrection service logs "device did not reappear after rescan"
- **BIOS WLAN toggle** → some laptops have a BIOS option that disables the WLAN card at the firmware level; check BIOS if all software fixes fail and the device is never present even after rescan
