# Tauri additionalFiles — Pitfalls and Behavior

## What additionalFiles Does

`additionalFiles` in `src-tauri/tauri.conf.json`'s `bundle` section tells the Tauri bundler to copy files from the source tree into the app package. At runtime, these files live in the app's directory alongside the `.exe` (Windows) or in the app bundle (macOS/Linux).

```jsonc
"bundle": {
  "additionalFiles": ["vpcap.dll", "wpcap.dll", "models/*.bin"]
}
```

Paths are resolved relative to the project root (the directory containing `src-tauri/`), **not** relative to `frontendDist` or `src-tauri/`.

## Silent-Skip Behavior (Critical Pitfall)

**The bundler does NOT error when an `additionalFiles` entry points to a missing file.** It silently skips it. No warning, no error, no log message. The app builds successfully, the `.exe` is produced, and the missing file simply isn't in the bundle.

This is the #1 cause of "the DLL isn't there but the build succeeded" bugs.

### Why This Happens

The bundler iterates `additionalFiles`, checks if each path exists, and copies it if so. If not, it moves on. The behavior is permissive by design (e.g. platform-specific files like `win32/` vs `linux/`), but it means a misconfigured path is invisible.

### How to Catch It

1. **Verify after every build:**
   ```powershell
   Get-ChildItem "src-tauri\target\release\bundle\windows\<app-name>\" -Filter "wpcap.dll"
   Get-ChildItem "src-tauri\target\release\bundle\windows\<app-name>\" -Filter "vpcap.dll"
   ```
2. **Add a CI verification step** (see `SKILL.md` — "CI Verification" section).
3. **Run the post-build script explicitly** before `tauri build` and check its output for the "Bundled X from ..." confirmation line or the WARNING.

## Path Resolution

`additionalFiles` paths are relative to the **project root** (where `.git` lives, where `src-tauri/` sits).

| Entry | Resolved path | Correct? |
|-------|---------------|----------|
| `"vpcap.dll"` | `<project-root>/vpcap.dll` | Only if the DLL is at project root |
| `"build/vpcap.dll"` | `<project-root>/build/vpcap.dll` | Yes — if Layer 1 copied it to `build/` |
| `"npcap/wpcap.dll"` | `<project-root>/npcap/wpcap.dll` | Only if that directory exists |
| `"src-tauri/vpcap.dll"` | `<project-root>/src-tauri/vpcap.dll` | Yes — if DLL is in src-tauri/ |

**The common mistake:** using a path that looks like it should work but doesn't match where the file actually is. The post-build script copies into `build/`, so the `additionalFiles` entry must be `"build/vpcap.dll"` — or the script must copy the DLL to the project root.

**The better pattern:** have the post-build script copy the DLL into `frontendDist` (which is `build/` for most Tauri apps), then use `additionalFiles` with the path relative to project root (`"build/vpcap.dll"`). This way the DLL flows through the same path as frontend assets.

## Wildcards

`additionalFiles` supports glob patterns:

```jsonc
"additionalFiles": ["models/*.bin", "configs/*.json"]
```

The glob is evaluated at bundle time against the project root. If no files match, the entry is silently skipped.

**Pitfall — empty glob:** `"models/*.bin"` when `models/` is empty → silently skipped. The app builds fine, but the models aren't bundled. Always verify the glob matches files.

## Interaction with `resources`

Do NOT confuse `additionalFiles` with `bundle.resources`:

| Config | Purpose |
|--------|---------|
| `additionalFiles` | Copies files into the app package at bundle time. Files are inside the app directory at runtime. |
| `resources` | Makes directories available at runtime via `tauri::api::path::resourceDir()`. Used for user-writable data that shouldn't be inside the immutable app bundle. |

For a DLL that the app loads at runtime via `LoadLibrary`, use `additionalFiles` — the DLL must be in the app directory, not in a resources folder.

## Verification Recipe

```bash
# 1. Build
npm run build          # triggers post-build script → DLL in build/
cargo tauri build      # bundles everything including additionalFiles

# 2. Check the DLL is in the bundle
find src-tauri/target/release/bundle -name "vpcap.dll" -o -name "wpcap.dll"

# 3. If missing, check:
#    a) Did the post-build script run? Look for "Bundled ... from ..." in npm build output.
#    b) Is the additionalFiles path correct? Does the file exist at that path relative to project root?
#    c) Is the SDK path correct? Does the post-build script's SDK_ROOT resolve to a real directory?
```

## References

- `references/wpcap-vs-vpcap.md` — which DLL name to expect from which Npcap SDK version.
