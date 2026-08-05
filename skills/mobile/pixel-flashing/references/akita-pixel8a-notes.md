# Pixel 8a (akita) — Session Notes

## Device
- **Codename**: akita  
- **Model**: Pixel 8a  
- **Bootloader version**: akita-16.4-14540574  

## Build
- **Incremental**: 2026050901  
- **Slot B** (bootable), Slot A marked unbootable  
- **AVB hastree error mode**: restart  

## Install ZIP URL
```
https://releases.grapheneos.org/akita-install-2026050901.zip
https://releases.grapheneos.org/akita-install-2026050901.zip.sig
```

Pattern is `{codename}-install-{build}.zip` — NOT `-factory-`.

## AVB Key
- Inside ZIP at: `akita-install-2026050901/avb_pkmd.bin`
- Partition to flash: `avb_custom_key` (not `avb_pkmd`)
- Key size: 1032 bytes

## Browser USB Lock
After using the GrapheneOS web installer, Brave (and any Chromium browser) holds the USB device via WebUSB. This causes `fastboot devices` to show the device but every command to hang with `< waiting for any device >`.

**Detection**: `sudo lsof /dev/bus/usb/<BUS>/<DEVICE>` shows `brave` (or `chrome`, `chromium`) holding the FD.

**Fix**: Kill the browser process. The device reconnects instantly.

## Boot Flow Observed
1. Power button → Google G logo (briefly)
2. Yellow "your device is loading into another OS" screen (~5s, has "Pause" option)
3. OS boots (GrapheneOS)
