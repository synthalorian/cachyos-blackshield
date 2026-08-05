# Star Citizen on Linux — RDNA 4 Specific Findings

## Environment

| Component | Value |
|-----------|-------|
| Game version | 4.8.0 (Build 11825000, May 12 2026) |
| GPU | AMD Radeon RX 9070 XT (RADV GFX1201) |
| Mesa | 26.0.6 (vulkan-radeon) |
| DXVK | 2.7.1 (via lug-wine-tkg-git-11.8-1 runner) |
| Kernel | 7.0.3-arch1-2 |
| Memory | 32GB, 45GB swap (30GB file + 15GB zram) |

## GPU Crash Signature

```
VK_WARNING vkQueueSubmit() failed (VK_ERROR_DEVICE_LOST)
GPU crash message: GPU Crash Vulkan ( async ): AMD - Device Lost - RenderPass [Unknown]
```

**Crash message suggestions:**
```
Raise r_gpuMarkers value for increased coverage.
Consider enabling r_vulkanCPUValidation or r_RenderGraph_ImmediateMode
and r_enable_full_gpu_sync = 2.
```

## Memory Pressure Pattern

Star Citizen on DXVK exhibits severe memory commit inflation:

| Metric | Value |
|--------|-------|
| Min commit | 25,086 MB |
| Max commit | 28,942 MB |
| Free RAM at crash | 2,624 MB out of 31,159 MB |
| Working set | 2,070 MB min, 23,861 MB max |

**Observation:** First session of the day is lower memory (20-21GB commit, 113 FPS). Second session builds up to 28-29GB commit (54 FPS) and crashes. Suggests a memory leak that accumulates across sessions — or different game areas load differently.

## Historical Session Performance (Same Build, Same Driver)

| Date | FPS | Commit Memory | Crashes |
|------|-----|---------------|---------|
| May 15 evening | 79.3 | 18.4-24.8 GB | 0 |
| May 16 morning | 48.4-99.1 | 19.6-36.9 GB | 0 |
| May 17 late | 73.4-101.6 | 19.0-27.1 GB | 0 |
| May 18 session 1 | 113.8 | 20.0-21.6 GB | 0 |
| May 18 session 2 | 54.1 | 25.0-28.9 GB | **1 (GPU crash)** |

## Mitigations to Try

1. **Create user.cfg** with memory/performance limits
2. **Add dxvk.conf** with `dxvk.numCompilerThreads=1` or `dxvk.enableAsync=true`
3. **Monitor GPU** during gameplay with MangoHud
4. **Reduce graphics settings** (especially clouds, volumetric fog, object detail)
5. **Use a swap file on fast NVMe** (already configured — 45GB swap)
6. **Close browser** before extended sessions (Brave GPU process competes)
7. **Restart the game** between long sessions to reset memory state
