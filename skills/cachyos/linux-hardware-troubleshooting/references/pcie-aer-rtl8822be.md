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

## Epilogue (2026-08-05): card confirmed DEAD, not config-sick

Resurrection attempt (BIOS re-enable + unblacklist + `pcie_aspm=off` + `rtw88_pci disable_aspm=y` + forced D0 + reset/unbind/rebind + PSU-drain cold boot) all failed at **"failed to power on mac"** / "failed to download firmware" (probe errors -114/-16), with intermittent non-enumeration and fatal AER on rescan. The July storm was the first hardware-death symptom, not a config issue. Notably `pcie_aspm=off` kept bus AER counters at ZERO even with the dying card present — correct storm prophylaxis.

Final state: card triple-buried (driver blacklist + udev bus-remove rule + pcie_aspm=off on limine active entries). Bonus lesson: the I219-V ethernet was ALSO dying (link partner advertising only 10baseT → 10Mb/s) — check `ethtool` "Link partner advertised link modes" when speeds crater. Machine runs on Pixel USB tethering (RNDIS shows as `enp0s20f0uXXiY` ethernet, zero config needed) until a USB/PCIe NIC is affordable.

## Second epilogue (2026-08-11): card REVIVED, storm prevention stack deployed

Six days after being declared dead, the card enumerated and associated cleanly (user removed blacklist + udev rule; BIOS toggle uncertain). Revived-after-death = classic marginal-contact behavior; expect it to flap again someday — reseat + clean M.2 contacts at next case-open.

Prevention stack (target the trigger — power-state transitions on a marginal link):
1. `rtw88_pci disable_aspm=y` (modprobe.d) — link ASPM Disabled both ends ✓
2. L1 PM Substates negotiated off ✓ (verify: `lspci -vv -s 04:00.0 | grep L1SubCtl1` — all minus)
3. 802.11 power save OFF: `/etc/NetworkManager/conf.d/99-wifi-powersave-off.conf` (`[connection] wifi.powersave = 2`) + live `iw dev wlan0 set power_save off`
4. `pcie_aspm=off` global — epilogue-proven ("kept bus AER counters at ZERO even with the dying card present"). **Persistent path: add to `KERNEL_CMDLINE[default]` in `/etc/default/limine`** so limine-entry-tool regeneration on kernel updates keeps it — hand-edits to /boot/limine.conf get dropped (same pitfall as the EDID override).
5. Diagnostic gotcha: `lspci -t` FIRST when AER appears — this boot's trickle (17/hr) was root port 00:1c.6 = ASMedia ASM2142 USB 3.1 controller (chatty chip, harmless noise), NOT the WiFi under 00:1c.2. Speed mismatch between root port LnkSta and suspected device is the tell that you're looking at the wrong device.
