# Tauri v2 Build Config Reference

Key fields in `src-tauri/tauri.conf.json` relevant to blank-window debugging.

## `build` section

```json
"build": {
  "beforeDevCommand": "npm run dev",
  "devUrl": "http://localhost:1420",
  "beforeBuildCommand": "npm run build",
  "frontendDist": "../build"
}
```

- **`beforeBuildCommand`**: command run automatically before `tauri build` (or `cargo build --release` when using the Tauri wrapper). Typically `npm run build`. Bypassed when running `cargo build --release` directly.
- **`frontendDist`**: path to the frontend's built output directory, relative to `src-tauri/`. Tauri reads this dir and embeds it into the binary at build time.
- **`devUrl`**: the URL the dev-mode window loads. Only used in `--dev` mode (`npm run tauri dev`). Must NOT appear in the window config for release.

## `app.windows` section

```json
"windows": [{
  "title": "Albion Translator",
  "label": "main",
  "width": 420,
  "height": 600,
  "minWidth": 320,
  "minHeight": 400,
  "alwaysOnTop": true,
  "transparent": false,
  "decorations": true,
  "skipTaskbar": false
}]
```

- **`url` field**: if present, the WebView loads that URL instead of the embedded dist. **Remove for release** — leaving `url: "http://localhost:1420"` (or any dev server URL) in the release config causes a blank window because no dev server is running.
- When `url` is absent (or only in dev mode), Tauri loads the embedded frontend from `frontendDist`.

## Dev vs release window config

| Field | Dev mode | Release mode |
|-------|----------|--------------|
| `url` | Optional, points at dev server | Remove — let Tauri load embedded dist |
| `frontendDist` | Not used (dev server serves) | Must point to correct built output |
| `beforeBuildCommand` | Runs `npm run dev` | Runs `npm run build` (must have run before build) |

## Common mistakes

1. Running `cargo build --release` without having run `npm run build` first → stale frontend embedded.
2. Leaving `url: "http://localhost:1420"` in the window config → release binary tries to connect to dev server that isn't running → blank window.
3. `frontendDist` pointing to a directory that doesn't exist or has the wrong name → no assets embedded → blank/empty window.

## Verification

```bash
# Frontend dist must be newer than the binary
stat -c '%n %y' ../build/index.html
stat -c '%n %y' target/release/<binary>

# Check assets are embedded
strings target/release/<binary> | grep -E "index.html|/_app|favicon"
```
