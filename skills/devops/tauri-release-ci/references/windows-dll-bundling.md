# Windows runtime DLL bundling — end-to-end pattern (Tauri v2)

Concrete reference for shipping a native DLL (`wpcap.dll` / `vpcap.dll`) inside a Tauri Windows NSIS release so packet capture (or any `LoadLibrary`-dependent crate) works on a clean machine without the user installing Npcap. Validated on the Albion Online Translator, Tauri v2, NSIS target.

## Problem

CI installs the Npcap SDK import library so the Rust `pcap` crate links (the `.lib`), but the end-user `.exe` still can't `LoadLibrary` the DLL on a machine that never installed Npcap. The DLL was only available at compile time, never packaged. The `.exe` runs, but capture silently fails at runtime.

## The SDK zip does NOT contain the runtime DLL

The Npcap SDK zip (`npcap-sdk-1.13.zip` and similar) only contains `.lib` import libraries + headers. It does **NOT** contain `wpcap.dll` or `vpcap.dll`. The runtime DLLs only ship inside the Npcap installer `.exe` (`https://npcap.com/dist/npcap-1.78.exe`).

This is why copying from `C:\npcap-sdk\Lib\x64` alone produces zero-byte placeholders — there's nothing to copy. You must extract the DLL from the Npcap installer.

## Two independent steps (both required)

### Step A — extract the real DLL and copy it into `src-tauri/resources/`

The DLL must end up in `src-tauri/resources/` (relative to the Tauri project root, NOT the frontend `build/` directory). The bundler walks `src-tauri/resources/` when `bundle.resources` lists them.

Hook the copy into `npm run build` via a post-build script (e.g. `scripts/fix-paths.cjs`) that already runs after Vite writes `build/index.html`. The script:

- Reads the SDK root from `NPCAP_SDK_PATH` env var, or falls back to `C:\\npcap-sdk` on Windows.
- Looks in `<SDK_ROOT>/Lib/x64` for whichever **non-empty** DLL variant actually landed there.
- Copies it into `src-tauri/resources/` under its real name.
- **Only copies non-empty files** — CI runs that miss the DLL must not write zero-byte placeholders (Tauri v2 will reject them at bundle time, or worse, package an empty file).
- On non-Windows platforms, the DLL won't exist — either skip silently (the bundler only ships what's there) or remove stale placeholders from a previous Windows run.

The `npm run build` script in `package.json` should be:

```json
"build": "vite build && node scripts/fix-paths.cjs"
```

### Step B — tell the Tauri v2 bundler to include the DLL

Add it to `src-tauri/tauri.conf.json` under **`bundle.resources`** (NOT `bundle.additionalFiles` — that key does not exist in Tauri v2):

```json
"bundle": {
  "resources": ["resources/vpcap.dll", "resources/wpcap.dll"]
}
```

Paths in `bundle.resources` are relative to the **Tauri project root** (where `tauri.conf.json` lives), so `resources/vpcap.dll` means `src-tauri/resources/vpcap.dll`. The bundler packages any listed resource that exists into the app package, next to the `.exe`.

**`bundle.additionalFiles` is a Tauri v1 field.** It was rejected by the Tauri v2 schema with `'additionalFiles' was unexpected`. Use `bundle.resources` instead.

## CI workflow: extract the DLL from the Npcap installer

The Windows CI step must do **both**:

1. Download + extract the Npcap SDK zip → `C:\npcap-sdk` (provides `wpcap.lib` so the Rust `pcap` crate links).
2. Download the Npcap installer `.exe` → extract the real `wpcap.dll` into `C:\npcap-sdk\Lib\x64` so `fix-paths.cjs` can find it.

Example (PowerShell, Windows runner, 7z available):

