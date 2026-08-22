---
name: tauri-webview-debugging
description: Tauri blank white WebView and iframe invoke() debugging.
tags: [tauri, webview, white-screen, iframe, invoke, sveltekit, devurl, css-variables, brotli]
triggers: ["Tauri blank white screen", "Tauri WebView not rendering", "tauri.conf.json url trap", "iframe invoke Tauri", "Tauri iframe same-origin", "CSS variable flash SvelteKit Tauri", "app.html theme init Tauri", "verify Tauri window no vision", "stale Tauri embedded assets", "brotli decompress Tauri assets"]
---

# Tauri WebView Debugging

## Blank white / non-rendering WebView

### 1. devUrl / url trap in `tauri.conf.json`

**Symptom:** Release binary shows blank white window. Process is alive. Works fine under `npm run tauri dev`.

**Cause:** `app.windows[].url` is set to `"http://localhost:1420"` (or similar) for dev mode. Correct for `tauri dev`, but the release binary uses `url` literally — if no dev server is running, the WebView loads nothing → blank white.

**Fix:** Remove `url` from window config for release. Tauri 2 serves from `frontendDist` when no `url` is specified.

```jsonc
// tauri.conf.json — window config
{
  "app": {
    "windows": [
      {
        "title": "My App",
        // ❌ REMOVE THIS for release builds:
        // "url": "http://localhost:1420",
        // ✅ Rely on frontendDist instead:
        "width": 400,
        "height": 600
      }
    ]
  },
  "build": {
    "frontendDist": "../build",
    "beforeBuildCommand": "npm run build",
    "devUrl": "http://localhost:1420"  // used by `tauri dev` only
  }
}
```

**If you want one config for both dev and release:** Set `devUrl` in `build` section (used by `tauri dev` automatically), do NOT set `url` in `app.windows`. Tauri picks the right source at runtime.

### 2. Stale embedded frontend assets

**Symptom:** Blank screen or partial UI. Binary built, then frontend changed, binary rebuilt but frontend NOT rebuilt in between.

**Cause:** Tauri embeds the frontend at compile time via `tauri_build::build()`, which runs `beforeBuildCommand` (e.g. `npm run build`). Running `cargo build --release` without `npm run build` first embeds the OLD built frontend.

**Detection:**
```bash
# Compare timestamps — build MUST be newer than binary
stat -c '%Y %n' build/index.html target/release/<binary-name>
# If build/index.html epoch < binary epoch → stale assets
```

**Fix:**
```bash
npm run build           # rebuild frontend → fresh build/
cargo build --release   # re-embed fresh build/ into binary
```

Or just: `npm run tauri build` (runs both in order).

**Verification — decompress embedded assets with brotli:**

Tauri 2 compresses frontend assets with brotli before embedding. To verify what's actually inside the binary:

```bash
# Find the embedded assets directory (hash in name varies)
ASSETS_DIR=$(find src-tauri/target/release/build -type d -name "tauri-codegen-assets" | head -1)

# Decompress the embedded index.html
brotli -d "$ASSETS_DIR/index.html.br" -o /tmp/embedded-index.html
cat /tmp/embedded-index.html | head -20

# Decompress JS chunks
for f in "$ASSETS_DIR"/*.js.br; do
  brotli -d "$f" -o "/tmp/$(basename $f .br)"
done
```

If the decompressed `index.html` references JS chunks that don't exist, or if the theme-init script is missing, you're looking at stale embeddings.

**PITFALL: `strings` does NOT find embedded frontend content.** Tauri compresses with brotli. `strings binary | grep` returns nothing for HTML/JS/CSS. Use brotli decompression instead.

