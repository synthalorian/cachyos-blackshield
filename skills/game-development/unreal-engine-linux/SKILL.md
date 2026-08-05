---
name: unreal-engine-linux
description: Install, verify, and launch Unreal Engine on Linux (Arch/CachyOS) from Epic's prebuilt zip or source — verification checklist, smoke test, KDE desktop shortcut, pitfalls.
---

# Unreal Engine on Linux

How to get Unreal Engine + UnrealEditor running on a Linux desktop (CachyOS/Arch, KDE Plasma/Wayland, NVIDIA or Intel GPU).

## Rule 0: Check if it's already built BEFORE compiling

Epic's `Linux_Unreal_Engine_X.Y.Z.zip` download ships **prebuilt binaries** — it contains an `Engine/Source` tree but ALSO fully compiled `Engine/Binaries/Linux/` with a ready `UnrealEditor` ELF executable and thousands of `libUnrealEditor-*.so` modules. Users routinely assume "downloaded the zip = must build from source." A full source build takes hours and 100GB+; never start one without checking first:

```bash
ls <extracted>/Engine/Binaries/Linux/UnrealEditor   # exists + ELF executable => NO BUILD NEEDED
file <extracted>/Engine/Binaries/Linux/UnrealEditor  # "ELF 64-bit LSB executable, x86-64"
```

A genuine source-only checkout (GitHub EpicGames/UnrealEngine) has `Setup.sh` + `GenerateProjectFiles.sh` at the root and NO prebuilt `UnrealEditor` binary. That path needs `./Setup.sh && ./GenerateProjectFiles.sh && make` — only go there if the binary is absent.

## Verify extraction completed

```bash
pgrep -af "unzip|7z|bsdtar"        # no extractor still running
ls <dir>/Engine/                    # expect: Binaries Build Config Content Plugins Programs Shaders Source ...
du -sh <dir>                        # ~73G for 5.8.0 (from a ~40GB zip)
```

## Pre-flight system checks

```bash
ldd Engine/Binaries/Linux/UnrealEditor | grep "not found"   # empty = good
vulkaninfo --summary | grep deviceName                      # confirm GPU + vulkan driver
df -h . && free -h                                          # disk + RAM
```

Notes:
- UE editor runs under XWayland on Wayland sessions — works fine, no special config.
- 16GB RAM is workable but lean for UE5 editor; warn about swap on big projects.
- First launch stalls on shader compilation for a long while — that's normal, not a hang.

## Smoke test (headless-safe)

```bash
./Engine/Binaries/Linux/UnrealEditor-Cmd -version -stdout -unattended -nullrhi
```

Exit 0 with UnrealTrace server chatter in the log = runtime is healthy.

**PITFALL:** this smoke test creates `~/UnrealEngine/UnrealTrace/` as a side effect. If you then `mv <extracted-dir> ~/UnrealEngine`, the engine nests as `~/UnrealEngine/Linux_Unreal_Engine_X.Y.Z/` because the target dir already exists. Fix by moving contents up:

```bash
cd ~/UnrealEngine && shopt -s dotglob && mv Linux_Unreal_Engine_*/* . && rmdir Linux_Unreal_Engine_*
```

## Desktop integration (KDE)

Official Linux icon ships inside the tree:
`Engine/Source/Runtime/Launch/Resources/Linux/UnrealEngine.png`

Install a launcher at `~/.local/share/applications/unreal-editor.desktop` — copy `templates/unreal-editor.desktop` from this skill, adjusting the install path. Then:

```bash
chmod +x ~/.local/share/applications/unreal-editor.desktop
update-desktop-database ~/.local/share/applications/
kbuildsycoca6 --noincremental   # refresh KDE app db (kbuildsycoca5 on Plasma 5)
```

## Recommendations to give the user

- Install location: `~/UnrealEngine` (out of ~/Downloads; a 73G engine shouldn't live next to browser downloads).
- Delete the source zip after verification — it's another ~40GB.
- Known-good install this session: UE 5.8.0 prebuilt at `/home/synth/UnrealEngine`, GTX 1080 Ti + Intel UHD 630 both Vulkan-capable.

## Support files

- `templates/unreal-editor.desktop` — KDE launcher template; adjust Exec/Icon paths to the install root.
