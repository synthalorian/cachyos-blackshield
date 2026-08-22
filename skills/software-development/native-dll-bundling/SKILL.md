---
name: native-dll-bundling
description: Ship native Windows DLLs in Tauri/desktop releases.
tags:
  - tauri
  - windows
  - dll
  - wpcap
  - npcap
  - pcap
  - release-build
  - github-actions
  - native-dependency
triggers:
  - "wpcap.dll missing"
  - "vpcap.dll"
  - "additionalFiles"
  - "native DLL not shipping"
  - "LoadLibrary failed"
  - "Tauri Windows release DLL"
  - "bundle native library"
  - "Npcap SDK CI"
  - "pcap crate Windows"
  - "DLL not found at runtime"
  - "Tauri additionalFiles"
---

# Native DLL Bundling for Desktop App Releases

## When to use

Any desktop app (Tauri, Electron, custom Rust/C++ app) that depends on a **native Windows DLL at runtime** — the DLL must be present next to the `.exe` (or in a path `LoadLibrary` can find) on the target machine, **not just at build time**. Common cases:

- `pcap` / `wpcap` / Npcap SDK — packet capture
- `sqlite3` (non-bundled feature) — SQLite native lib
- `openssl` / `libssl` — TLS (less common with Rustls, but happens)
- Any `extern "system" { fn ... }` or `#[link(name = "...")]` block
- Crates using `raw-dylib` or `LoadLibrary` internally

**Rule of thumb:** if the crate's `build.rs` links against a `.lib`/`.a` at compile time, check whether the corresponding `.dll` is needed at runtime. If yes, and it's not bundled by the crate itself, you need this skill.

## The Two-Layer Fix (Tauri)

Tauri's bundler only includes files that live in `frontendDist` (the built frontend directory) at the time `tauri build` runs. A native DLL that lives in `src-tauri/` or gets downloaded by CI won't make it into the release unless you explicitly bridge it.

### Layer 1 — Copy DLL into `frontendDist` via post-build script

The post-build script already wired into `package.json` is the natural injection point:

```jsonc
// package.json
"scripts": {
  "build": "vite build && node scripts/fix-paths.cjs"
}
```

The script checks the SDK's DLL directory for whichever variant exists and copies it into `build/` (the `frontendDist`):

```js
// scripts/fix-paths.cjs (append to existing post-build hook)
const fs = require('fs');
const path = require('path');

const buildDir = path.join(__dirname, '..', 'build');
const SDK_ROOT = process.env.NPCAP_SDK_PATH
  || (process.platform === 'win32' ? 'C:\\npcap-sdk' : '');
const libDir = path.join(SDK_ROOT, 'Lib', 'x64');

function bundleDllIfPresent(name) {
  const src = path.join(libDir, name);
  if (fs.existsSync(src)) {
    fs.copyFileSync(src, path.join(buildDir, name));
    console.log(`Bundled ${name} from ${src}`);
    return true;
  }
  return false;
}

let bundled = false;
if (SDK_ROOT && fs.existsSync(libDir)) {
  bundled = bundleDllIfPresent('vpcap.dll') || bundleDllIfPresent('wpcap.dll');
}

if (!bundled && process.platform === 'win32') {
  console.warn(
    'WARNING: No Npcap DLL (vpcap.dll / wpcap.dll) found — ' +
    'Windows builds will lack packet capture. ' +
    'Set NPCAP_SDK_PATH or extract the Npcap SDK to C:\\npcap-sdk.'
  );
}
```

**Why this runs after the frontend build:** `vite build` populates `build/`. The script adds the DLL to the same directory the Tauri bundler scans. If you run `cargo build` directly without `npm run build`, the DLL won't be present — that's expected for local dev without the SDK. The warning makes it a visible failure, not a silent one.

### Layer 2 — Tell the Tauri bundler to include it

```jsonc
// src-tauri/tauri.conf.json — bundle section
"bundle": {
  "active": true,
  "targets": ["deb", "rpm"],
  "icon": ["icons/32x32.png", "icons/128x128.png", "icons/128x128@2x.png", "icons/icon.icns", "icons/icon.ico"],
  "additionalFiles": ["vpcap.dll", "wpcap.dll"],
  "linux": { /* ... */ },
  "windows": { /* ... */ }
}
```

List **both** DLL names. The bundler silently skips any entry it can't find in `frontendDist` — no error, no warning. Listing both is safe because the post-build script guarantees whichever one exists is in `build/`.

**Pitfall — `additionalFiles` alone is not enough.** If you only add `additionalFiles` without Layer 1, Tauri looks for the DLL relative to the source tree and finds nothing. The bundler silently skips the missing entry. Result: a release `.exe` that starts but fails at runtime when it tries `LoadLibrary`. Always verify the DLL is actually in the bundled app directory after a build.

**Pitfall — wrong path in `additionalFiles`.** An entry like `additionalFiles: ["npcap/wpcap.dll"]` points at a non-existent directory. Bundler silently ignores it. The correct source is the `frontendDist` (`build/`), which is why Layer 1 copies there first.

