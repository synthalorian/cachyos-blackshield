---
name: tauri-sveltekit-static
description: Fix Tauri blank window from SvelteKit static adapter
---

# Tauri + SvelteKit Static Adapter — Release Build Blank Window

## Diagnosis

When `cargo tauri build` produces a release app that opens to a blank white window, the most common cause with SvelteKit's `adapter-static` is **asset path resolution failure**.

The static adapter emits `build/index.html` with **absolute** asset paths:

```html
<link href="/_app/immutable/entry/start.XXXX.js" rel="modulepreload">
<link href="/favicon.png" rel="icon">
<script src="/_app/immutable/entry/app.XXXX.js" type="module"></script>
```

These resolve in `npm run tauri dev` because Vite's dev server serves them. They **fail in release** because Tauri loads from `file://` — absolute paths like `/_app/...` don't resolve against the local file system.

### Confirm the diagnosis

```bash
grep -o 'href="[^"]*"' build/index.html | head -5
grep -o 'src="[^"]*"' build/index.html | head -5
```

If paths start with `/` (not `./`), that's the problem.

## Fix

Post-build rewrite of absolute paths to relative in `build/index.html`.

### 1. Create the path rewriter

`scripts/fix-paths.cjs`:

```javascript
const fs = require('fs');
const path = require('path');

const indexPath = path.join(__dirname, '..', 'build', 'index.html');
const html = fs.readFileSync(indexPath, 'utf8');

const fixed = html
  .replaceAll('="/_app/', '="./_app/')
  .replaceAll('="/favicon.png"', '="./favicon.png"')
  .replaceAll('="/svelte.svg"', '="./svelte.svg"')
  .replaceAll('="/tauri.svg"', '="./tauri.svg"')
  .replaceAll('="/vite.svg"', '="./vite.svg"');

if (fixed !== html) {
  fs.writeFileSync(indexPath, fixed, 'utf8');
  console.log('Fixed asset paths in build/index.html');
} else {
  console.log('No path fixes needed');
}
```

Adjust the `replaceAll` calls to match your framework's asset conventions. The pattern is: `="/<prefix>/` → `="./<prefix>/`.

### 2. Wire into the build pipeline

`package.json`:

```json
"scripts": {
  "build": "vite build && node scripts/fix-paths.cjs",
  ...
}
```

The `&&` ensures the rewrite runs after every build, including Tauri release builds which call `npm run build` internally.

### 3. Verify

```bash
npm run build
grep -o 'href="[^"]*"' build/index.html | head -3
# Expected: ./_app/...  ./favicon.png  — NOT /_app/... or /favicon.png
```

Then run the release binary and confirm the window renders.

## What does NOT work

These are common dead ends — don't spend time on them:

1. **`base: './'` in `vite.config.js`** — `adapter-static` ignores Vite's `base` option. The emitted HTML still has absolute paths.

2. **`kit.base: './'` in `svelte.config.js`** — rejected by `adapter-static` with `Unexpected option config.kit.base`. The static adapter manages its own base path internally.

3. **Any `adapter({ relative: true })`-style option** — no such option exists on `adapter-static`.

The root cause is that `adapter-static` hardcodes absolute paths in the emitted HTML. There is no adapter config to change this. Post-build rewriting is the only reliable fix.

## Generalization

This pattern applies to **any SPA framework whose build output emits absolute asset paths**. The fix is always the same: post-build string replacement of `/` → `./` in the HTML entry point.

- **Vite alone** (non-SvelteKit): `base: './'` in `vite.config.js` usually works.
- **SvelteKit + adapter-static**: `base` is ignored — use the post-build rewrite.
- **Other adapters**: check whether they emit absolute or relative paths; the grep diagnostic above works for any setup.
