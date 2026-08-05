---
name: pixel-flashing
description: Flash custom OS (GrapheneOS, etc.) on Google Pixel devices — bootloader management, AVB keys, fastboot/adb setup on Arch Linux.
triggers:
  - Pixel
  - GrapheneOS
  - fastboot
  - adb
  - bootloader unlock/lock
  - AVB custom key
  - avb_pkmd
  - verified boot warning
  - yellow warning screen
  - orange warning screen
  - "your device is loading into another operating system"
  - Pixel 8a
  - akita
  - USB device busy
  - "waiting for any device"
  - WebUSB
  - Chromium browser blocking fastboot
---

# Pixel Flashing

Flash custom OS builds on Google Pixel devices using fastboot/adb from Arch Linux.

## Prerequisites (Arch Linux)

```bash
# Tools
sudo pacman -S android-tools

# udev rules for non-root access
sudo pacman -S android-udev
# Unplug/replug device or reboot after installing
```

## Factory Image URLs

GrapheneOS images are served from `https://releases.grapheneos.org/` with the naming pattern:

- **Install package**: `{device}-install-{build}.zip` (contains everything needed)
- **OTA update**: `{device}-ota_update-{build}.zip`
- **Signature**: `{device}-install-{build}.zip.sig`

Device codenames: `akita` (Pixel 8a), `shiba` (Pixel 8), `husky` (Pixel 8 Pro), `tokay` (Pixel 9), etc.

**Do NOT use `-factory-`** in the URL — the install package is the correct one for extraction.

Check device build on phone:
```bash
adb shell getprop ro.build.version.incremental
```

## AVB (Android Verified Boot) Custom Key

The yellow "your device is loading into another operating system" screen appears on every boot with a locked bootloader and no custom AVB key enrolled.

### Extract the key

The AVB key (`avb_pkmd.bin`) is inside the install ZIP:
```bash
unzip -o {device}-install-{build}.zip "*/avb_pkmd.bin" -d /tmp/grapheneos_avb
```

### Flash the key

**This requires the bootloader to be UNLOCKED first** (which wipes all data):

```bash
# 1. Reboot to bootloader
adb reboot bootloader

# 2. Unlock (WIPES ALL DATA)
fastboot flashing unlock
# Confirm on phone screen with volume keys + power

# 3. Flash AVB key (phone will be in fastboot mode)
fastboot erase avb_custom_key
fastboot flash avb_custom_key /path/to/avb_pkmd.bin

# 4. Lock bootloader
fastboot flashing lock
# Confirm on phone screen

# 5. Reboot
fastboot reboot
```

## Bootloader Operations

| Action | Command | Notes |
|--------|---------|-------|
| Check state | `fastboot getvar unlocked` | Returns `yes`/`no` |
| Check locked | `fastboot getvar locked` | Returns `yes`/`no` |
| Unlock | `fastboot flashing unlock` | **WIPES ALL DATA** |
| Lock | `fastboot flashing lock` | Safe after AVB key is set |
| Flash AVB key | `fastboot flash avb_custom_key avb_pkmd.bin` | Requires unlocked bootloader |
| Erase old AVB key | `fastboot erase avb_custom_key` | Run before flash |

## Common Pitfalls

### "device already locked" — locked but still seeing yellow warning

If `fastboot flashing lock` returns "device already locked" but the yellow warning persists, the issue is **NOT the bootloader state** — it's that the **AVB custom key was never enrolled**. This is a different problem from an unlocked bootloader:

| Screen color | Message | Cause |
|-------------|---------|-------|
| **Orange** | "Your device is unlocked and can't be trusted" | Bootloader is actually unlocked — dangerous |
| **Yellow** | "Your device is loading into another operating system" | Bootloader locked but no AVB custom key enrolled — safe but annoying |

If you see yellow, DON'T try `fastboot flashing lock` again — it's already locked. The fix is to **unlock → flash AVB key → relock** (which wipes data — see below).

### fastboot devices works but commands hang ("< waiting for any device >")

This means the device is on the USB bus but something's between it and the fastboot driver. Causes and fixes:

- **🔴 Chromium browser WebUSB lock** — If the user used the GrapheneOS web installer, Brave/Chrome/Edge holds a permanent USB device lock. `fastboot devices` shows the device but every command hangs. **Fix**: find and kill the browser process:
  ```bash
  # Find what's holding the USB device
  lsusb | grep -i google  # Note bus/device numbers
  sudo lsof /dev/bus/usb/<BUS>/<DEVICE>
  # Kill the locking process
  kill <PID>
  ```
- **Replug USB**: unplug and reconnect the cable
- **Different USB port**: try a rear port (desktop) or a different port (laptop)
- **Different cable**: use the cable that came with the phone
- **Try `sudo`**: `sudo fastboot <command>` — udev rules may not have taken effect
- **Kill stale adb**: `sudo adb kill-server` then retry
- **fwupd interference**: `sudo systemctl stop fwupd` if installed

### Unlocking wipes data

Always. Full factory reset — apps, accounts, photos, everything. There is no way around this. Set up the phone fresh after, re-enable USB debugging, then flash the AVB key before relocking.

### Yellow warning on Pixel 8+

The yellow "loading different OS" screen with a **"Pause" option** is standard Android Verified Boot (AVB) behavior on all Pixels running any non-Google OS with a locked bootloader. It adds ~5 seconds to boot and is completely harmless. The boot-chain warning appears even on Pixel 8+ with a properly enrolled AVB key on some firmware versions.

### Which build to download

The install ZIP uses `-install-` not `-factory-` in the URL. The minor version (e.g. `2026050901` vs `2026050900`) matters — download the one matching the phone's build number:

```bash
adb shell getprop ro.build.version.incremental
# Then fetch: https://releases.grapheneos.org/akita-install-{build}.zip
```

The AVB key file inside is `avb_pkmd.bin` (not `.img`). It's the same partition to flash (`avb_custom_key`):
