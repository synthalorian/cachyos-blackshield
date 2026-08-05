---
name: vm-gpu-passthrough
category: devops
description: Diagnose and safely configure VM GPU passthrough on Arch/Hyprland — crash recovery, libgallium freeze patterns, persistent vs transient config detection.
---

# VM GPU Passthrough — Crash Diagnosis & Safe Configuration

## When To Use

VM GPU assignment crashes, libvirt VFIO setup, GPU switching freezes, vga_switcheroo / ATPX confusion.

## Crash Diagnosis Flow

When a Linux host crashes/freeze after changing VM GPU assignment:

1. **Check journalctl across boots for libgallium freeze**:
   ```
   journalctl -b -1 --no-pager | grep -iE "libgallium|pthread_cond_wait"
   ```
   Multiple threads in `pthread_cond_wait` inside `libgallium-*.so` = GPU driver hung because a resource was reassigned out from under Mesa.

2. **Check for vga_switcheroo / ATPX**:
   ```
   journalctl -b | grep -iE "vga_switcheroo|ATPX|switcheroo"
   ```
   Presence does NOT mean laptop. Desktop AMI/UEFI firmware also exposes ATPX switching methods. It's harmless unless something actively triggers a switch.

3. **Audit persistent configs** — distinguish saved config from transient UI state:
   ```
   ls /etc/libvirt/qemu/           # VM XML — must exist to be real
   find /etc/modprobe.d/ -name "vfio*" -o -name "kvm*"
   cat /etc/default/grub | grep -iE "vfio|amd_iommu"
   grep MODULES /etc/mkinitcpio.conf
   ls /etc/libvirt/hooks/ 2>/dev/null
   ```
   Empty `/etc/libvirt/qemu/` + no modprobe/GRUB changes = nothing persisted. The crash happened mid-setup, before config hit disk.

4. **Identify the trigger**: Multiple Mesa threads frozen → GPU resource hijack. This only happens when VM assignment runs *while the display server is active*.

## Safe GPU Passthrough Sequence

Never dynamically swap GPUs while Hyprland/Wayland is running.

```
# 1. Stop display server
systemctl isolate multi-user.target

# 2. Unbind GPU from amdgpu
echo "0000:XX:YY.0" > /sys/bus/pci/drivers/amdgpu/unbind

# 3. Bind to vfio-pci
modprobe vfio-pci
echo "VVVV DDDD" > /sys/bus/pci/drivers/vfio-pci/new_id

# 4. Start VM
virsh start windows-vm

# 5. After VM stops — reverse the process
# unbind from vfio → bind to amdgpu → systemctl isolate graphical.target
```

## Pitfalls

- **vga_switcheroo/ATPX on desktop**: Motherboard firmware exposes it. Harmless until triggered. Don't assume laptop form factor from kernel detection.
- **Crash during mid-setup**: If system froze while configuring GPU passthrough in virt-manager wizard (didn't click Finish), no config exists on disk. Zero artifacts to revert.
- **libgallium freeze = GPU mid-session hijack**: Threads in `pthread_cond_wait` inside `libgallium` means the host GPU driver lost access. Clean reboot required.
- **No XML = no VM**: Without a definition in `/etc/libvirt/qemu/`, the VM is just UI state. Mid-wizard crashes leave nothing on disk.

## References

- `references/libgallium-freeze-diagnosis.md` — crash analysis from session 2026-05-13