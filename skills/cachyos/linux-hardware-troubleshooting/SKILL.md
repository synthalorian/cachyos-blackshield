---
name: linux-hardware-troubleshooting
description: Use when Linux is slow from IRQ/PCIe AER hardware storms.
version: 1.0.0
author: synthclaw (Orchestra Research)
license: MIT
tags: [linux, hardware, pcie, aer, irq, troubleshooting, performance]
metadata:
  hermes:
    tags: [linux, hardware, pcie, aer, irq, troubleshooting, performance]
---

# Linux Hardware Troubleshooting

Use when a Linux box is slow/unstable and the cause is **below userspace**: interrupt storms, PCIe bus errors, faulting hardware. The signature is high load average with no single userspace process explaining it.

## Symptom recognition

- `uptime` load high (≥ #cores) while top userspace process is a browser at 10%
- A **kernel thread** near the top of `ps aux --sort=-%cpu`: `[irq/N-<name>]`, `[kworker/*]`, `[irq/N-aerdrv]`
- `vmstat 1 3` shows `in` (interrupts) in the tens of thousands per second on an idle desktop (normal: low thousands)
- Slowness started at a wall-clock time correlating with a hardware event (link state change, ASPM transition, device hotplug, heavy bus traffic)

## Diagnosis workflow (PCIe AER storm — the archetype)

1. **Identify the IRQ and its device:**
   ```bash
   grep -E '^\s*<N>:' /proc/interrupts   # N from the kthread name
   # → e.g. PCI-MSI-0000:00:1c.2  aerdrv  (a root port)
   ```
2. **Read AER counters for every PCIe device** (no sudo needed):
   ```bash
   for f in /sys/bus/pci/devices/*/aer_dev_correctable; do
     d=$(dirname $f); echo "$(grep PCI_SLOT_NAME $d/uevent) $(cat $f | tr '\n' ' ')"
   done
   ```
   The offending device shows millions of RxErr/BadTLP/BadDLLP/Timeout. Its **upstream root port** shows a matching Timeout count — that port's IRQ is the storm thread.
3. **Confirm the storm is active, not historical:** read `TOTAL_ERR_COR` twice 5s apart. Thousands/sec increase = active storm.
4. **Map slot → hardware:** `lspci -nnk | grep -iA2 <slot-suffix>` (e.g. `04:00.0`).

## The core pitfall: driver blacklist ≠ hardware silenced

`modprobe.d` blacklists only prevent the **driver** from binding. A physically present, powered, malfunctioning device **keeps generating PCIe errors at the hardware level**, and the root port keeps raising AER interrupts for every one. If a device was "blacklisted but the problem came back," this is why. Verify with `lspci -nnk`: "Kernel modules: X" listed but no "Kernel driver in use" means blacklisted — and irrelevant to the storm.

## Fix ladder (least → most permanent)

1. **Runtime bus removal (instant relief, dies at reboot):**
   ```bash
   echo 1 | sudo tee /sys/bus/pci/devices/0000:<slot>/remove
   ```
   Verify: `lspci` no longer lists it; the root port's `TOTAL_ERR_COR` freezes; the irq kthread's %CPU decays (its lifetime average in `ps` drains slowly — check instantaneous `top -bn1`).
2. **udev rule (survives reboot, targeted):**
   ```
   # /etc/udev/rules.d/99-<device>-remove.rules
   ACTION=="add", SUBSYSTEM=="pci", ATTR{vendor}=="0x10ec", ATTR{device}=="0xb822", ATTR{remove}="1"
   ```
   Match by vendor/device ID, not slot — IDs survive slot renumbering. Get them from `lspci -nn` output `[10ec:b822]`.
3. **ASPM angle:** if a storm starts spontaneously after hours of uptime, a link power-state transition is a likely trigger. If device removal is not an option (needed hardware), try `pcie_aspm=off` kernel param, or mask correctable-error reporting on the root port via `setpci` on the AER capability (offset 0x14, mask the storming bits).
4. **Physical removal** of the card (M.2/PCIe slot) — the only fix immune to software resets. Right answer for a dead device on an Ethernet-only machine.

## General principles

- **Kernel threads accumulate *lifetime* average CPU in `ps`.** After the fix, `[irq/N-aerdrv]` still shows a scary %CPU. Judge by instantaneous `top -bn1` and whether TIME+ stops advancing.
- **Load average drains slowly** (1/5/15-min exponential). Verify the fix via interrupt rate (`vmstat 1 3`, watch `in`) and error counters, not by waiting for load to drop.
- **Correlate storm onset with activity.** Heavy bus traffic (GPU model loads, NVMe bursts) can push a marginal link into an erroring power state — a storm starting during such work points back to the same marginal hardware.
- `dmesg` may be restricted (`kernel.dmesg_restrict=1`) — the sysfs AER counters above need no privileges and carry the same evidence.

## Full-system FREEZE (log-silent, power-button recovery) — a different class

Not slowness — the whole box locks (Wayland session included) with ZERO kernel log at the end of the previous boot. Diagnosed on synthesis 2026-08 (i7-8700K + GTX 1080 Ti, 4 freezes in 50 min).

1. **Confirm the crash pattern:** `journalctl --list-boots` — repeated short boots ending with no shutdown logs = hard hangs. `journalctl -b -1 | tail` shows the last breath (nothing useful is normal — the hang prevents flushing).
2. **Eliminate the usual suspects fast (each is one command):** RSS flat over a minute under load (not a leak), `nvidia-smi` temps <75°C under load (not thermal), `dmesg | grep -i xid` (no GPU driver hang logged), AER counters stable (not a storm), `lspci` for known-bad devices.
3. **Prime suspect on 8th/9th-gen Intel + aging PSU: deep package C-states.** Bursty load↔idle transitions (game launch, bench bursts) trip the freeze. Check `cat /sys/module/intel_idle/parameters/max_cstate` (9 = deep states on).
   - **Runtime test/fix (no reboot, reversible):** hold `/dev/cpu_dma_latency` at 30µs — the CPU can't enter deep C-states while the fd is held:
     ```bash
     sudo bash -c 'exec 3>/dev/cpu_dma_latency && printf "\x1e\x00\x00\x00" >&3 && exec sleep infinity' &
     ```
     If freezes stop with the clamp held, C-states are confirmed. Also flip `scaling_governor` to `performance` (powersave lurches through freq transitions).
   - **Permanent:** `intel_idle.max_cstate=2` kernel cmdline (limine.conf on this box), or disable C6 in BIOS.
4. **GPU transient power trips (1080 Ti is notorious):** instant-reboot (not freeze) under bursty GPU load with normal temps = PSU tripping on microsecond spikes. Runtime mitigation: `sudo nvidia-smi -pl 180` (from 250W; ~5-10% perf cost). Resets on reboot — persist via systemd unit if it proves out.
5. **Both runtime mitigations die on reboot.** When the diagnosis is paused (user moving systems, lag complaints), REVERT them and say so: `nvidia-smi -pl 250`, kill the clamp PID, governor back. The clamp's deep-sleep block + power cap cost real snappiness — don't leave them on silently.
6. **If clamped freezes continue:** memtest86+ (XMP degradation on aging DDR4), then an X11-session A/B (Wayland+KWin+NVIDIA has its own hard-hang paths).

## References

- **[references/pcie-aer-rtl8822be.md](references/pcie-aer-rtl8822be.md)** — full session detail: RTL8822BE WiFi AER storm on synthesis (100M errors, 6.7k/s, irq/147-aerdrv at 48% CPU), diagnosis output, exact fix sequence, persistence via udev rule.