**PITFALL: plain `cargo build --release` can embed ZERO assets.** Observed on Tauri 2 + SvelteKit (2026-08): `npm run tauri build` produced a working binary (98 files in `tauri-codegen-assets`); a subsequent plain `cargo build --release` relinked the binary with an EMPTY `tauri-codegen-assets` dir. Symptom is NOT a blank window — the WebView shows an error page: **"Could not connect to localhost: Connection refused"** (the `tauri://localhost` protocol handler has no index.html to serve). Diagnose by comparing asset counts across `target/release/build/<crate>-*/out/tauri-codegen-assets` — the newest out dir having 0 files is the tell. Fix: ALWAYS build release via `npm run tauri build` (add `-- --no-bundle` to skip slow bundling); never plain cargo for a shippable/testable release binary. `cargo build` is fine for `cargo check`-type iteration only.

### 3. CSS custom properties unset → white flash (SvelteKit + Tauri)

**Symptom:** Window opens white for a moment, then theme appears. Or stays white if theme init fails.

**Cause:** CSS custom properties (e.g. `--bg-primary`) are set by JS after page load (localStorage read, async theme fetch, etc.). During the gap between HTML parse and JS theme application, elements styled with `background: var(--bg-primary)` resolve to the initial fallback — often transparent or white in WebKitGTK/Tauri.

**Fix — synchronous theme init in `app.html`:**

Put an inline synchronous script in `app.html`'s `<head>` that applies the theme before SvelteKit bootstraps:

```html
<!-- src/app.html — synchronous theme init in <head> -->
<script>
  (function() {
    try {
      var themeId = localStorage.getItem('app-theme') || 'default';
      var root = document.documentElement;
      var themes = {
        'default': {
          '--bg-primary': 'rgba(15, 10, 30, 0.95)',
          '--bg-secondary': 'rgba(25, 15, 45, 0.85)',
          '--accent': '#ff64c8'
          // ... all CSS vars needed for initial paint
        }
      };
      var t = themes[themeId] || themes['default'];
      for (var p in t) root.style.setProperty(p, t[p]);
    } catch (e) { /* localStorage may not be available */ }
  })();
</script>
```

Key points:
- Must be in `app.html`, NOT in a Svelte component's `onMount` — `onMount` runs too late
- Must be synchronous (not `async`) — browser pauses HTML parsing for inline scripts
- Keep theme object minimal — only CSS vars needed for initial paint. Full theme can load later.
- Wrap in try/catch — `localStorage` may throw in some contexts

### 4. Verifying the window rendered (without vision tools)

```bash
# Process alive?
ps aux | grep <binary-name> | grep -v grep

# Window created? (xdotool)
xdotool search --name "<window-title-or-substring>" 2>/dev/null
# Returns window IDs if found; empty if not

# WebKit/Tauri journal errors
journalctl --user -n 50 -t "WebKit" 2>/dev/null
journalctl --user -n 50 -t "tauri" 2>/dev/null

# Dev server responding? (dev mode only)
curl -s http://localhost:1420 | head -5
```

- Window found but blank → content problem (stale assets, devUrl trap, CSS flash)
- No window found → window creation problem (WebKitGTK init failure, Wayland display, missing deps)

### 5. Reading frontend localStorage without devtools (WebKitGTK/Linux)

When you need the frontend's persisted state (settings, filters, flags) and can't
open devtools: Tauri v2 on Linux stores webview localStorage as SQLite at
`~/.local/share/<bundle-identifier>/localstorage/tauri_localhost_0.localstorage`
(table `ItemTable`, key/value). **Values are UTF-16-LE** — plain
`sqlite3 ... SELECT` prints only the first char (`{`). Decode with Python:

```python
import sqlite3
con = sqlite3.connect('/home/<user>/.local/share/<bundle.id>/localstorage/tauri_localhost_0.localstorage')
blob = con.execute("SELECT value FROM ItemTable WHERE key='<key>'").fetchone()[0]
print((blob if isinstance(blob, bytes) else blob.encode()).decode('utf-16-le'))
```

Dev mode uses a separate origin file: `http_localhost_1420.localstorage` — check
which origin the session you care about used.

### 6. Verifying the window on KDE Wayland (xdotool sees nothing)

`xdotool search` only sees XWayland windows — a native-Wayland Tauri window is
invisible to it, and cua-driver may report 0 windows session-wide. Use a KWin
script and read its output from the journal:

