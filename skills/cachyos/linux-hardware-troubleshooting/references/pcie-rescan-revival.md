# PCI rescan revival — RTL8822BE on synthesis (2026-08-12)

Session condensate: a PCIe device removed at runtime via `echo 1 > /sys/bus/pci/devices/0000:04:00.0/remove` did not reappear on reboot, even though no persistent kill files (udev rule, modprobe blacklist) were in place. The card was a revived-after-death RTL8822BE (marginal contact behavior, epilogue-documented in `pcie-aer-rtl8822be.md`). Rescan brought it back.

## What happened

**Context:** The RTL8822BE had a long history on this box (2026-07-31 AER storm → triple-buried; 2026-08-05 declared dead; 2026-08-11 revived). The persistent kill chain (udev bus-remove rule + driver blacklist) had been removed after revival; only the prevention stack remained (`rtw88_pci disable_aspm=y`, powersave off). The user then removed the device at runtime (`echo 1 > /sys/bus/pci/devices/0000:04:00.0/remove`) — a non-persistent operation.

**Failure mode:** On reboot, the device did not re-enumerate. No `wlan0`, no rfkill `phy1`, no PCI entry for `04:00.0`. Yet no rfkill block, no blacklist, no udev rule — all the usual suspects were cleared. The runtime removal had done its job (device gone from bus), but the kernel's PCIe re-enumeration on the next boot failed to rediscover the card, leaving it ghosted.

**Fix:** `echo 1 | sudo tee /sys/bus/pci/rescan` re-triggered enumeration. Device `04:00.0` reappeared, `rtw88_8822be` bound, `wlan0` came up, rfkill `phy1: Wireless LAN` clean (no soft/hard block).

## Verification trail (post-revival)

- `lspci -nnk`: `04:00.0 Network controller [0280] Realtek RTL8822BE [10ec:b822]` with `Kernel driver in use: rtw88_8822be`
- `rfkill list`: `2: phy1: Wireless LAN` — Soft blocked: no, Hard blocked: no
- `iw dev`: `phy#1`, `Interface wlan0`, `mode managed`, `txpower 30.00 dBm`
- `nmcli device`: `wlan0 wifi disconnected` (expected — no AP connected)
- `ip link show wlan0`: `<NO-CARRIER,BROADCAST,MULTICAST,UP>` (UP but no carrier — normal for disconnected WiFi)
- Saved connection present: `The Grid` (67ac1ec3-... — wifi type, ready to connect)
- AER counters on `04:00.0`: `RxErr 0, BadTLP 0, TOTAL_ERR_COR 0` — storm not returning

## Why the kill chain was already clean

Inventory confirmed no persistent removal in place:
- `/etc/modprobe.d/`: only `options rtw88_pci disable_aspm=y` (good — storm prevention, not a block)
- `/etc/udev/rules.d/`: no `ATTR{remove}` rules
- `/etc/systemd/system/` and `/usr/lib/systemd/system/`: `rfkill-block@` and `rfkill-unblock@` both disabled
- `rfkill`: only `hci0: Bluetooth` device existed — no WiFi rfkill node at all (consistent with the device being absent from the bus, not blocked in place)

## Epilogue: root cause after multiple resurrections (2026-08-13)

After the card was revived and the resurrection service deployed, it ghosted again on the next boot — even though the service ran, found the device "already present," and exited. This session identified the actual root cause: the card's **PCIe power state**, not the enumeration itself.

**Discovery:** on the ghosted boot, the card's sysfs power controls read:
- `power/control = auto` (card permitted to autosuspend)
- `power/wakeup = disabled` (card cannot wake from D3cold)

The card was going to D3cold on idle/suspend and never waking. On the next boot, the kernel's PCI enumeration probe found nothing responding at `04:00.0` — not because the kernel didn't scan, but because the card was asleep forever. The resurrection service's "already present" path was also wrong: a boot that managed to enumerate the card could leave stale driver state (a flaky enumeration), so the service was changed to always rebind even when present, not just skip.

**Fixes applied (in order of permanence):**
1. **PCIe power lock udev rule** — `/etc/udev/rules.d/99-rtl8822be-power-lock.rules`: forces `power/control=on` and `power/wakeup=enabled` every time the PCI device appears. This prevents the card from ever sleeping to D3cold.
2. **`pci=rescan` kernel cmdline** — added to `/etc/default/limine` `KERNEL_CMDLINE[default]`. Tells the kernel to re-scan the PCIe bus after the initial probe, catching devices the default probe window misses.
3. **Resurrection service rebind path** — the service now rebinds the driver even when the device is already present, to flush stale state from flaky boot enumeration.

**Verification:** after fixes, `cat /sys/bus/pci/devices/0000:04:00.0/power/control` → `on`, `cat .../power/wakeup` → `enabled`. Card survives reboot.

## Lesson

Runtime PCI removal (`echo 1 > /sys/bus/pci/devices/.../remove`) is a non-persistent, invisible-to-rfkill operation. When a user says "I disabled it at the kernel level and it didn't survive reboot," the right first move is **rescan**, not BIOS check or kill-file inventory — the runtime removal already did the kill, and the device should come back on rescan unless the kernel's re-enumeration itself is failing. Only fall back to kill-file inventory if rescan doesn't bring it back.

See also: `references/pcie-aer-rtl8822be.md` (full storm history + revival epilogue), `SKILL.md#Reversing-a-kill` (updated with the runtime-removal-dies-at-reboot pitfall).
