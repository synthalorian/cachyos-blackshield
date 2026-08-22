# AER Correctable-Error Masking Playbook (root port setpci)

For BURSTY correctable-error devices that don't warrant bus removal (ports in
use, or an empty controller you might use later). Masks error *reporting* —
the hardware keeps working, the CPU stops eating interrupt/log storms.

Concrete case: ASMedia ASM2142 USB controller (06:00.0, behind root port
00:1c.6) on synthesis, 2026-08-11. Empty add-on controller (no USB devices on
its buses) bursting RxErr in clusters correlated with desktop lag. WiFi card
(rtw88, 04:00.0) was INNOCENT — check which port the errors attribute to
before blaming the usual suspect.

## Steps

1. **Confirm the storm + attribute the port** (no sudo needed):
   ```bash
   for f in /sys/bus/pci/devices/*/aer_dev_correctable; do
     d=$(dirname $f); echo "$(grep PCI_SLOT_NAME $d/uevent) $(cat $f | tr '\n' ' ')"
   done
   # Read TOTAL_ERR_COR twice 5s apart on the suspect — frozen = historic,
   # climbing = active storm.
   lspci -tv | grep -B1 -A1 "<port>"   # what hangs off the port
   ```
2. **Read the correctable-error mask** on the ROOT PORT (not the device):
   ```bash
   sudo setpci -s 00:1c.6 ECAP_AER+0x14.l    # e.g. 00002000
   ```
   Bit 0 = Receiver Error (RxErr) reporting. Clear = errors reported.
3. **Mask it, preserving other bits** (old_value | 0x1):
   ```bash
   sudo setpci -s 00:1c.6 ECAP_AER+0x14.l=00002001
   sudo setpci -s 00:1c.6 ECAP_AER+0x14.l    # verify readback = 00002001
   ```
4. **Persist via systemd oneshot** (setpci doesn't survive reboot). Write
   `/etc/systemd/system/aer-mask-<device>.service` WITH an incident header
   comment (what/why/how to undo):
   ```ini
   # <device> RxErr AER storm prophylaxis — <incident> (<date>)
   # Undo: systemctl disable --now aer-mask-<device>
   [Unit]
   Description=Mask AER RxErr reporting on <port>
   After=multi-user.target
   [Service]
   Type=oneshot
   ExecStart=/usr/bin/setpci -s <slot> ECAP_AER+0x14.l=<value>
   RemainAfterExit=yes
   [Install]
   WantedBy=multi-user.target
   ```
   `systemctl daemon-reload && systemctl enable --now aer-mask-<device>`

## Watchdog (catches NEW stormers, not just the known one)

Track the SUM of TOTAL_ERR_COR across ALL PCIe devices per tick; alert when
delta exceeds a threshold (50/5min worked). Silent when healthy. Names the
climbing port in the alert so the user knows which device to blame. On
synthesis this runs as a Hermes no_agent cronjob (`aer-watchdog.sh`,
5 min) with notify-send for local desktop alerts.

## Escalation

Masking only silences *correctable* reporting. If errors turn uncorrectable,
or the device is genuinely dead and unneeded, escalate to the bus-removal
ladder in the main skill (udev `ATTR{remove}="1"` by vendor/device ID).