**Pitfall — DLL name mismatch (wpcap.dll vs vpcap.dll).** Npcap SDK versions ship different runtime DLL names. Hardcoding one and ignoring the other is a bug. The post-build script prefers `vpcap.dll` (newer) and falls back to `wpcap.dll`. The `additionalFiles` list includes both so the bundler picks up whichever landed in `build/`.

## CI Wiring (GitHub Actions)

The release workflow must make the native SDK available to **both** the Rust link step (compile time) and the post-build script (runtime DLL copy).

```yaml
# .github/workflows/release.yml — Windows matrix job
- name: Install Npcap SDK (Windows)
  if: runner.os == 'Windows'
  shell: pwsh
  run: |
    Invoke-WebRequest -Uri "https://npcap.com/dist/npcap-sdk-1.13.zip" -OutFile "npcap-sdk.zip"
    Expand-Archive npcap-sdk.zip -DestinationPath C:\npcap-sdk
    "LIB=C:\npcap-sdk\Lib\x64;$env:LIB" | Out-File -FilePath $env:GITHUB_ENV -Append
```

- **`LIB` env var:** Rust `pcap` crate's `build.rs` probes `LIB` for the import library (`wpcap.lib`) at compile time. Without it, linker errors.
- **`C:\npcap-sdk`:** the post-build script's Windows default path. The script looks in `C:\npcap-sdk\Lib\x64\` for the DLL.
- **Both must agree on the path.** If the workflow extracts to a different location than the script expects, the DLL copy silently skips and the release is broken.
- **`shell: pwsh`** is required on Windows runners — the default shell (`cmd`) or `bash` won't handle the `Invoke-WebRequest` + `Expand-Archive` pwsh cmdlets.

For non-Npcap SDKs, adapt the download/extract step to the vendor's distribution. The pattern is the same: download → extract to a known path → set the env var the Rust crate probes at build time AND the path the post-build script reads at bundle time.

## Verification

After a Windows `tauri build`:

```powershell
# Check the DLL is in the bundled app directory
Get-ChildItem "src-tauri\target\release\bundle\windows\*" -Recurse -Filter "wpcap.dll"
Get-ChildItem "src-tauri\target\release\bundle\windows\*" -Recurse -Filter "vpcap.dll"

# If neither shows up, the post-build script didn't run or the SDK path was wrong.
# Re-run the build with the script explicitly to see its output:
npm run build
# Look for: "Bundled wpcap.dll from ..." or the WARNING line
```

On the target machine:
- Use [Dependencies](https://github.com/lucasg/Dependencies) or `dumpbin /dependents` to verify the `.exe` lists the DLL as a runtime dependency.
- Confirm the DLL sits next to the `.exe` in the install directory.
- Run the app and check that the feature requiring the DLL actually works (e.g. packet capture starts without error).

## CI Verification (in the workflow itself)

Add a verification step after the `tauri-action` build in the Windows matrix job:

```yaml
- name: Verify DLL in Windows bundle
  if: runner.os == 'Windows'
  run: |
    $bundle = Get-ChildItem "src-tauri\target\release\bundle\windows" -Directory | Select-Object -First 1
    if (-not (Get-ChildItem $bundle.FullName -Recurse -Filter "wpcap.dll" | Select-Object -First 1) &&
        -not (Get-ChildItem $bundle.FullName -Recurse -Filter "vpcap.dll" | Select-Object -First 1)) {
      Write-Error "No Npcap DLL found in Windows bundle — release will be broken"
      exit 1
    }
    Write-Host "Npcap DLL verified in Windows bundle"
```

Fail the CI if the DLL is missing — don't ship a broken release.

## Beyond Tauri

The same two-layer pattern applies to other bundlers:

| Bundler | Layer 1 (copy DLL into bundle dir) | Layer 2 (tell bundler to include) |
|---------|-------------------------------------|------------------------------------|
| Tauri 2 | Post-build script copies into `frontendDist` | `additionalFiles` in `tauri.conf.json` |
| Electron | Copy into `app/` or `resources/` in the build pipeline | `extraResources` in `electron-builder` config |
| Custom Rust (no bundler) | Copy DLL next to `.exe` in `target/release/` via `build.rs` `cargo:` directive or a post-build script | Not applicable — you control the install layout |
| Inno Setup / NSIS installer | Put DLL in the installer source dir | `File` directive in the `.iss` script |

For custom Rust apps without a bundler, the cleanest approach is a `build.rs` that emits `cargo:extra-deps-dir=` or copies the DLL into `OUT_DIR` and then a post-build step that places it next to the binary. Tauri's `additionalFiles` is the equivalent mechanism for apps that use the Tauri bundler.

## References

- `references/wpcap-vs-vpcap.md` — Npcap SDK version mapping, DLL name variants, and which SDK versions ship which DLL.
- `references/tauri-additional-files-pitfalls.md` — detailed breakdown of silent-skip behavior, path resolution, and verification recipes.
