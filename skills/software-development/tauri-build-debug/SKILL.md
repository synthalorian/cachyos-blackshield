---
name: tauri-build-debug
description: Use when a Tauri release build shows blank white window.
---

# Tauri Build + Blank Window Debug

Diagnosing a Tauri v2 release binary that compiles, launches, shows the window frame, but renders blank/white/empty content.

## Trigger

- `cargo build --release` succeeds, binary runs, window appears, content area blank/white
- App log shows initialization (fonts, engine setup) but no visible UI
- You changed frontend code (Svelte/React/Vite) and rebuilt the Rust binary without the UI updating

## Core insight

**Tauri v2 embeds the frontend at Rust build time.** The `frontendDist` directory is read and packaged during `cargo build`. If you change the frontend and only rebuild the Rust side, the binary ships stale assets.

## Build sequence (correct order)

```bash
# Frontend first — emit the dist
npm run build          # or yarn/pnpm build

# Embed it into the binary
cd src-tauri
cargo build --release  # or: npm run tauri build (handles both)
```

The `build.beforeBuildCommand` (typically `npm run build`) handles this automatically when using `npm run tauri build`. Running `cargo build --release` directly bypasses that hook.

## Diagnosis path

### 1. Build timestamps

```bash
stat -c '%n %y' ../build/index.html
stat -c '%n %y' target/release/<binary>
```

If `build/index.html` is older than the binary, the binary embedded stale frontend. Rebuild in correct order.

### 2. Embedded assets in binary

```bash
strings target/release/<binary> | grep -E "index.html|/_app|favicon"
```

Should show frontend paths. If empty, frontend was never embedded — check `frontendDist` in `tauri.conf.json` and that `npm run build` produced output.

### 3. tauri.conf.json traps

- **Dev URL in release config**: a `url` field pointing at `http://localhost:1420` (or any dev server) makes the release binary try to connect to a server that isn't running → blank window. Remove `url` from the window config for release; Tauri loads the embedded dist by default when no `url` is set.

- **`frontendDist` wrong**: confirm `build.frontendDist` points to the actual frontend output directory (e.g. `../build`, `../dist`).

### 4. App log

```bash
export RUST_LOG=debug,<app-module>=debug
./target/release/<binary> > /tmp/app.log 2>&1 &
```

Look for: font subsystem init (glycin/WebKit), engine messages ("No CTranslate2 model found" etc.), and **absence** of "Window created" / "WebView created" / "Loading URL" logs (WebView may be failing silently).

### 5. Display env on Wayland

WebKitGTK needs the right environment to render:

```bash
export WAYLAND_DISPLAY=wayland-0
export XDG_RUNTIME_DIR=/run/user/$(id -u)
export DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$(id -u)/bus
export XAUTHORITY=$(cat /proc/$(pgrep -u $USER plasmashell | head -1)/environ | tr '\0' '\n' | grep ^XAUTHORITY= | cut -d= -f2)
```

Missing/wrong env → WebKitGTK initializes but renders nothing.

### 6. CSS variable race condition (frontend-side)

Pure white window background (not the app's dark theme) = CSS custom properties unset during initial render. Fix: apply theme **synchronously in `app.html`** before the framework bootstraps.

In `src/app.html`, add a `<head>` script that reads the stored theme from localStorage and sets CSS variables on `document.documentElement` directly:

```html
<script>
  (function () {
    try {
      var themeId = localStorage.getItem('<app>-theme') || '<default-theme-id>';
      var root = document.documentElement;
      root.style.setProperty('--bg-primary', 'rgba(15, 10, 30, 0.95)');
      // ... all vars the theme JS would set
    } catch (e) { /* localStorage may not be available */ }
  })();
</script>
```

This runs before SvelteKit/React/vanilla JS mounts — no flash of white.

## Pitfalls

- **`cargo build --release` without `npm run build` first.** Binary compiles fine; frontend stale; window shows old/empty content. Always build frontend first, or use `npm run tauri build`.

- **Leaving `url` in tauri.conf.json window config for release.** Makes release binary depend on a dev server. Remove it.

- **Launching without display env vars on Wayland.** WebKitGTK silently renders nothing. Set the four env vars above.

- **`cargo check` validating the full app.** Only compiles Rust. Doesn't embed frontend, doesn't run the build hook, doesn't prove the release binary renders. Always test the actual release binary.

## References

- [tauri-build-config](references/tauri-build-config.md) — `tauri.conf.json` fields, `frontendDist`, `beforeBuildCommand`, dev vs release window config

<!-- session-specific detail (timestamps, binary paths) belongs in references/, not the body -->
