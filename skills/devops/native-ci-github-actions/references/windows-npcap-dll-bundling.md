# Windows Npcap DLL bundling (two-step)

The `pcap` crate compiles against the Npcap SDK (`wpcap.lib`) but at RUNTIME needs the corresponding DLL (`wpcap.dll` or `vpcap.dll`) next to the `.exe`. The SDK install step in the workflow only provides the `.lib` for linking — the DLL must be bundled separately or the release fails on a clean Windows machine with "module not found" / packet capture silently disabled.

## Step 1 — Copy DLL into frontend `build/` during `npm run build`

Add a script (e.g. `scripts/fix-paths.cjs`) that runs after `vite build`. Wire it via `package.json`:

```json
"scripts": {
  "build": "vite build && node scripts/fix-paths.cjs"
}
```

The script checks for the DLL in the Npcap SDK path and copies whichever exists into `build/`:

```js
const fs = require('fs');
const path = require('path');

const buildDir = path.join(__dirname, '..', 'build');
const SDK_ROOT = process.env.NPCAP_SDK_PATH || (process.platform === 'win32' ? 'C:\\npcap-sdk' : '');
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
  // Npcap SDK ships either vpcap.dll or wpcap.dll depending on version
  bundled = bundleDllIfPresent('vpcap.dll') || bundleDllIfPresent('wpcap.dll');
}

if (!bundled && process.platform === 'win32') {
  console.warn(
    'WARNING: No Npcap DLL (vpcap.dll / wpcap.dll) found — Windows builds will lack packet capture. ' +
    'Set NPCAP_SDK_PATH or extract the Npcap SDK to C:\\npcap-sdk.'
  );
}
```

Prefer `vpcap.dll` if present (newer Npcap SDK naming); fall back to `wpcap.dll`. If neither is present, warn and skip — the build still succeeds, just without packet capture on Windows.

## Step 2 — Tell Tauri to bundle the DLL via `additionalFiles`

Copying the DLL into `build/` is NOT enough by itself — the Tauri bundler does not pick up arbitrary files from the frontend dist unless told to. Add the DLL name(s) to `bundle.additionalFiles` in `src-tauri/tauri.conf.json`:

```json
"bundle": {
  "additionalFiles": ["vpcap.dll", "wpcap.dll"]
}
```

Both steps are required. Without `additionalFiles`, the DLL lands in `build/` but does not ship in the release package.

## CI wiring

The `.github/workflows/release.yml` already installs the Npcap SDK on `windows-latest`:

```yaml
- name: Install Npcap SDK (Windows)
  if: runner.os == 'Windows'
  shell: pwsh
  run: |
    Invoke-WebRequest -Uri "https://npcap.com/dist/npcap-sdk-1.13.zip" -OutFile "npcap-sdk.zip"
    Expand-Archive npcap-sdk.zip -DestinationPath C:\npcap-sdk
    "LIB=C:\npcap-sdk\Lib\x64;$env:LIB" | Out-File -FilePath $env:GITHUB_ENV -Append
```

The `fix-paths.cjs` script picks up the DLL from `C:\npcap-sdk\Lib\x64` automatically (the `NPCAP_SDK_PATH` fallback). No extra env var needed in CI.

## Local Windows builds

For a local Windows dev machine without the SDK extracted, either:
- Set `NPCAP_SDK_PATH` to the SDK root before `npm run build`, or
- Extract the Npcap SDK to `C:\npcap-sdk` (matches the CI path)

If neither is present, the script warns and the Windows build proceeds without packet capture — the app still launches, just can't sniff UDP traffic.

## Diagnosing a missing DLL at runtime

If the Windows release launches but packet capture doesn't work:
1. Check the release package (zip/NSIS install dir) for `vpcap.dll` or `wpcap.dll` next to the `.exe`.
2. `gh run view <id> --log-failed | grep -i "wpcap\|vpcap\|Npcap"` to confirm the copy step ran in CI.
3. Verify `bundle.additionalFiles` includes the DLL name in `src-tauri/tauri.conf.json`.
