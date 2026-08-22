---
name: linux-hardware-troubleshooting
description: Use when Linux is slow from IRQ/PCIe AER hardware storms, or when reviving an OS-killed PCI device.
version: 1.1.0
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

- `uptime` load high (>= #cores) while top userspace process is a browser at 10%
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
4. **Empty-controller case (masking > removal):** if the storming device has NOTHING attached (e.g. an unused add-on USB controller — verify with `lsusb -t`: buses showing root hubs only), masking RxErr reporting on its root port kills the interrupt/log flood while keeping the ports usable. Read the mask with `setpci -s <port> ECAP_AER+0x14.l`, OR in bit 0 (RxErr), write back preserving existing bits (e.g. `=00002001`). Persist via a systemd oneshot unit — setpci dies at reboot (template: `templates/aer-mask-root-port.service`; on synthesis 2026-08: `aer-mask-asmedia-usb.service` for port 00:1c.6). If the controller IS in use, same mask works — it only silences error *reporting*, not function.
5. **Watchdog after any AER fix:** storms are bursty — "quiet now" proves nothing. Stand up a counter-delta watchdog (`scripts/aer-watchdog.sh`: sums `TOTAL_ERR_COR` across ALL PCI devices each tick, desktop-notifies + reports the climbing port when delta > 50, silent otherwise) so a recurrence names the port before the user reports lag.
6. **Physical removal** of the card (M.2/PCIe slot) — the only fix immune to software resets. Right answer for a dead device on an Ethernet-only machine.

## Reversing a kill: device missing from lspci ≠ dead or BIOS-disabled

When a PCI device doesn't appear in `lspci` at all, check the **OS-level kill chain** before concluding the hardware died or the user disabled it in BIOS. A udev bus-remove rule (`ATTR{remove}="1"`) makes a physically-alive device vanish from `lspci` entirely — that is the signature of a software exorcism, not a hardware event.

**Pitfall — runtime PCI removal is invisible and doesn't survive reboot.** `echo 1 | sudo tee /sys/bus/pci/devices/0000:<slot>/remove` kills the device instantly but leaves **no trace in rfkill** (the device is gone from the bus, so no rfkill node is created) and **no trace in dmesg** beyond the removal itself. It does **not** survive a reboot — the device should reappear on next boot, but if the kernel's PCIe re-enumeration fails to pick it up (marginal hardware, flaky link, or a stale bus state), the device stays ghosted. This is the signature when the user says "I disabled it at the kernel level and it didn't come back after reboot." When the user explicitly states they removed the device at kernel level, **skip the kill-file inventory and go straight to rescan** — the removal was runtime, not persistent.

1. **Inventory the kill files** (only when the user's story is ambiguous — skip when they explicitly removed the device at kernel level):
   ```bash
   grep -ri 'blacklist\|install.*/bin/false' /etc/modprobe.d/   # driver blocks
   grep -rl 'ATTR{remove}' /etc/udev/rules.d/                  # bus-removal rules
   cat /proc/cmdline                                           # pcie_aspm=off etc.
   rfkill list                                                 # device absent = removed from bus; Hard blocked = BIOS/switch
   ```
   Read the comments in any rule found — kill files written with a `# Dead <device> — <incident> (<date>)` header tell you exactly why the device was exorcised. Always write kill files with that header when creating them.
2. **Revive without rebooting:**
   ```bash
   # When the user removed the device at kernel level (runtime removal, no persistent rule):
   echo 1 | sudo tee /sys/bus/pci/rescan
   ```

   **Make the rescan survive reboot (boot-time systemd oneshot).** Runtime `echo 1 | sudo tee /sys/bus/pci/rescan` brings the device back now but dies on reboot. If the device has a pattern of failing to re-enumerate on boot, deploy a systemd oneshot that runs at `sysinit.target`, *before* NetworkManager, so the rescan happens early enough for NM to see the netdev:

   - Template: `templates/wifi-resurrect.service` — oneshot `WantedBy=sysinit.target`, `Before=NetworkManager.service`, `DefaultDependencies=no`. Customize before deploying.
   - Companion script: `scripts/wifi-resurrect.sh` — triggers rescan, polls up to 30s, wakes from D3cold via unbind/rebind if needed, verifies sysfs vendor/device ID matches before touching anything, exits 1 (logged) if the card doesn't reappear (dead-card probe errors -114/-16 are a "card is dead" signal, not "keep retrying").
   - Deploy steps: `cp templates/wifi-resurrect.service /etc/systemd/system/`, `chmod +x scripts/wifi-resurrect.sh`, `systemctl daemon-reload && systemctl enable wifi-resurrect.service`.
   - The oneshot verifies the device is present and correct (vendor/device ID
     match) even when the card appears enumerated; it only triggers a full
     rescan when the device is absent. Do NOT make it a no-op when the device
     appears present — a card enumerated during a flaky boot window may carry
     stale driver state, but **do not use a driver rebind to flush it** (see
     pitfall below); the **power-lock udev rule** (see below) handles
     driver-state flush on every PCI add event, which is the reliable path.
     The resurrection service's job is to bring the card back when it is
     absent from the bus; the udev rule's job is to correct power state and
     flush driver state when the card is present. Keep the responsibilities
     separate.
   - **Kernel boot parameter for flaky enumeration:** if the card repeatedly
     ghosts on boot despite the rescan service, add `pci=rescan` to the kernel
     cmdline (e.g. Limine `KERNEL_CMDLINE[default]`). **Critical:** CachyOS
     uses Limine with a two-tier config — editing `/etc/default/limine` (the
     source) does NOT automatically update the ESP config at `/boot/limine.conf`
     (what the bootloader actually reads). After editing the source, verify the
     param is actually in effect with `cat /proc/cmdline | grep pci=rescan` —
     if it's missing, the ESP needs regeneration (`sudo limine --enroll-config`)
     or a direct `sed` patch on `/boot/limine.conf`. See
     `references/limine-esp-config-pitfall.md` for the full breakdown. Verify
     post-boot with `cat /proc/cmdline | grep pci=rescan`.
   - **PCIe power state root cause (often missed):** when a PCI device vanishes
     on every reboot AND `rfkill` has no entry for it AND no kill files exist,
     check the device's PCIe power sysfs before reaching for a rescan service:
     ```bash
     cat /sys/bus/pci/devices/0000:<slot>/power/control   # "auto" = can sleep
     cat /sys/bus/pci/devices/0000:<slot>/power/wakeup     # "disabled" = never wakes
     ```
     If `power/control` is `auto` and `power/wakeup` is `disabled`, the card
     goes to D3cold on idle/suspend and **never wakes up**. The kernel's next
     boot enumeration then misses it entirely because it never responded to the
     probe. This is a root cause distinct from "the kernel didn't scan" — the
     device IS sleeping, permanently.
     - **Fix:** lock the power state via a udev rule that fires on every PCI
       add event for the device:
       ```
       ACTION=="add", SUBSYSTEM=="pci", ATTR{vendor}=="0x10ec",
       ATTR{device}=="0xb822",
       RUN+="/bin/sh -c 'echo on > /sys$devpath/power/control; echo enabled > /sys$devpath/power/wakeup'"
       ```
       Deploy to `/etc/udev/rules.d/99-<dev>-power-lock.rules`, reload rules.
       Verify: both sysfs files read `on` and `enabled` after a rebind or reboot.
       This rule survives reboot and corrects the power state every time the
       device appears on the bus.
   - **Anchor pitfall:** do NOT set `After=` to a non-existent unit — systemd logs it and drops the dependency silently. Safe anchors: `After=local-fs.target` (guarantees `/sys` mounted) or omit `After=` entirely.
   - **Generalization:** this pattern works for any PCI device that intermittently fails boot-time enumeration. Adjust the hardcoded slot, vendor, and device IDs for the target card; the script refuses to touch a slot whose sysfs IDs don't match.

   For the general case (persistent kill files in place), also remove them:
   ```bash
   sudo rm /etc/modprobe.d/blacklist-<dev>.conf /etc/udev/rules.d/99-<dev>-remove.rules
   sudo udevadm control --reload-rules
   echo 1 | sudo tee /sys/bus/pci/rescan
   ```
3. **Verify:** `lspci -nnk` (device back, "Kernel driver in use"), `ip -br link` (interface UP), `nmcli dev` (connected), `lsmod | grep <driver>`.
4. **Judge the aftermath by rate, not presence.** A formerly-storming device may log occasional *correctable* AER errors after revival — a few per hour is a trickle, not a storm. Apply the existing test: read `TOTAL_ERR_COR` twice 5s apart; thousands/sec increase = storm returned → re-apply the kill ladder.
5. **When the user insists "I turned it off in BIOS":** the OS trail (blacklist files, udev rules with incident comments) beats human memory — verify it first, state what you found, then let them check BIOS. Some machines genuinely have a BIOS WLAN toggle; both can be true at once.

## Post-revival WiFi lock-down (PCI WiFi devices — RTL8822BE and similar)

When the resurrected device is a WiFi card, resuscitation is only half the job. The card has a habit of re-enabling powersave and selecting the wrong band on its own. Lock both down before declaring the fix complete.

### Powersave persistence via udev (survives reboot, fires before NM)

NM's `802-11-wireless.powersave=2` (disable) only takes effect when the connection profile activates. If the card re-enables powersave at the driver level between boots — or before NM starts — connectivity dies. A udev rule fires unconditionally on every `wlan0` add:

```
# /etc/udev/rules.d/99-<dev>-powersave.rules
ACTION=="add", SUBSYSTEM=="net", KERNEL=="wlan0", RUN+="/sbin/iw dev $kernel set power_save off"
```

Deploy: `sudo tee` the file, `sudo udevadm control --reload-rules`. Verify: `iw dev wlan0 get power_save` → `Power save: off`.

### Band lock via NM profile

Force a specific band so the card never falls back to a crowded or undesired band:

```
sudo nmcli connection modify "<conn-name>" 802-11-wireless.band a
```

`a` = 5GHz only; `bg` = 2.4GHz only. Combine with `802-11-wireless.powersave 2` in the same modify call. Verify: `nmcli -f 802-11-wireless.band,802-11-wireless.powersave connection show "<conn-name>"`.

### Full verification sweep (post-revival, before declaring done)

Run all of these and confirm each:
- `lspci -nnk` — device present, `Kernel driver in use: <driver>`
- `rfkill list` — no soft/hard block on the WiFi phy
- `iw dev wlan0 get power_save` — `Power save: off`
- `ip -br link show wlan0` — `UP`, `LOWER_UP` (carrier present when connected)
- `nmcli dev show wlan0` — `GENERAL.STATE: 100 (connected)` when AP in range
- `nmcli -f 802-11-wireless.band,802-11-wireless.powersave connection show "<conn>"` — band + powersave as configured
- `nmcli -f connection.autoconnect connection show "<conn>"` — must be `yes` (defaults to `no` on manually created connections — WiFi won't reconnect on boot without it)

### Pitfall — NM autoconnect defaults to `no` on manually managed connections

A WiFi connection activated manually with `nmcli connection up` does **not** autoconnect on boot by default. Even with the rescan service bringing the card back and NM seeing `wlan0`, the connection stays down unless `connection.autoconnect` is `yes`. Set it explicitly:

```bash
nmcli connection modify "<conn-name>" connection.autoconnect yes
```

Combine with the band lock and BSSID pinning (below) in the same modify call. Verify: `nmcli -f connection.autoconnect,802-11-wireless.band,802-11-wireless.bssid connection show "<conn>"`.

### Pitfall — BSSID randomization breaks AP association after NM reset

When NM resets a WiFi connection (recreate profile, delete+recreate, or `nmcli connection modify` on a dying card), it may **randomize the MAC address** (`mac-address-randomization`). The AP sees a different MAC than the one it has an authorized/connected entry for, and association fails silently — the card shows `connecting (configuring)` indefinitely with no error.

**Signature:** `ip link show wlan0` shows a MAC that differs from the card's `permaddr`. E.g. `link/ether de:88:56:6d:3e:4a ... permaddr 80:c5:f2:9e:4a:4f` — the card's real MAC is `80:c5:...` but the interface was given `de:88:...`.

**Fix before reconnecting:**
```bash
sudo ip link set wlan0 address 80:c5:f2:9e:4a:4f   # restore permaddr (replace with actual)
sudo ip link set wlan0 up
```
Then re-trigger NM connect. If NM's state machine is hung, also kill the supplicant for that interface first:
```bash
kill -9 $(pgrep -f "wpa_supplicant.*wlan0") 2>/dev/null
```
**Prevent at profile level:**
```bash
nmcli connection modify "The Grid" 802-11-wireless.mac-address-randomization never
```
Verify: `ip link show wlan0 | grep link/ether` shows the permaddr, not a randomized one.


### Pitfall — `802-11-wireless.band=bg` (2.4GHz) re-association can hang NM

Forcing the band to `bg` (2.4GHz) via `nmcli connection modify "<conn>" 802-11-wireless.band bg` works for the profile change, but the first activation after the switch can **hang NM in "connecting (configuring)" indefinitely** — the card is scanning the 2.4GHz band but the supplicant can't complete the WPA handshake, often because the AP's 2.4GHz BSSID is a different MAC than the 5GHz one and the profile still references the old BSSID, or because the card's driver is in a bad state.

**This session:** `nmcli connection up "The Grid"` after setting `802-11-wireless.band=bg` hung for 30+ seconds, then timed out. The `iw dev wlan0 survey dump` returned empty. Deleting the connection profile, then using `nmcli dev wifi connect "The Grid" password <pass> band bg bssid <2.4-AP-MAC>` worked — but only when the password was known (NM's `dev wifi connect` prompts for it interactively if not provided, and pasting through terminal/bash expands `<pass>` as a glob if unquoted).

**Recovery sequence when NM hangs on band switch:**
1. Disconnect: `nmcli dev disconnect wlan0`
2. Reset the interface: `ip link set wlan0 down && ip link set wlan0 up`
3. Restore the permaddr if it got randomized: `sudo ip link set wlan0 address <permaddr>` (see BSSID randomization pitfall above)
4. Recreate the connection targeting the 2.4GHz AP by BSSID:
   ```bash
   nmcli dev wifi connect "The Grid" password <pass> band bg bssid F4:52:46:4F:D9:3B
   ```
   Fill in the actual password — if unknown, connect via the desktop UI first, then export the profile.
5. If the card is slow/unresponsive after a reset, give it time — `nmcli dev wifi list` may take 5-10s to return after an `ip link set wlan0 up`.

**If you don't know the WiFi password:** the only path is the desktop UI (KDE system tray NetworkManager widget) — right-click the AP → Connect, enter password. After it connects, export the active profile's settings with `nmcli -f 802-11-wireless.*,802-11-wireless-security.psk connection show "The Grid"` (the psk field is the raw password when `show-secrets` is available) or recreate the connection with `nmcli connection clone "The Grid" "The Grid 2.4"`.

**Fallback if 2.4GHz also fails to hold:** revert to 5GHz (`band a`) and use a reconnect watchdog (a systemd timer + script that checks `nmcli dev show wlan0` state and re-runs `nmcli connection up` on drop) — the 5GHz AP may have a stronger signal even if it drops occasionally, and a fast reconnect script beats a stubborn card.

### Pitfall — resurrection service rebind can silently fail

### Disabling a PCI device permanently — build and verify the full kill chain

When the user wants a problematic PCI device (e.g. a WiFi card causing CPU/PCIe storms) permanently disabled, rfkill + driver unload is not enough. Build and verify the **full kill chain**:

| Layer | Mechanism | Verify |
|-------|-----------|--------|
| rfkill | `rfkill block wifi` / `nmcli radio wifi off` | `rfkill list` → soft-blocked |
| driver | `modprobe -r` + blacklist in `/etc/modprobe.d/` with `install /bin/true` | `lsmod \| grep rtw88` → empty; file exists |
| udev | Remove any `ATTR{remove}` or power-lock rules for the device | `ls /etc/udev/rules.d/ \| grep <dev>` → empty |
| boot cmdline | Strip `pci=rescan` from Limine config (both `/etc/default/limine` AND `/boot/limine.conf`) | `cat /proc/cmdline \| grep pci=rescan` → absent |
| service | Disable + remove resurrection service | `systemctl is-enabled wifi-resurrect` → disabled; file gone |
| NM | Remove the connection profile | `nmcli connection show \| grep <ssid>` → absent |

**Critical pitfall:** `pci=rescan` in the boot cmdline makes the kernel actively re-scan the PCI bus at boot — including for devices you meant to keep disabled. When killing a PCI device, strip this param. On CachyOS + Limine, editing `/etc/default/limine` does **not** update `/boot/limine.conf` (the ESP config the bootloader actually reads). After editing the source, either regenerate with `sudo limine --enroll-config` or patch the ESP directly with `sudo sed`. **Always verify the active cmdline** with `cat /proc/cmdline` — if the param is still there, the ESP wasn't updated.

**This session:** stripped `pci=rescan` from both config files but it remained in `/proc/cmdline` because the ESP config hadn't been regenerated. The card was already ghosted out of the PCI bus at that point, so the param was harmless but conceptually wrong — the kernel shouldn't be hunting for a device the user explicitly disabled.

### Root cause: PCIe power state can ghost a PCI device even with rescan in place

### Root cause: PCIe power state can ghost a PCI device even with rescan in place

When a PCI device vanishes on every reboot despite a working resurrection service, **check the device's PCIe power sysfs before assuming the rescan failed**:

```bash
cat /sys/bus/pci/devices/0000:<slot>/power/control   # "auto" = can sleep
cat /sys/bus/pci/devices/0000:<slot>/power/wakeup     # "disabled" = never wakes
```

If `power/control` is `auto` and `power/wakeup` is `disabled`, the device goes to D3cold and **never wakes** — the kernel's next boot probe finds nothing because the device is asleep forever, not because the kernel didn't scan. This is a root cause distinct from "the kernel didn't enumerate."

**Pitfall — `power/control=on` alone is not enough.** Setting `power/control=on` via udev but leaving `power/wakeup=disabled` means the device stays on while running, but if it ever enters a sleep state (D3cold), it cannot wake. **Both must be set**: `control=on` AND `wakeup=enabled`. The udev rule must write to both sysfs files:

```
ACTION=="add", SUBSYSTEM=="pci", ATTR{vendor}=="0x10ec", ATTR{device}=="0xb822",
RUN+="/bin/sh -c 'echo on > /sys$devpath/power/control; echo enabled > /sys$devpath/power/wakeup'"
```

- **[references/pcie-total-device-silence.md](references/pcie-total-device-silence.md)** — full kill-chain verification for PCI devices disabled at software level; the `pci=rescan` vs blacklist pitfall; CachyOS + Limine two-tier config trap; how to tell a "disabled" card is actually dead vs soft-killed vs hardware-failed. Captures this session's disable-chain verification and the `pci=rescan` persistence trap.

**Interaction with the resurrection service:** the resurrection service (PCI rescan + rebind) and the power-lock udev rule defend on two fronts. The service handles the device being absent from the bus entirely (didn't enumerate); the udev rule handles the device being present but with a broken power state. Without the power-lock rule, a device that goes to D3cold during the boot window may still be ghosted even after a successful rescan.

See `references/limine-esp-config-pitfall.md` for the Limine ESP vs source config split — a frequent footgun when adding kernel cmdline params on CachyOS.

See `references/wifi-powersave-persistence.md` for the session transcript and exact commands.

## General principles

- **Kernel threads accumulate *lifetime* average CPU in `ps`.** After the fix, `[irq/N-aerdrv]` still shows a scary %CPU. Judge by instantaneous `top -bn1` and whether TIME+ stops advancing.
- **Load average drains slowly** (1/5/15-min exponential). Verify the fix via interrupt rate (`vmstat 1 3`, watch `in`) and error counters, not by waiting for load to drop.
- **Correlate storm onset with activity.** Heavy bus traffic (GPU model loads, NVMe bursts) can push a marginal link into an erroring power state — a storm starting during such work points back to the same marginal hardware.
- **Don't reflexively blame the known-bad device.** On a machine with a history of WiFi AER storms, a 2026-08 lag spike traced to root port `00:1c.6` → an **ASMedia USB 3.1 host controller** (RxErr bursts) — the WiFi card was innocent. ASMedia USB controllers are notorious for correctable RxErr floods even with `pcie_aspm=off`; a burst floods interrupts/logging and stalls the bus. Always `lspci -tv` the storming root port to name the actual child device before prescribing the fix for the usual suspect.
- **"Storm already passed" signature:** user reports lag, load average is high (15 on 12 cores) but summed %CPU is modest (~260%), `vmstat` shows wa=0, no D-state procs, and a 10-second AER recount shows zero new errors. The complaint lagged the event — compare dmesg AER timestamps against `uptime` to confirm the burst window matches the complaint, tell the user it's already settling, and only then hunt recurrence prevention. Don't prescribe fixes for a storm that isn't running.
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
- **[references/pcie-rescan-revival.md](references/pcie-rescan-revival.md)** — runtime PCI removal ghosted on reboot: RTL8822BE didn't survive re-enumeration after `echo 1 > /sys/bus/pci/devices/0000:04:00.0/remove`; brought back via `echo 1 > /sys/bus/pci/rescan`. Covers the "I disabled it at kernel level and it didn't come back" path.
- **[references/wifi-powersave-persistence.md](references/wifi-powersave-persistence.md)** — session transcript: RTL8822BE ghosted after runtime PCI removal, resurrected via PCI rescan, powersave disabled at driver level (udev rule), band locked to 5GHz via NM profile, full post-revival verification sweep.