---
name: arch-kernel-upgrade-fallout
description: "Use when hardware dies after a kernel update without reboot."
metadata:
  hermes:
    tags: [arch, cachyos, kernel, limine, troubleshooting, reboot]
---

# Arch/CachyOS Kernel-Upgrade Fallout

Class of breakage: something worked this morning, a system update ran, now it's dead — and nothing in the app's config changed. On Arch, suspect the kernel update first.

## Signature

- `pacman -Syu` upgraded `linux-cachyos` (check `/var/log/pacman.log` timestamps) **while the machine kept running** (`uptime -s` predates the update).
- The update **removes the old kernel's module tree**: `/lib/modules/$(uname -r)` no longer exists or is incomplete.
- Anything needing a **not-yet-loaded** kernel module fails with `FATAL: Module <x> not found in directory /lib/modules/<running-kernel>`. Already-loaded modules keep working, so the breakage looks random and feature-specific.

## Diagnostic sequence (fast, do in order)

```bash
uname -r                          # running kernel
pacman -Q linux-cachyos           # installed kernel — mismatch = smoking gun
ls /lib/modules/                  # running kernel's tree gone?
uptime -s                         # boot predates the update?
grep 'upgraded linux-cachyos' /var/log/pacman.log | tail -2
```

Real case (2026-08-11): Pixel USB tethering died right after a 13:08 kernel update (7.1.6→7.1.8). Kernel log showed the phone enumerating as `18d1:4ee7` (RNDIS mode) then bouncing back to `4eec` with no interface — because `rndis_host` couldn't load: modules for 7.1.6 were already deleted. Fix was the reboot the update already wanted.

**Tether-specific detail:** USB IDs tell the mode — `18d1:4eec` = Pixel MTP (file transfer), `18d1:4ee7` = RNDIS tethering. If the phone flips to 4ee7 and back within ~2s with no `usb0`/rndis lines in the kernel log, the host side has no driver — it's not the phone, the cable, or NetworkManager.

## Fix

Reboot into the new kernel. Verify the module exists in the NEW tree before promising it works:

```bash
ls /lib/modules/<new-kernel>/kernel/drivers/net/usb/ | grep rndis   # etc.
```

## Limine boot-entry fallout (second, sneakier half)

Kernel updates also regenerate **one** active limine entry via `limine-entry-tool`, dropping any hand-added cmdline params **there** while other active entries keep them. On synth's machine this drops `drm.edid_firmware=HDMI-A-1:edid/skg-2560x1080.bin` (the 21:9 EDID override) every kernel.

- Check the ACTIVE entries only (they contain `rootflags=subvol=/@ root=`; snapshots contain `/@/.snapshots/`): `grep -F 'rootflags=subvol=/@ root=' /boot/limine.conf | grep -v snapshots`. A param surviving on ONE entry fools plain grep — check **every** active line, and remember `/proc/cmdline` tells you which entry actually booted.
- Re-apply with `~/Projects/active/this-is-the-wide/scripts/install.sh` (fixed 2026-08-11 to be per-line idempotent — the old any-match grep skipped the regenerated entry you actually boot).
- **Durable fix (deployed 2026-08-11): put params in the SOURCE, not the entries.** `limine-entry-tool` rebuilds entries from `KERNEL_CMDLINE[default]` in `/etc/default/limine` — params there survive every kernel update with zero re-application. `pcie_aspm=off` and `drm.edid_firmware=HDMI-A-1:edid/skg-2560x1080.bin` both live there now (backed up as `configs/limine/default-limine` in cachyos-blackshield, deployed by install.sh). Check first: `grep CMDLINE /etc/default/limine`. Hand re-application is now only needed for params deliberately kept OUT of the default cmdline.
- The EDID bin itself (`/usr/lib/firmware/edid/skg-2560x1080.bin`) survives updates; it does NOT need to be in the initramfs on this setup (firmware loads after root mount).

## Pitfalls

- Don't chase the app. When NM profiles, udev rules, and modprobe blacklists all look right but the module file simply doesn't exist, stop — it's the kernel mismatch, not config.
- `dmesg` may be restricted; use `journalctl -k --no-pager` instead.
- `plasmashell --replace` from an agent terminal can SIGABRT and silently not replace the shell (see terminal-theming skill) — same class of "the obvious command didn't actually do it." Always verify with PID start time: `ps -o lstart= -p $(pgrep -x plasmashell)`.
