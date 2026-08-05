# PCIe AER storm — RTL8822BE on synthesis (2026-07-31)

Session condensate: system-wide slowness, root-caused to a PCIe AER error storm from the (driver-blacklisted) Realtek RTL8822BE WiFi card.

## Evidence captured

- `ps aux --sort=-%cpu`: `[irq/147-aerdrv]` at **48% CPU, 82 min CPU time** accumulated over ~3h. All userspace processes normal.
- `vmstat 1 3`: `in` (interrupts) at **31–38k/sec** on an idle desktop.
- `/proc/interrupts` line 147: `PCI-MSI-0000:00:1c.2 ... aerdrv, PCIe bwctrl` — root port 00:1c.2, 300M interrupts on CPU3.
- AER counters (`/sys/bus/pci/devices/*/aer_dev_correctable`):
  - Root port `00:1c.2`: `Timeout 100126125  TOTAL_ERR_COR 100126125`
  - Device `04:00.0` (RTL8822BE): `RxErr 93403330  BadTLP 7145216  BadDLLP 35013583  Timeout 31653301  TOTAL_ERR_COR 98862573`
- Active-storm check: TOTAL_ERR_COR 99,136,337 → 99,169,787 in 5s = **~6,700 errors/sec**.
- `lspci -nnk` for 04:00.0: `Realtek RTL8822BE [10ec:b822]`, `Kernel modules: rtw88_8822be` — note **no "Kernel driver in use"** line. The modprobe blacklist (`/etc/modprobe.d/blacklist-rtl8822be.conf`, blacklisting rtw88_8822be/8822b/pci/core) was fully in effect and did nothing for the storm.

## Key lesson

The card is powered and on the bus; with no driver bound it still generates PCIe correctable errors at the hardware level, and root port 00:1c.2 raises an AER interrupt for each. **Driver blacklisting is not a hardware mute.**

Storm onset correlated with heavy bus traffic (multi-GB GGUF downloads + 12GB model loads through the GPU) starting ~3h into the session, ~27h into uptime — consistent with a marginal link dropping into an erroring power state under load (ASPM).

## Fix sequence (worked)

1. Runtime removal:
   ```bash
   echo 1 | sudo tee /sys/bus/pci/devices/0000:04:00.0/remove
   ```
2. Verify: `lspci | grep -i realtek` → empty. Root-port TOTAL_ERR_COR frozen at 100,520,953 across a 5s re-read. `top -bn1` showed irq/147-aerdrv at 4.8% instantaneous and decaying (its `ps` lifetime average stayed misleadingly high).
3. Persistence (udev, matches vendor/device ID not slot):
   ```
   # /etc/udev/rules.d/99-rtl8822be-remove.rules
   ACTION=="add", SUBSYSTEM=="pci", ATTR{vendor}=="0x10ec", ATTR{device}=="0xb822", ATTR{remove}="1"
   ```
4. Held in reserve, not needed: `pcie_aspm=off` kernel param; physical M.2 card removal recommended at next case-open.

## Post-fix state

Ethernet-only machine (Intel I219-V, e1000e — unaffected). Load average drains over ~15 min; that lag is expected and not evidence of failure.
