# PCIe AER IRQ storm — RTL8822BE on synthesis (2026-07-31)

## Symptoms

- System-wide sluggishness, load average ~4 on a 6-core i7-8700K desktop
- `ps aux --sort=-%cpu`: `[irq/147-aerdrv]` at 48% CPU, 82 min cumulative TIME, kthread started 15:47 (storm onset — correlated with heavy PCIe activity from LLM model loads)
- `vmstat 1 3`: `in` ~31–38k interrupts/s (idle desktop should be ~1–5k), `cs` ~29–32k/s

## Diagnosis chain

1. `grep -E '^\s*147:' /proc/interrupts` → `PCI-MSI-0000:00:1c.2 aerdrv` — root port 00:1c.2
2. `/sys/bus/pci/devices/*/aer_dev_correctable` sweep:
   - Root port `0000:00:1c.2`: **Timeout 100,126,125** (100M)
   - Downstream `0000:04:00.0` (RTL8822BE WiFi): RxErr 93M, BadTLP 7M, BadDLLP 35M, Timeout 31M
3. Double-read 5s apart: +33,450 errors → **~6,700 errors/sec, actively storming**
4. `lspci -nnk`: `04:00.0 Network controller Realtek RTL8822BE [10ec:b822]`, **no "Kernel driver in use"** — the rtw88 blacklist (`/etc/modprobe.d/blacklist-rtl8822be.conf`) was intact and working, yet the storm raged on. **Blacklist ≠ fix: hardware errors without a driver.**

## Fix applied

```bash
echo 1 | sudo tee /sys/bus/pci/devices/0000:04:00.0/remove
```

- `lspci | grep -i realtek` → empty (device off the bus)
- Root-port counter **froze** at 100,520,953 (zero new errors in 5s)
- `top -bn1`: irq/147-aerdrv instantaneous CPU 48% → 4.8% and falling (the ps %CPU is a lifetime average — don't trust it post-fix)

## Persistence (device is INTEGRATED — cannot be physically yanked)

1. udev rule (boot-persistent, targeted by vendor/device ID):
   ```
   # /etc/udev/rules.d/99-rtl8822be-remove.rules
   ACTION=="add", SUBSYSTEM=="pci", ATTR{vendor}=="0x10ec", ATTR{device}=="0xb822", ATTR{remove}="1"
   ```
2. BIOS: `Advanced → Onboard Devices Configuration → Wi-Fi 802.11ac → Disabled` — true hardware kill for integrated cards (survives everything but CMOS reset)
3. Rejected: `pci=noaer` boot param — global mute, would hide future legit GPU/NVMe errors
4. If the storm recurs with device removal in place, next lever: `pcie_aspm=off` (storm likely triggered by an ASPM link power-state transition — it started 27h into uptime)

## Lessons

- A powered, driverless, malfunctioning PCIe device can still DDoS the CPU via correctable-error interrupts. Driver blacklists are software; AER is physics.
- Storm onset time (kthread START) + journal correlation found the trigger window (heavy GPU/PCIe traffic from LLM model loading).
- Verify fixes with instantaneous CPU (`top -bn1`) and frozen counters, not `ps` averages.