```bash
cat > /tmp/list-windows.js << 'EOF'
const clients = workspace.windowList();
for (const c of clients) print(c.caption + " | " + c.resourceClass + " | " + c.width + "x" + c.height + " | visible=" + !c.minimized);
EOF
qdbus6 org.kde.KWin /Scripting org.kde.kwin.Scripting.loadScript /tmp/list-windows.js
qdbus6 org.kde.KWin /Scripting org.kde.kwin.Scripting.start
sleep 2
journalctl --user --since "30 sec ago" --no-pager | grep kwin_wayland
```

(`qdbus6`, not `qdbus`, on Plasma 6.) Window listed with sane size but user
reports blank → content problem. Not listed → creation problem.

## iframe IPC reachability inside Tauri WebView

### Can an iframe call `invoke()`?

**Yes, but only if the iframe is same-origin with the Tauri app's webpage.**

Tauri's IPC bridge (`@tauri-apps/api`, `invoke()`, `window.__TAURI__`) is exposed to the WebView's main frame and any same-origin frames. Cross-origin iframes do NOT get IPC access — this is a security boundary.

**Same-origin = works:**
```html
<!-- App at tauri://localhost (release) or http://localhost:1420 (dev) -->
<iframe src="/other-page"></iframe>           <!-- same origin → CAN invoke -->
<iframe src="http://localhost:1420/other"></iframe>  <!-- same origin in dev → CAN invoke -->
```

**Cross-origin = does NOT work:**
```html
<iframe src="https://example.com"></iframe>  <!-- cross-origin → CANNOT invoke -->
<iframe src="file:///local.html"></iframe>   <!-- different origin → CANNOT invoke -->
```

**Why:** Tauri's IPC bridge attaches to the page's origin. Frames with a different origin get a separate JS context without the bridge. Mirrors browser same-origin policy for `postMessage` and shared cookies.

**Practical implications:**
- Dev mode (`tauri dev`): app runs at `http://localhost:1420`. Any iframe sourcing from `localhost:1420` is same-origin and can invoke.
- Release mode: app runs from `tauri://` protocol. Iframes loading external URLs cannot invoke.
- To let an iframe call Tauri commands, serve that iframe's content from the same origin — bundle it in `frontendDist`, or serve from same dev server.

### Debugging iframe invoke() failures

```javascript
// In the iframe's JavaScript:
console.log('window.__TAURI__:', typeof window.__TAURI__);
console.log('window.__TAURI_INTERNALS__:', typeof window.__TAURI_INTERNALS__);

// Both undefined → cross-origin iframe, no IPC bridge
// __TAURI__ defined → same-origin, can invoke
```

```bash
# In dev mode, check the main app's origin matches iframe src
curl -s http://localhost:1420 | grep -i '<iframe'
```

## Sandboxed iframe can't access Tauri IPC — use postMessage bridge

**Symptom:** iframe calls `invoke()` but gets `TypeError: undefined is not an object (evaluating 'window.__TAURI_INTERNALS__.invoke')`. The iframe renders fine but Tauri commands don't work.

**Cause:** The iframe uses `sandbox` (e.g. `sandbox="allow-same-origin allow-scripts allow-forms"`). While `allow-same-origin` makes it same-origin for browser purposes, Tauri's IPC bridge (`window.__TAURI_INTERNALS__`) may not be exposed in sandboxed iframes depending on the Tauri version and WebView backend. The `invoke()` function from `@tauri-apps/api` accesses `window.__TAURI_INTERNALS__.invoke` which is undefined.

**Fix — postMessage bridge between iframe and parent:**

In the iframe, post a message instead of calling `invoke()` directly:

```javascript
// Inside the sandboxed iframe
const requestId = crypto.randomUUID();
window.parent.postMessage(
  { type: 'tauri-invoke', id: requestId, command: 'my_command', args: [arg1] },
  '*'
);
```

In the parent page, receive the message and call `invoke()`:

```javascript
// Parent Svelte component
useEffect(() => {
  const handler = (event) => {
    if (event.data?.type === 'tauri-invoke') {
      invoke(event.data.command, event.data.args).then(result => {
        window.postMessage(
          { type: 'tauri-invoke-result', id: event.data.id, result },
          '*'
        );
      });
    }
  };
  window.addEventListener('message', handler);
  return () => window.removeEventListener('message', handler);
}, []);
```

And in the iframe, listen for the result:

```javascript
window.addEventListener('message', (event) => {
  if (event.data?.type === 'tauri-invoke-result' && event.data.id === myRequestId) {
    // Handle result
  }
});
```

**Key points:**
- Use a request ID to match responses to concurrent requests
- The PARENT must call `invoke()` — it has `window.__TAURI_INTERNALS__`
- This works even with full sandbox (`sandbox` without `allow-same-origin`), because `postMessage` doesn't require same-origin
- Add a fallback for non-Tauri environments: check `typeof window.__TAURI_INTERNALS__` and use `invoke()` directly if available

**Pitfall:** Implementing only the iframe side — the iframe posts messages but the parent never listens. Always implement BOTH sides of the bridge.

---

## SvelteKit Static Adapter + Tauri Release Build: Absolute Asset Paths

**Symptom:** Release build (`npm run tauri build` or `cargo tauri build`) shows blank white window. `npm run tauri dev` works fine. Frontend builds without errors.

**Cause:** SvelteKit's `adapter-static` emits `build/index.html` with absolute asset paths (`/_app/immutable/chunks/X.js`, `/favicon.png`). These resolve correctly on a web server (dev mode serves from localhost, production hosting serves from site root), but in a Tauri release build the WebView loads from `file://` — absolute paths like `/favicon.png` resolve to the filesystem root, not the app directory. Result: all JS/CSS/assets 404 → blank white window.

**Fix:** Post-build script that rewrites absolute paths to relative paths in `build/index.html`.

```javascript
// scripts/fix-paths.cjs
const fs = require('fs');
const path = require('path');

const indexPath = path.join(__dirname, '..', 'build', 'index.html');
const html = fs.readFileSync(indexPath, 'utf8');

const fixed = html
  .replaceAll('="/_app/', '=\"./_app/')
  .replaceAll('="/favicon.png"', '=\"./favicon.png\"')
  .replaceAll('="/svelte.svg"', '=\"./svelte.svg\"')
  .replaceAll('="/tauri.svg"', '=\"./tauri.svg\"')
  .replaceAll('="/vite.svg"', '=\"./vite.svg\"');

if (fixed !== html) {
  fs.writeFileSync(indexPath, fixed, 'utf8');
  console.log('Fixed asset paths in build/index.html');
} else {
  console.log('No path fixes needed');
}
```

Wire into `package.json`:
```json
"scripts": {
  "build": "vite build && node scripts/fix-paths.cjs"
}
```

**Verification:**
```bash
npm run build
grep -c '=\"/_app/' build/index.html   # should be 0 after fix
grep -c '=\"\./_app/' build/index.html  # should be >0 after fix
```

**Pitfall:** Running `cargo build --release` without `npm run build && node scripts/fix-paths.cjs` first embeds the old/unfixed frontend. Always run the full frontend build pipeline before the Rust build, or use `npm run tauri build` which runs both in order.

---

## Quick diagnostic checklist

```
Blank white Tauri window:
├── 1. Is it a release build? Run `npm run build` then `cargo build --release`
├── 2. Check tauri.conf.json: is `url` set in app.windows? Remove it.
├── 3. Decompress embedded assets with brotli — verify index.html is fresh
├── 4. Check app.html for synchronous theme init script
├── 5. Run with RUST_LOG=debug and check stderr for WebKit errors
└── 6. Use xdotool to confirm window exists vs. content is blank

iframe cannot invoke():
├── 1. Check iframe src — is it same-origin?
├── 2. In iframe JS: console.log(typeof window.__TAURI__)
├── 3. If undefined → cross-origin, serve iframe content from app origin
└── 4. If defined but invoke fails → check Tauri command registration in Rust
```