```yaml
- name: Install Npcap SDK + extract runtime DLL (Windows)
  if: runner.os == 'Windows'
  shell: pwsh
  run: |
    # 1. SDK import library
    Invoke-WebRequest -Uri "https://npcap.com/dist/npcap-sdk-1.13.zip" -OutFile "npcap-sdk.zip"
    Expand-Archive npcap-sdk.zip -DestinationPath C:\npcap-sdk
    "LIB=C:\npcap-sdk\Lib\x64;$env:LIB" | Out-File -FilePath $env:GITHUB_ENV -Append
    "NPCAP_SDK_PATH=C:\npcap-sdk" | Out-File -FilePath $env:GITHUB_ENV -Append

    # 2. Extract the real runtime DLL from the Npcap installer
    Invoke-WebRequest -Uri "https://npcap.com/dist/npcap-1.78.exe" -OutFile "npcap-installer.exe"
    & 7z x npcap-installer.exe -o"C:\npcap-dll" -r "*.dll" -y
    $libDir = "C:\npcap-sdk\Lib\x64"
    Get-ChildItem "C:\npcap-dll" -Recurse -Include "*.dll" | ForEach-Object {
      Copy-Item $_.FullName "$libDir\$($_.Name)" -Force
      Write-Host "::notice::Extracted DLL: $($_.Name)"
    }
    Get-ChildItem $libDir -Filter "*.dll" | ForEach-Object { Write-Host "  $($_.Name) ($($_.Length) bytes)" }
    Remove-Item "C:\npcap-dll" -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item npcap-installer.exe -ErrorAction SilentlyContinue
```

Modern Npcap (1.70+) ships `wpcap.dll` only — `vpcap.dll` was the old name. The post-build script should prefer `wpcap.dll`, fall back to `vpcap.dll` for legacy SDKs, and skip whichever is absent.

## Pitfalls

- **`bundle.additionalFiles` is Tauri v1, not v2.** Using it in `tauri.conf.json` under Tauri v2 produces schema error `'additionalFiles' was unexpected`. Use `bundle.resources`.
- **`bundle.resources` paths are relative to the Tauri project root**, not `frontendDist`. A DLL placed in `build/` but listed as `resources/vpcap.dll` in `bundle.resources` won't be found — the bundler looks for `<tauri-project-root>/resources/vpcap.dll`.
- **Listing both DLL variants in `bundle.resources` is fine** (`["resources/vpcap.dll", "resources/wpcap.dll"]`). The bundler only ships what actually exists on disk. The post-build script decides which one gets copied.
- **Zero-byte placeholders are worse than nothing.** If the CI step only downloads the SDK zip (no installer extraction), `fix-paths.cjs` may write empty files. Tauri v2 either rejects them at bundle time or packages an empty DLL that fails at runtime. Always check `fs.statSync(path).size > 0` before copying.
- **macOS/Linux builds must not fail because of missing Windows DLLs.** If `bundle.resources` lists files that don't exist on non-Windows runners, the Tauri bundler may reject the build. Either: (a) the post-build script leaves a valid empty placeholder for non-Windows (but not zero bytes — Tauri v2 rejects those), or (b) the resources config is conditional per platform, or (c) the post-build script removes the placeholder after bundling on non-Windows. One prior run failed macOS with `resource path 'resources/vpcap.dll' doesn't exist` — so the config must not require both files on every platform.
- **Never rely on the user installing Npcap as the fix for a sniffer app.** Ship the DLL. "The user must install Npcap" is a release bug, not a user instruction.
- **Npcap installer URL changes across versions.** The DLL extraction step should pin a known-good installer version (e.g. `npcap-1.78.exe`) and re-verify when updating. Only `wpcap.dll` (and `Packet.dll`) are inside the installer — `vpcap.dll` is not.

## Verification

```bash
# Download the Windows NSIS installer from the draft release
gh release download v0.2.1 --repo <owner>/<repo> --pattern "*x64-setup.exe"

# List archive contents — confirm the DLL is non-zero bytes
7z l *.exe | grep -iE "vpcap|wpcap"

# Expected: a line showing resources/vpcap.dll or resources/wpcap.dll with a real size,
# NOT "0 bytes" and NOT missing entirely.
```

If the DLL is absent or zero bytes, the CI Npcap step didn't extract the installer DLL, or `fix-paths.cjs` wrote a placeholder instead of the real file. Re-check the CI step logs for the `Extracted DLL:` notice and the `wpcap.dll (N KB)` listing.

## Related

- SKILL.md (this skill) — full Tauri release CI workflow, first-release checklist, duplicate-draft race fix, version bump checklist (4 files), signing/key setup, macros like `RUSTFLAGS: -Ctarget-feature=+crt-static` for Windows CTranslate2 builds.
- `npm run build` post-build script pattern (`scripts/fix-paths.cjs`) — the Vite/Svelte post-build hook that copies the DLL into `src-tauri/resources/` and fixes absolute asset paths in `build/index.html` for `file://` Tauri releases.
