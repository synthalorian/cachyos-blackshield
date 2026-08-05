# EDID override — forcing a custom "native" panel mode (verified 2026-08)

Use when the NVIDIA driver rejects custom display modes on Wayland and the mode
must exist at the PANEL level (desktop, KWin, all apps) — not just inside a
gamescope. For game-only resolution tricks (gamescope flags, centering quirk,
Unity launcher behavior), see `references/gamescope-custom-game-resolutions.md`.

Hardware/stack verified: GTX 1080 Ti, nvidia-drm 580.173.02, KWin 6.7 Wayland,
limine bootloader, SKG 2560x1440@165 monitor on HDMI-A-1.

## Why the easier paths fail (verified, don't retry)

- `kscreen-doctor addCustomMode` → mode registers, apply fails:
  "The driver rejected the output configuration". Even standard 2560x1080 rejected.
- Kernel `video=HDMI-A-1:2560x800@60` cmdline → reaches /proc/cmdline but
  nvidia-drm never applies it (no "user-specified mode" line in dmesg), and
  KWin re-applies its stored kwinoutputconfig.json mode at login regardless.
- Hand-edited `customModes` in kwinoutputconfig.json → schema valid
  (`{"width":W,"height":H,"refreshRate":mHz,"flags":0}`) but only read at KWin
  startup; driver still rejects on apply.

## The override recipe (WORKS)

1. Dump: `cp /sys/class/drm/card1-HDMI-A-1/edid /tmp/edid-orig.bin`
   (find the card prefix via `ls /sys/class/drm/`; 256 bytes = base + CTA ext).
2. Timings: `cvt 2560 800 60` →
   `167.25 2560 2696 2960 3360 800 803 813 831 -hsync +vsync`
3. Build the 18-byte DTD from the modeline (clock in 10kHz LE, hact/hblank,
   vact/vblank with hi-nibble packing, sync offsets/widths + hi bits, image
   size mm, flags 0x18 for digital separate -hsync +vsync). For this panel the
   exact bytes were: `55 41 00 20 A3 20 1F 30 88 08 3A 10 55 50 21 00 00 18`
   (kept the original 597x336mm image-size bytes).
4. Replace DTD1 (bytes 54–71 of the base block), recompute checksum:
   `byte[127] = (-sum(bytes[0..126])) % 256`. Leave extension blocks (128+)
   untouched — their checksums stay valid.
5. Validate: `edid-decode patched.bin` → expect
   `DTD 1: 2560x800 59.9 Hz 16:5 ... (597 mm x 336 mm)`.
6. Install: `sudo mkdir -p /usr/lib/firmware/edid && sudo cp patched.bin /usr/lib/firmware/edid/<name>.bin`
7. Cmdline: `drm.edid_firmware=HDMI-A-1:edid/<name>.bin` in limine.conf — edit
   BOTH `/boot/limine.conf` and the repo copy
   `~/Projects/active/cachyos-setup/configs/limine/limine.conf`
   (handoff-post-reboot.sh syncs repo→/boot; editing only /boot gets reverted).
8. Check `/etc/mkinitcpio.conf`: `MODULES=()` empty = nvidia loads post-root so
   /usr/lib/firmware is available. If nvidia were baked into initramfs, the
   firmware would need FILES() + rebuild.
9. Reboot. First DTD = preferred mode → KWin auto-selects it. Monitor OSD
   aspect/scaling controls stretch vs 1:1 letterbox.

Result on this box: `kscreen-doctor` shows HDMI-A-1 geometry 2560x800; Unity
reports `Display 0 'HDMI-A-1 32"': 2560x800`.

Safety: other outputs untouched. Revert = restore limine.conf `.bak` + delete
the firmware file + reboot.
