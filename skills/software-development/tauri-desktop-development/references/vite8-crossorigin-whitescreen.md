# Vite 8 + Tauri 2: Crossorigin White Screen Debug

## The Bug

Built `index.html` has `crossorigin` attributes on `<script module>` and `<link>` tags.

```html
<!-- BAD — Tauri WebView rejects these -->
<script type="module" crossorigin src="/assets/index-abc.js"></script>
<link rel="stylesheet" crossorigin href="/assets/index-def.css">
```

## Why It Happens

Vite 5–7 had a `build.crossorigin` config option (`string | boolean`). Setting it to `false` or `''` would remove the attribute from the build output.

**Vite 8** removed `build.crossorigin` from `BuildEnvironmentOptions` entirely. Setting `crossorigin: false` (or `crossorigin: ''`) causes a TypeScript build error:

```
vite.config.ts: error TS2769: No overload matches this call.
  Object literal may only specify known properties, and 'crossorigin' does not
  exist in type 'BuildEnvironmentOptions'.
```

Despite removing the config option, Vite 8's default behavior still adds `crossorigin` (empty attribute → equivalent to `crossorigin="anonymous"`).

## Tauri's Role

Tauri 2 serves bundled assets via a **custom protocol** — not a standard HTTP server. On Linux (WebKitGTK), this is `tauri://localhost`; on macOS, `https://tauri.localhost`. This custom protocol does NOT return CORS headers on resource responses.

When the WebView encounters `crossorigin` on a resource load, it expects:
- An `Access-Control-Allow-Origin` header matching the page origin, OR
- An `Access-Control-Allow-Credentials: true` header if `use-credentials`

Without these headers, the WebView **silently refuses to execute the module script** — no error in console, no network failure visible, just nothing renders. The result is a white screen, or on some WebKit versions, a page that says "cannot connect to host."

## The Fix: Custom Vite Plugin

Since Vite's built-in option is gone, we need a plugin that hooks into `transformIndexHtml`:

```ts
function removeCrossorigin(): import('vite').Plugin {
  return {
    name: 'remove-crossorigin',
    enforce: 'post',           // run after all other transforms
    transformIndexHtml(html) {
      return html.replaceAll(' crossorigin', '')
    },
  }
}
```

**Key details:**
- `enforce: 'post'` — ensures this runs last, after Vite's built-in HTML transform adds the `crossorigin` attributes
- `replaceAll(' crossorigin', '')` — strips the standalone attribute `crossorigin` and also `crossorigin="anonymous"` patterns (since both appear as `crossorigin` in the attribute string). Handles `<script crossorigin>`, `<link crossorigin>`, and any other element.
- Must be added to the `plugins` array: `plugins: [react(), removeCrossorigin()]`

## The Build Order Trap

The two-step build pipeline has a hidden gotcha:

```
npm run build   → writes to frontend/dist/
cargo build --release  → embeds frontend/dist/ via tauri::generate_context!()
```

If you rebuild the frontend (`npm run build`) but do NOT rebuild the Rust binary (`cargo build --release`), the binary still contains the OLD embedded frontend. Running the binary will serve the stale version.

This explains why changing `vite.config.ts` and rebuilding the frontend alone doesn't fix the white screen — the user has to rebuild the Rust binary too.

**Check timestamps:**

```bash
# Binary build time
stat /path/to/target/release/kicks | grep Modify
# Frontend dist time
stat /path/to/frontend/dist/index.html | grep Modify
```

If the binary is older than the dist, the binary has stale assets.

## CSP Considerations

Tauri 2 apps with SPA frameworks need a minimally permissive CSP:

```json
"security": {
  "csp": "default-src 'self'; connect-src 'self'; script-src 'self' 'unsafe-eval'; style-src 'self' 'unsafe-inline'; img-src 'self' data: blob:;"
}
```

- `'unsafe-eval'` — needed by some bundler module loaders (Vite's output can include eval-based module loading for certain configurations). Without it: script loads OK but `eval()` calls fail → blank page or partial render.
- `blob:` — needed for `URL.createObjectURL()` patterns (canvases, custom image generation, drag-and-drop thumbnails). Without it: images from blobs fail to load silently.
- `'unsafe-inline'` in `style-src` — already required by CSS-in-JS and Tailwind's generated styles.

## Verification

After applying the fix:

```bash
# Verify no crossorigin in built HTML
grep -c 'crossorigin' frontend/dist/index.html
# → 0

# Verify binary is newer than dist
[ frontend/dist/index.html -nt target/release/kicks ] && echo "BINARY STALE" || echo "OK"

# Run and test
./target/release/kicks
```

## Version-Specific Notes

| Vite Version | Has `build.crossorigin`? | Fix approach |
|---|---|---|
| 5.x | Yes (`string \| false`) | `crossorigin: false` or `crossorigin: ''` |
| 6.x | Yes (deprecated) | `crossorigin: ''` |
| 7.x | Removed from types, may still work at runtime | Try empty string, fall back to plugin |
| 8.x | No — TypeScript error at compile time | Custom `transformIndexHtml` plugin required |

Tested on: Tauri 2, Vite 8.0.14, WebKitGTK 2.48+, Arch Linux (Hyprland/Wayland), React 19 + Tailwind 4.