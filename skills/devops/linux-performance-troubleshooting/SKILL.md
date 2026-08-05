---
name: linux-performance-troubleshooting
description: Use when Linux is slow but top blames no user app.
version: 1.0.0
author: synthclaw (Orchestra Research)
license: MIT
platforms: [linux]
metadata:
  hermes:
    tags: [linux, performance, irq, aer, pcie, troubleshooting]
---

# Linux performance troubleshooting — the invisible-culprit class

Use when the system is slow/laggy/load-high and `top` shows nothing obvious in user space. The classic signature: load average high, CPU eaten by **[bracketed] kernel threads**, not processes. Covers IRQ storms, kernel-thread CPU hogs, interrupt floods, and swap thrash.

## Workflow

### 1. Snapshot everything at once

```bash
uptime                                    # load vs core count
ps aux --sort=-%cpu | head -8             # look for [bracketed] KERNEL threads
ps aux --sort=-%mem | head -8
free -h                                   # swap climbing = thrash candidate
vmstat 1 3                                # in = interrupts/s, cs = ctx switches/s
```

Read it right:
- **Idle desktop `in` (interrupts): ~1–5k/s. Storm: 30k+/s.** `cs` follows it.
- Kernel threads (`[irq/...]`, `[kworker/...]`) with huge cumulative TIME are the culprit class user-space tools never blame.
- A kthread's `%CPU` in `ps` is a **lifetime average** — after a fix, verify with `top -bn1` (instantaneous) instead. The kthread's START time tells you when the storm began — correlate with `journalctl` to find the trigger.

### 2. IRQ storm → map the interrupt to hardware

```bash
grep -E '^\s*<N>:' /proc/interrupts     # e.g. 147 → PCI-MSI-0000:00:1c.2
lspci -nnk                               # walk the bus address to the device
```

### 3. PCIe AER storm (the [irq/N-aerdrv] pattern)

AER = PCIe Advanced Error Reporting. A malfunctioning device floods its root port with correctable errors; each one fires an interrupt. Half a core gone, system-wide jank.

```bash
# Confirm + find the screaming device:
for f in /sys/bus/pci/devices/*/aer_dev_correctable; do
  d=$(dirname $f); echo "$(grep PCI_SLOT_NAME $d/uevent) $(cat $f | grep TOTAL)"
done
# Verify actively storming (read twice, 5s apart — counter increments):
cat /sys/bus/pci/devices/<addr>/aer_dev_correctable | grep TOTAL
```

Millions+ of TOTAL_ERR_COR, incrementing thousands/sec = confirmed.

**Fixes in order of preference:**
1. **Runtime bus removal** (instant, gone at reboot): `echo 1 | sudo tee /sys/bus/pci/devices/<addr>/remove` — verify error counter freezes.
2. **udev rule** (persists across boots): `ACTION=="add", SUBSYSTEM=="pci", ATTR{vendor}=="0xXXXX", ATTR{device}=="0xYYYY", ATTR{remove}="1"` in `/etc/udev/rules.d/99-<name>.rules`.
3. **BIOS/UEFI disable** — the ONLY hardware-level kill for integrated/soldered devices. Survives everything except CMOS reset.
4. `pci=noaer` kernel param — **last resort**: mutes ALL AER reporting globally, hiding future legit errors from GPU/NVMe.

**KEY PITFALL: a driver `blacklist` is NOT sufficient.** Blacklisting unloads the driver but the powered hardware keeps generating PCIe errors at the physical layer — the storm continues with zero drivers bound. You must remove the device from the bus (or power-gate it in BIOS).

### 4. Swap thrash (no IRQ storm, just paging)

`free -h` swap usage climbing during the slow operation + process in D state = working set exceeds RAM. Diagnose per-process with `smem -rk` or `/proc/<pid>/status` VmRSS vs file-backed pages. Fix = shrink the working set, not more swappiness tuning. (For llama.cpp MoE CPU-offload specifically, see the `llama-swap` skill's RAM-ceiling pitfall.)

## References

- **[pcie-aer-irq-storm-rtl8822be.md](references/pcie-aer-irq-storm-rtl8822be.md)** — full session: RTL8822BE WiFi (integrated, driver-blacklisted) storming 6,700 errors/sec through root port 00:1c.2; diagnosis chain, runtime removal, udev persistence, integrated-card BIOS fallback.
