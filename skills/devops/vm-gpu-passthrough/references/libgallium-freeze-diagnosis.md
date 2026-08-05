# libgallium GPU Freeze — Session 2026-05-13 Crash Analysis

## System
- Omarchy (Arch + Hyprland)
- AMD dual-GPU desktop (RX 7800M/7900M 16GB + secondary DCN 3.1.5)
- PipeWire 1.6.4, Mesa 26.0.6
- libvirt/QEMU installed, no VM defined yet

## Crash Evidence (boot -1, 17:21:39)

Multiple threads in libgallium stuck in `pthread_cond_wait`:

```
Stack trace of thread 1604:
  #0 0x00007fd9c38a0a52 n/a (libc.so.6 + 0xa0a52)
  #3 0x00007fd9c389766c pthread_cond_wait (libc.so.6 + 0x9766c)
  #4 0x00007fd9bb9ecb1e n/a (libgallium-26.0.6-arch1.1.so + 0x5ecb1e)
  #5 0x00007fd9bb9a1ebd n/a (libgallium-26.0.6-arch1.1.so + 0x5a1ebd)
  #6 0x00007fd9bb9eca5d n/a (libgallium-26.0.6-arch1.1.so + 0x5eca5d)
  #7 0x00007fd9c38981b9 n/a (libc.so.6 + 0x981b9)
  #8 0x00007fd9c391d21c n/a (libc.so.6 + 0x11d21c)
```

This repeated across threads 1604, 1611, 397011, 397013, 397015, 397016, 397017.

## Trigger
User changed GPU swap/assignment settings while launching a Windows VM. The host's Mesa/amdgpu stack was still actively using the dGPU when the VM reassigned it.

## Key Findings

1. `vga_switcheroo` detected ATPX switching method despite being a DESKTOP system. Motherboard AMI BIOS exposes this. It sits idle unless triggered.

2. System crashed at ~17:21:39. First shutdown logs appear at 17:21:56. No config file modifications in that window.

3. Post-crash audit found ZERO persistent artifacts:
   - `/etc/libvirt/qemu/` empty of guest XMLs
   - No vfio.conf or kvm.conf in /etc/modprobe.d/
   - No VFIO modules in mkinitcpio
   - No GRUB changes (amd_iommu, vfio-pci.ids)
   - No libvirt hooks directory
   Conclusion: settings were transient UI state only, never persisted to disk

## Recovery
Clean reboot restored system. No manual intervention needed because no config existed on disk to clean up.

## Boot Comparison Table
| Boot | Date | Duration | GPUs | Crash? |
|------|------|----------|------|--------|
| -2 | May 12 14:18 | ~11h | amdgpu OK | No |
| -1 | May 13 11:33 | ~5h49m | amdgpu OK → libgallium freeze | YES |
| 0 | May 13 17:23 | current | amdgpu OK | No |

Both boot -1 and boot 0 show identical GPU initialization logs. The only difference: boot -1 had an active GPU reassignment attempt mid-session.