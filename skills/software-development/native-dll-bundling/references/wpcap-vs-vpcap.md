# wpcap.dll vs vpcap.dll — Npcap SDK Version Mapping

## Overview

The Npcap SDK ships a different runtime DLL name depending on the SDK version. The `pcap` crate links against whichever is present at compile time, and the same DLL must be loadable at runtime via `LoadLibrary`.

## DLL Name Variants

| SDK version range | Runtime DLL | Notes |
|-------------------|-------------|-------|
| Older Npcap SDK (≤ 1.10 era) | `wpcap.dll` | Original Npcapname |
| Newer Npcap SDK (1.11+) | `vpcap.dll` | "V" variant — same functionality, renamed |

The transition happened as Npcap evolved. Newer SDK downloads from npcap.com ship `vpcap.dll` in `Lib\x64\`. Older SDK archives may still ship `wpcap.dll`.

## Why Both Names Matter

If you hardcode one DLL name and the SDK (or a user's installed Npcap) provides the other:
- The Rust `pcap` crate's `build.rs` links against whichever is in the SDK's `Lib\x64` at compile time — this works regardless of name.
- At runtime, the `.exe` calls `LoadLibrary("wpcap.dll")` or `LoadLibrary("vpcap.dll")` depending on how the crate was configured. If the DLL on disk has a different name, `LoadLibrary` fails.
- Result: the app starts, claims to be ready, but packet capture silently does nothing.

## The Fix

Always handle both variants:

1. **Post-build script** — check for `vpcap.dll` first (newer), fall back to `wpcap.dll`. Copy whichever exists into `frontendDist`.
2. **`additionalFiles`** — list both DLL names. Tauri's bundler silently skips the one not present in `frontendDist`.

```js
// Prefer vpcap.dll (newer), fall back to wpcap.dll
bundled = bundleDllIfPresent('vpcap.dll') || bundleDllIfPresent('wpcap.dll');
```

```jsonc
// additionalFiles lists both — bundler picks whichever is present
"additionalFiles": ["vpcap.dll", "wpcap.dll"]
```

## Detection on a Target Machine

If a Windows user reports packet capture not working:

1. Check which DLL is installed alongside the app: `dir /b *.dll` in the install directory.
2. Check which DLL Npcap (if installed system-wide) provides: `dir "C:\Program Files\Npcap\*.dll"`.
3. Compare against what the app was built with. If they don't match, rebuild with the matching SDK or bundle both DLLs.

## CI SDK Version Pinning

Pin the Npcap SDK version in CI so the runtime DLL name is predictable:

```yaml
- name: Install Npcap SDK (Windows)
  shell: pwsh
  run: |
    # Pin to a known SDK version — do NOT use latest/unversioned URL
    Invoke-WebRequest -Uri "https://npcap.com/dist/npcap-sdk-1.13.zip" -OutFile "npcap-sdk.zip"
    Expand-Archive npcap-sdk.zip -DestinationPath C:\npcap-sdk
```

Check the SDK's `Lib\x64` after extraction to confirm which DLL it ships:

```powershell
# In CI, after extraction
Get-ChildItem "C:\npcap-sdk\Lib\x64" -Filter "*.dll" | Select-Object Name
# Expected output: either wpcap.dll or vpcap.dll — adapt the post-build script accordingly
```

## References

- `references/tauri-additional-files-pitfalls.md` — how `additionalFiles` resolves DLL paths and the silent-skip behavior.
