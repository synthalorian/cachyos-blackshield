# WiFi powersave persistence — RTL8822BE on synthesis (2026-08-12)

## What happened

The RTL8822BE (PCI slot `04:00.0`) was ghosted — absent from `lspci`, no `wlan0`, no rfkill `phy1` entry. The user reported it was "disabled at a kernel level" and kept turning itself off on reboot. No persistent kill files were present: `/etc/modprobe.d/` held only `options rtw88_pci disable_aspm=y` (good — storm prevention, not a block), `/etc/udev/rules.d/` held no `ATTR{remove}` rules.

This is the runtime-PCI-removal-dies-at-reboot signature: the card was removed at kernel level previously (non-persistent), and on this boot the kernel's PCIe re-enumeration failed to rediscover it, leaving it ghosted.

## Fix sequence (exact commands)

### 1. Resurrect via PCI rescan

```bash
echo 1 | sudo tee /sys/bus/pci/rescan
sleep 3
lspci -nnk | grep -A3 -i "04:00\|8822\|network"
```

Result: `04:00.0 Network controller [0280]: Realtek RTL8822BE ... Kernel driver in use: rtw88_8822be`.

### 2. Verify rfkill and interface

```bash
rfkill list all          # → phy1: Wireless LAN, Soft blocked: no, Hard blocked: no
ip -br link show wlan0   # → wlan0 DOWN ... <NO-CARRIER,...> (UP but no carrier — normal)
```

### 3. Inspect driver params

```bash
sudo modinfo rtw88_pci | grep -A1 "parm"
# → disable_aspm, disable_msi
cat /sys/module/rtw88_pci/parameters/*  # → disable_aspm: Y, disable_msi: N
```

ASPM already disabled (`Y`) via `/etc/modprobe.d/rtw88.conf`. Good.

### 4. Kill powersave at driver level (runtime, now)

```bash
sudo iw dev wlan0 set power_save off
sudo iw dev wlan0 get power_save   # → Power save: off
```

### 5. Lock band + powersave in NM profile

```bash
nmcli connection modify "The Grid" 802-11-wireless.band a 802-11-wireless.powersave 2
nmcli -f 802-11-wireless.band,802-11-wireless.powersave connection show "The Grid"
# → band: a, powersave: 2 (disable)
```

### 6. Connect and verify

```bash
sudo nmcli connection up "The Grid"
ip -br link show wlan0          # → UP, LOWER_UP
nmcli dev show wlan0 | grep STATE  # → GENERAL.STATE: 100 (connected)
```

### 7. Persist powersave via udev rule (survives reboot)

The NM profile setting only applies when the connection activates. A udev rule fires unconditionally on every `wlan0` add — including before NM starts:

```bash
sudo tee /etc/udev/rules.d/99-rtl8822be-powersave.rules > /dev/null << 'EOF'
# RTL8822BE — disable WiFi powersave at driver level (survives reboot,
# applied before NM would ever enable it). Prevents the card from
# turning itself off / sleeping on idle.
ACTION=="add", SUBSYSTEM=="net", KERNEL=="wlan0", RUN+="/sbin/iw dev $kernel set power_save off"
EOF
sudo udevadm control --reload-rules
```

## Full verification sweep (post-revival, all green)

- `lspci -nnk` — `04:00.0`, `Kernel driver in use: rtw88_8822be`
- `rfkill list` — `phy1: Wireless LAN`, no soft/hard block
- `iw dev wlan0 get power_save` — `Power save: off`
- `ip -br link show wlan0` — `UP`, `LOWER_UP`
- `nmcli dev show wlan0` — `GENERAL.STATE: 100 (connected)`
- `nmcli -f 802-11-wireless.band,802-11-wireless.powersave connection show "The Grid"` — `band: a`, `powersave: 2 (disable)`
- `/sys/module/rtw88_pci/parameters/disable_aspm` — `Y`

## Why both NM profile AND udev rule

NM's `802-11-wireless.powersave=2` is **connection-scoped**. If the user has multiple WiFi profiles, or connects to an AP whose profile lacks the setting, powersave re-enables. The udev rule is **device-scoped** — it fires whenever `wlan0` appears, regardless of which profile is active. Use both for full coverage.

## Session epilogue: PCIe power state as root cause (2026-08-13)

The card ghosted again after deployment. The root cause was not the enumeration — it was the card's PCIe power state: `power/control=auto` and `power/wakeup=disabled`. The card went to D3cold and never woke, so the kernel's next boot probe found nothing.

**Fix:** a udev rule that locks the power state every time the PCI device appears:
```
ACTION=="add", SUBSYSTEM=="pci", ATTR{vendor}=="0x10ec", ATTR{device}=="0xb822",
RUN+="/bin/sh -c 'echo on > /sys$devpath/power/control; echo enabled > /sys$devpath/power/wakeup'"
```
File: `/etc/udev/rules.d/99-rtl8822be-power-lock.rules`. The `pci=rescan` kernel cmdline was also added to force aggressive re-enumeration. See `references/pcie-power-state-root-cause.md` for the full pattern.

## Related references

- `references/pcie-rescan-revival.md` — the ghosted-device path, same card, prior session.
- `references/pcie-aer-rtl8822be.md` — the long storm history that originally killed the card.
