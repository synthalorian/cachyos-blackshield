# PCI Total Device Silence — How to Know a "Disabled" Card Is Actually Dead (vs Soft-Killed)

Use when the user says "disable the WiFi / PCIe device" and the question is: **did we actually kill it, or just hide it?** This document captures the full kill-chain verification and a single critical boot-cmdline pitfall that bit this session.

---

## The kill chain — what actually disables a PCIe device

| Layer | Mechanism | Survives reboot? | How to verify |
|-------|-----------|------------------|---------------|
| **rfkill** | `rfkill block wifi` / `nmcli radio wifi off` | Yes (NM re-applies on boot) | `rfkill list` → soft-blocked |
| **Driver unload** | `modprobe -r rtw88_core rtw88_pci rtw88_8822b rtw88_8822be` | No — dies at reboot | `lsmod \| grep rtw88` → empty |
| **Module blacklist** | `/etc/modprobe.d/blacklist-rtw88.conf` with `blacklist` + `install /bin/true` | Yes | File exists + `lsmod` stays empty after reboot |
| **udev bus-remove** | `ATTR{remove}="1"` on PCI add event | Yes | Device absent from `lspci`; `grep -rl ATTR{remove} /etc/udev/rules.d/` |
| **PCIe power state lock** | udev rule forcing `power/control=on` + `power/wakeup=enabled` | Yes | `cat /sys/.../power/control` → `on`, `power/wakeup` → `enabled` |
| **Boot cmdline `pci=rescan`** | Kernel re-scans PCI bus aggressively at boot | Yes (cmdline persists) | `cat /proc/cmdline \| grep pci=rescan` |

## The critical pitfall: `pci=rescan` fights a blacklist

`pci=rescan` tells the kernel to re-scan the PCI bus at boot and re-enumerate devices that weren't found in the normal probe window. **If you have `pci=rescan` in the boot cmdline AND a blacklist for the same device, you have the kernel actively hunting for a device you've told it to ignore.** The blacklist wins (the driver never binds), but the re-scan itself can cause PCIe chatter, and on flaky hardware it can resurrect ghosted devices you meant to keep dead.

**The rule:** when disabling a problematic PCIe device permanently, **strip `pci=rescan` from the boot cmdline**. The blacklist alone is sufficient to prevent the driver from loading; you don't need aggressive re-enumeration for a device you want gone.

### CachyOS + Limine two-tier config trap

On this machine (CachyOS, Limine bootloader), there are two config files:

| File | Role |
|------|------|
| `/etc/default/limine` | Source config — edited by hand, used when regenerating the ESP |
| `/boot/limine.conf` | ESP config — what the bootloader **actually reads** at boot |

Editing `/etc/default/limine` does **not** update `/boot/limine.conf`. After editing the source, either:
- Regenerate: `sudo limine --enroll-config` (syncs source → ESP)
- Or patch the ESP directly: `sudo sed -i 's/.../.../' /boot/limine.conf`

**Always verify the active cmdline** with `cat /proc/cmdline` — if the param isn't there, the ESP wasn't updated. This session stripped `pci=rescan` from both files but it was still showing in `/proc/cmdline` because the ESP config hadn't been regenerated after the earlier source edit.

## Inference warning: card absent from `lspci` ≠ card is dead or BIOS-disabled

When `lspci` doesn't show the device at all:
- It may be **physically present but ghosted** (PCIe power state D3cold + wakeup disabled — see `references/pcie-power-state-root-cause.md`)
- It may be **soft-killed by udev bus-remove rule** — the device is physically alive but vanished from the bus by software (`ATTR{remove}="1"`)
- It may be **dead hardware** (marginal M.2 contact, failed device)
- It may be **BIOS-disabled** (WLAN toggle in firmware)

**Check the kill chain before concluding hardware failure.** The absence of `pci=rescan` from the active cmdline is consistent with "we want this device gone" — not "we want it back."

## Current state of this machine's RTL8822BE disable chain

As of this session, the card is disabled via:

```
RFKILL        — soft-blocked (wifi)
MODPROBE      — blacklist-rtw88.conf (all 4 rtw88 modules blocked, install=/bin/true)
PCIE POWER    — card ghosted out of bus (no power-lock udev rule needed since device is gone)
BOOT CMDLINE  — pci=rescan STRIPPED from /etc/default/limine AND /boot/limine.conf
              BUT STILL PRESENT IN /proc/cmdline — ESP not regenerated after edits.
              The kernel is STILL scanning aggressively for the card.
SERVICE       — wifi-resurrect.service DISABLED and removed
UDEV RULES    — 99-rtl8822be-power-lock.rules + 99-rtl8822be-powersave.rules REMOVED
NM PROFILE    — "The Grid" connection REMOVED
```

**Growth point — the kill chain did not fully hold during this session.** Despite all of the above, the card resurrected: it was absent from `lspci` and modules were unloaded at one point, then reappeared with modules loaded at another. Root cause not definitively identified — `pci=rescan` was still in the active cmdline (ESP not regenerated after source edit), so the kernel was still aggressively re-enumerating. **Next-step hypotheses (not yet tried this session, may or may not work):**

1. **Regenerate the ESP** to actually strip `pci=rescan` from the active cmdline: `sudo limine --enroll-config`. Verify with `cat /proc/cmdline | grep pci=rescan` → must be absent.
2. **udev bus-removal rule** (`ATTR{remove}="1"` on PCI add for the device's vendor/device ID) — removes the device from the bus at the PCI level every time it appears, so it never gets a chance to generate errors. This is more aggressive than a driver blacklist (which only stops the driver, not the hardware). **Not tried this session** — do not present as a verified fix.
3. **If the card is physically malfunctioning** (generating correctable AER errors at the hardware level even without a driver bound), bus removal or physical removal is the only path that stops the hardware from being present on the bus. Driver blacklist alone is necessary but may not be sufficient. See the core pitfall in the SKILL.md body: "driver blacklist ≠ hardware silenced."

**Re-enable path (if user changes their mind)**

```bash
# 1. Remove blacklist
sudo rm /etc/modprobe.d/blacklist-rtw88.conf

# 2. Unblock rfkill
sudo rfkill unblock wifi
sudo nmcli radio wifi on

# 3. Rescan PCI bus (card is physically present, just ghosted)
echo 1 | sudo tee /sys/bus/pci/rescan

# 4. Verify
lspci -nnk | grep -A3 "04:00.0"   # should show vendor/device + driver
lsmod | grep rtw88                  # modules should load
rfkill list                         # should show no block
```

If the card doesn't reappear after rescan, check BIOS WLAN toggle and M.2 seating before assuming hardware death.
