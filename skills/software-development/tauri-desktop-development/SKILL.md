---
name: tauri-desktop-development
description: Tauri 2 desktop application development on Linux (Arch/Hyprland) — project structure, build pipeline, icon requirements, desktop integration, and common pitfalls for Rust + Vite/React Tauri apps.
tags:
  - tauri
  - rust
  - desktop
  - webview
  - arch-linux
  - icon-generation
  - vite
  - csp
  - crossorigin
triggers:
  - "Tauri app"
  - "tauri build"
  - "tauri.conf.json"
  - "webkit2gtk"
  - "tauri icons"
  - "app launcher icon"
  - ".desktop file"
  - "hicolor icons"
  - "Tauri 2"
  - "Tauri release build"
  - "white screen"
  - "cannot connect to host"
  - "Vite 8"
  - "crossorigin"
  - "CSP"
  - "content security policy"
  - "transformIndexHtml"
---

# Tauri Desktop Development

## Prerequisites (Arch Linux)

System packages required for Tauri 2 development:

```bash
# Core Tauri deps — webview, GTK, rendering
sudo pacman -S webkit2gtk-4.1 gtk3 libsoup3 libayatana-appindicator

# Audio (for audio-focused apps like Kicks)
sudo pacman -S pipewire pipewire-jack pipewire-pulse pipewire-audio alsa-lib alsa-utils

# Build essentials
sudo pacman -S base-devel pkg-config openssl dbus
```

**Don't forget:** `webkit2gtk-4.1` is THE version Tauri 2 needs. The older `webkit2gtk` (no `-4.1`) is for Tauri 1.

## Project Structure (Typical)

```
project-root/
├── Cargo.toml              # Workspace root — members: ["src-tauri", "crates/*"]
├── crates/
│   ├── core/               # Shared domain logic (no Tauri dependency)
│   ├── dsp/                # Platform-specific engine (cpal, jack, audio)
│   └── rpc/                # External service clients
├── src-tauri/
│   ├── Cargo.toml          # Binary package — `[package].name` determines binary name
│   ├── tauri.conf.json     # App ID, window config, bundle settings, icon paths
│   ├── icons/              # All icon files (see Icon Requirements below)
│   └── src/
│       ├── lib.rs          # Tauri app setup, commands registration
│       ├── main.rs         # Entry point: `fn main() { app_lib::run(); }`
│       └── commands/       # #[tauri::command] handlers grouped by domain
└── frontend/
    ├── package.json        # React/Vite/Svelte — whatever web framework
    ├── vite.config.ts
    └── src/                # Frontend source
```

## Build Pipeline

```bash
# 1. Install frontend deps and build
cd frontend
npm ci
npm run build     # tsc -b && vite build  — outputs to frontend/dist/

# 2. Rust backend (from project root)
cd ..
cargo build --release
```

**Build order matters:** Tauri's `beforeBuildCommand` in `tauri.conf.json` usually handles the frontend step automatically, but if that fails, build frontend explicitly first, then the Rust side.

The binary lands at `target/release/<package_name>` where `<package_name>` = `[package].name` in `src-tauri/Cargo.toml`. It is NOT necessarily `kicks` or the product name — it's whatever the Cargo package name says.

### Static Frontend (No Bundler)

Tauri 2 can serve static HTML/CSS/JS files without a bundler or dev server. Set up the project with:

```
project-root/
├── dist/                   # Frontend files served by Tauri
│   ├── index.html          # Entry point
│   ├── styles.css          # All app styles
│   └── app.js              # All app logic
├── src/
│   ├── main.rs
│   └── lib.rs
├── Cargo.toml
└── tauri.conf.json
```

In `tauri.conf.json`:
```json
{
  "build": {
    "beforeBuildCommand": "",
    "beforeDevCommand": "",
    "frontendDist": "dist"
  }
}
```

- `frontendDist` is resolved **relative to the tauri.conf.json file location**, not the project root. If tauri.conf.json is in `src/desktop/`, then `"frontendDist": "dist"` points to `src/desktop/dist/`.
- Remove `devUrl` entirely — without it, `tauri dev` serves from `frontendDist` statically.
- **CRITICAL: `window.__TAURI__` is NOT available without the `@tauri-apps/api` npm package in Tauri 2.** Only `window.__TAURI_INTERNALS__` (low-level IPC bridge) is injected by default. If you're using static HTML/JS (no bundler, no `npm install @tauri-apps/api`), `window.__TAURI__` will be `undefined` and `window.__TAURI__.core.invoke` will throw.
- Without the npm package, the frontend must use HTTP `fetch()` to call a backend server instead of Tauri IPC. Set API_BASE from env or hardcode for development.
- To detect if running inside Tauri at all (even without the API), check `typeof window.__TAURI_INTERNALS__ !== 'undefined'`.
- For development in browser (outside Tauri), set a **conditional** shim so `__TAURI__`-related code doesn't throw:
  ```html
  <script>
    if (!window.__TAURI__) {
      window.__TAURI__ = { core: { invoke: () => {} } };
    }
  </script>
  ```

**PITFALL: What you MUST do when you can't use the npm package** — Don't try to make Tauri IPC work. Use HTTP `fetch()` to `http://localhost:<port>` instead. The `__TAURI__` approach requires `@tauri-apps/api` which needs a bundler (Vite, Webpack). If using a static `dist/` with `<script src="app.js">`, skip Tauri IPC entirely and use an HTTP API.

**PITFALL: Tauri shim overwrites real IPC** — Even if `window.__TAURI__` IS available (npm package installed), placing a browser shim **unconditionally** in index.html OVERWRITES the real Tauri IPC object. All `invoke()` calls silently return `undefined`. The app falls back to HTTP API calls which fail if no backend is running. This looks like Tauri IPC works but actually the no-op shim is active. Always wrap the shim in `if (!window.__TAURI__)`.

**Symptom of bad shim:** Tauri command detection returns `true` (the shim defines `invoke` as a function) but calls return `undefined`. The app falls back to HTTP API calls which fail if no backend is running. This looks like Tauri IPC works but actually the no-op shim is active.

## Runtime Tauri Detection + Dual API Bridge

For static-frontend Tauri apps that need to work both inside Tauri (using `invoke()`) and in a browser (using `fetch()`), implement a runtime detection bridge:

```javascript
const isTauri = typeof window !== 'undefined' && window.__TAURI__ !== undefined;
const invoke = isTauri ? window.__TAURI__.core.invoke : null;

async function apiCall(method, path, body) {
  if (isTauri && invoke) {
    // Map REST calls to Tauri commands
    const cmdMap = {
      'GET:/api/health': 'get_health',
      'GET:/api/channels': 'get_channels',
      'POST:/api/auth/register': 'register',
      'POST:/api/messages': 'send_message',
      // ... map all endpoints
    };
    const cmd = cmdMap[method + ':' + path];
    if (cmd) {
      const result = await invoke(cmd, buildArgs(cmd, body));
      // Tauri Rust commands return JSON strings — parse them
      return typeof result === 'string' ? JSON.parse(result) : result;
    }
  }
  // Fallback to fetch for browser dev
  return fetchApi(method, path, body);
}
```

**Why this matters:**
- Tauri `invoke()` is faster (no HTTP overhead, no CORS, no port binding)
- `fetch()` fallback lets you develop the frontend in a regular browser without running Tauri
- The same HTML/JS file works in both contexts — no build step changes needed
- Each Rust command handler returns `Result<String, String>` where the Ok value is a JSON string that the frontend parses

**Rust command signature pattern:**
```rust
#[tauri::command]
fn get_health(state: tauri::State<'_, Mutex<AppState>>) -> Result<String, String> {
    let api_base = state.lock().map_err(|e| e.to_string())?.api_base.clone();
    let rt = tokio::runtime::Runtime::new().map_err(|e| e.to_string())?;
    rt.block_on(api::get_health(&api_base))
}
```

The `api::get_health()` async function returns `Result<String, String>` where Ok is the raw JSON response body from the backend. The frontend receives this string and calls `JSON.parse()`.

**PITFALL: `Runtime::new()` per command** — Creating a new tokio runtime for every command is inefficient. For production, use `#[tokio::main]` or a shared runtime. For MVP/static frontend apps, it's acceptable since the overhead is negligible for UI-driven calls.

**PITFALL: Command argument naming** — Tauri camelCases Rust snake_case arguments automatically. `channel_id` in Rust becomes `channelId` in the frontend `invoke()` call. Match the Tauri convention or use `#[serde(rename = "channelId")]` on the Rust side.

**PITFALL: `icon` field location in Tauri 2** — In Tauri v2, `icon` goes ONLY under `bundle.icon`, NOT under `app`. The old Tauri 1 convention of putting it in `app.icon` causes `unknown field 'icon'` panic during `tauri_build::build()`. Error message: `unknown field 'icon', expected one of: windows, security, tray-icon, ...`.

```json
// WRONG — Tauri 2 will panic:
{
  "app": {
    "icon": ["icons/32x32.png"]  // ❌ unknown field
  }
}

// CORRECT — only under bundle:
{
  "bundle": {
    "active": true,
    "icon": ["icons/32x32.png", "icons/128x128.png"]
  }
}
```

**PITFALL: `frontendDist` path resolution** — `frontendDist` is relative to the tauri.conf.json directory. A common mistake is using `"../dist"` thinking it's relative to the project root when the config is in a subdirectory. If tauri.conf.json is at `src/desktop/tauri.conf.json`, use `"frontendDist": "dist"` for the `src/desktop/dist/` directory, NOT `"frontendDist": "../dist"` which would resolve to the parent of `src/desktop/`.

## Icon Requirements

**Critical:** Tauri requires icons to be **RGBA PNG** format. ImageMagick's `convert` (or `magick convert`) strips the alpha channel by default, producing RGB PNGs that cause:

```
error: proc macro panicked
  --> src-tauri/src/lib.rs:182:14
   |
182 |         .run(tauri::generate_context!())
   |              ^^^^^^^^^^^^^^^^^^^^^^^^^^
   |
   = help: message: icon ... is not RGBA
```

### Generating RGBA Icons Correctly

Use Python PIL (Pillow):

```python
from PIL import Image

src = Image.open('/path/to/source.png').convert('RGBA')

sizes = {
    '32x32.png': 32,
    '128x128.png': 128,
    '128x128@2x.png': 256,
    'icon.png': 512,
    # Windows Store sizes (if building for Windows)
    'Square30x30Logo.png': 30,
    'Square44x44Logo.png': 44,
    'Square71x71Logo.png': 71,
    'Square89x89Logo.png': 89,
    'Square107x107Logo.png': 107,
    'Square142x142Logo.png': 142,
    'Square150x150Logo.png': 150,
    'Square284x284Logo.png': 284,
    'Square310x310Logo.png': 310,
    'StoreLogo.png': 300,
}

for fname, size in sizes.items():
    img = src.resize((size, size), Image.LANCZOS)
    img.save(fname, 'PNG')
```

For icon.ico (Windows):
```python
ico_sizes = [16, 32, 48, 256]
ico_images = [src.resize((s, s), Image.LANCZOS) for s in ico_sizes]
ico_images[0].save('icon.ico', 'ICO', sizes=[(i.width, i.height) for i in ico_images])
```

icon.icns (macOS) cannot be generated natively on Linux without extra tooling. Keep the existing .icns or use `png2icns`.

### Icon Paths in tauri.conf.json

Configured under `bundle.icon`:
```json
"bundle": {
    "icon": [
        "icons/32x32.png",
        "icons/128x128.png",
        "icons/128x128@2x.png",
        "icons/icon.icns",
        "icons/icon.ico"
    ]
}
```

## Desktop Integration (Linux/App Launcher)

### Installing System Icons

Use the app identifier from `tauri.conf.json` (e.g. `com.kicks.guitar-workstation`):

```bash
APP_ID="com.my-app"
ICONS_SRC="src-tauri/icons"
ICONS_DST="$HOME/.local/share/icons/hicolor"

for size in 32 128 256; do
    case $size in
        256) src_file="128x128@2x.png" ;;
        *)   src_file="${size}x${size}.png" ;;
    esac
    install -Dm644 "$ICONS_SRC/$src_file" "$ICONS_DST/${size}x${size}/apps/$APP_ID.png"
done

# HiDPI (512px)
install -Dm644 "$ICONS_SRC/icon.png" "$ICONS_DST/512x512/apps/$APP_ID.png"
```

### Desktop File

```ini
[Desktop Entry]
Type=Application
Name=Kicks
Comment=Guitar & Bass Workstation
Exec=/absolute/path/to/target/release/<binary_name>
TryExec=/absolute/path/to/target/release/<binary_name>
Icon=/absolute/path/to/icon.png
Categories=Audio;AudioVideo;
Terminal=false
StartupNotify=true
```

**PITFALL: Icon path in Desktop Entry** — Use an **absolute path** to the PNG file (`Icon=/home/user/.local/share/icons/hicolor/256x256/apps/app.png`) instead of the icon theme name (`Icon=com.my-app`). Some launchers (Walker, rofi) may not resolve themed icon names properly when the icon cache fails to generate. An absolute path always works.

**PITFALL: Missing `TryExec`** — Without `TryExec`, launchers may show the entry even if the binary is missing. Always include `TryExec` pointing to the same path as `Exec`.

Place at `~/.local/share/applications/<APP_ID>.desktop`. After installing:
```bash
update-desktop-database ~/.local/share/applications/
```

### Launcher Cache (Walker / rofi)

When testing changes through a launcher like Walker:

1. **Test from terminal first** — run `./target/release/<binary_name>` directly. If it works from terminal but not from launcher, the issue is the `.desktop` file or launcher cache, not the app.
2. **Kill and restart** — `killall walker && sleep 1 && walker &` forces a fresh read of `.desktop` files.
3. **Clear cache** — `rm -rf ~/.cache/walker` removes any stale icon or app-list cache.
4. **Full session restart** — if the icon still shows as a question mark after all of the above, log out and back in. Some Wayland compositors cache window icons across sessions.

## Git Tracking for Static Frontend Dist

When a Tauri project uses a **static frontend** (no bundler — `beforeBuildCommand: ""`, `dist/` IS the source), the `dist/` directory should be tracked by git.

The problem: common `.gitignore` patterns like `**/dist/` or `dist/` at the project root will exclude `src/desktop/dist/` from version control. Since there's no build step to regenerate it, the frontend is lost on checkout.

**Fix:** Create a local `.gitignore` override inside the Tauri directory:

```
# src/desktop/.gitignore
# Track dist/ — it's the source for Tauri desktop (no build step)
!dist/
```

This only un-ignores `dist/` in THIS directory. The parent `.gitignore`'s `**/dist/` is overridden for this subtree.

**Do NOT rely on `gtk-update-icon-cache`** — on Arch with hicolor, it often fails with "The generated cache was invalid". Since we use absolute icon paths in the `.desktop` file, the cache is irrelevant. If you must use themed icon names instead, install missing sizes and force-refresh:

```bash
# Ensure all sizes exist (launchers often need 32x32 and 48x48)
python3 -c "
from PIL import Image
src = Image.open('path/to/icon.png').convert('RGBA')
for size in [32, 48, 128, 256]:
    img = src.resize((size, size), Image.LANCZOS)
    path = f'/home/user/.local/share/icons/hicolor/{size}x{size}/apps/{APP_ID}.png'
    img.save(path, 'PNG')
"

# The cache may still fail — that's OK if using absolute paths
gtk-update-icon-cache -f ~/.local/share/icons/hicolor/ 2>/dev/null || true
```

## Binary Naming

The Cargo binary name defaults to `[package].name` in `src-tauri/Cargo.toml`. To override:

```toml
[package]
name = "app"           # default binary name = "app"

[[bin]]
name = "kicks"         # override: binary will be "kicks"
path = "src/main.rs"
```

If you don't add a `[[bin]]` section, create a symlink:
```bash
ln -sf target/release/<actual_name> target/release/<desired_name>
```

## Packaging

### Flatpak

The flatpak manifest (`flatpak/<APP_ID>.yml`) references `src-tauri/icons/` — update icons there and the build picks them up. The binary is installed as the `command:` value, not the Cargo package name:

```yaml
command: kicks
...
- install -Dm755 target/release/kicks -t /app/bin/
```

If your binary name differs, adjust the install command or add a `[[bin]]` section.

### Snap

Same pattern in `snap/snapcraft.yaml` — icons from `src-tauri/icons/`, binary name must match.

## Absorbed Skills (Consolidated 2026-05-27)

- **rust-tauri-desktop-app** — Full Tauri 2 lifecycle guide (Rust HTTP client via reqwest, IPC command pattern, Cargo.toml setup). Its reqwest API client pattern is in `references/rust-api-client-pattern.md`. All other content is covered by sections above.
- **tauri-2-frontend-embedding** — White screen / "cannot connect to host" fix from missing `custom-protocol` feature + Vite 8 crossorigin stripping. Fully covered in the "WebView: White Screen" section above and `references/vite8-crossorigin-whitescreen.md`.

## Common Pitfalls

| Pitfall | Symptom | Fix |
|---------|---------|-----|
| Non-RGBA icons | `proc macro panicked: icon is not RGBA` | Use PIL with `.convert('RGBA')` |
| Missing webkit2gtk-4.1 | `error: pkg-config: package 'webkit2gtk-4.1' not found` | Install `webkit2gtk-4.1` (NOT `webkit2gtk` alone) |
| Wrong binary name | `Exec=` in .desktop points to nonexistent file | Check `[package].name`, add `[[bin]]` section if needed |
| Frontend not built | Tauri sends old/empty dist | Run `npm run build` explicitly in frontend/ first |
| Missing libsoup3 | Linker errors for libsoup | Install `libsoup3` |
| Missing appindicator | Runtime warnings about tray icon | Install `libayatana-appindicator` |
| `icon` in wrong section | `unknown field 'icon'` during `tauri_build::build()` | Move to `bundle.icon` — never `app.icon` in Tauri 2 |
| `crate-type` missing from Cargo.toml | Linker errors when using `lib.rs` + `main.rs` pattern | Add `[lib] crate-type = ["lib", "cdylib", "staticlib"]` to Cargo.toml |
| `frontendDist` resolves to wrong dir | Tauri serves 404 or wrong content | Path is relative to tauri.conf.json directory, not project root |
| Inline `onclick` handlers in frontend HTML | Sidebar links, buttons, and tabs don't respond to clicks — no JS errors in console | Tauri webview CSP may block inline event handlers. Use **event delegation** instead: attach a single listener to a parent container, use `.closest()` and `data-*` attributes to identify targets. See "Tauri Webview: Inline onclick not working" below |
| Tauri shim overwrites real IPC | Sidebar and buttons render but nothing happens when clicked (even with event delegation). Tauri `invoke()` silently returns `undefined`. App works fine in standalone browser | The browser shim (`window.__TAURI__ = { core: { invoke: () => {} } }`) overwrites Tauri's real IPC when placed unconditionally in index.html. **Always wrap in `if (!window.__TAURI__)`** |
| Build script caches `dist/` content | After changing `dist/*` files, `cargo build --release` recompiles Rust but may NOT re-embed the new frontend. The build script (`build.rs` -> `tauri_build::build()`) only watches `tauri.conf.json` via `cargo:rerun-if-changed`. `dist/` file changes are invisible to Cargo's build script cache | Run `cargo clean && cargo build --release` when changing frontend files in a static-frontend Tauri project. Normal incremental builds reuse the cached build script output |
| `gtk-update-icon-cache` fails on hicolor | `The generated cache was invalid` when running `gtk-update-icon-cache ~/.local/share/icons/hicolor/` | Use absolute icon paths in `.desktop` file instead of themed names. The cache is irrelevant with absolute paths. Ensure all needed icon sizes exist (32x32, 48x48, 128x128, 256x256) |
| Vite 8 `crossorigin` attribute on module scripts | White screen with "cannot connect to host" in desktop (works in browser dev). Tauri 2's custom asset protocol doesn't set CORS headers, so `crossorigin` causes WebView to silently reject module scripts | Create a custom Vite plugin with `transformIndexHtml` hook to strip `crossorigin` from the built HTML (see WebView: White Screen below) |
| CSP too restrictive for React modules | JS errors, blank page, script-src violations in console | Add `'unsafe-eval'` to `script-src` for module loaders, `blob:` to `img-src` for programmatic images |
| `"csp": null` blocks inline `<script>` tags | App renders static HTML skeleton but nothing interactive works — sidebar clicks, forms, auth — all dead. No JS errors in console because the script never executes | Tauri 2's `"csp": null` does **not** mean "no CSP" — it activates an internal default of `default-src 'self'` which does NOT include `'unsafe-inline'` for `script-src`. Inline `<script>` tags are silently blocked. **Fix: move all JS to an external file** (`<script src="app.js">`) which `'self'` allows. Or set an explicit CSP. Production recommendation: external scripts + explicit CSP with `script-src 'self'` (no `unsafe-inline` needed) |
| Static HTML icon paths resolve outside dist/ | `<img src="../icons/logo.png">` shows broken image / `?` placeholder | Tauri 2 serves all assets relative to `frontendDist`. `../icons/` goes outside that scope. **Fix: copy icons into `dist/icons/`** and reference as `icons/logo.png`. Or use `bundle.resources` config to make outside directories available |
| WebKit form elements show white background / invisible text | `<input>`, `<textarea>`, `<select>` render with white background and dark text regardless of CSS | WebKit2GTK applies native widget styling that overrides CSS. **Fix:** add `!important` to `background` and `color` on ALL form elements, plus `-webkit-appearance: none; appearance: none;` to strip native chrome. See "WebKit Form Styling" section below |
| `fetch()` calls in inline HTML silently fail | "Enter the Grid" / submit buttons do nothing — no error, no network request, button stays clickable | `fetch()` throws `TypeError: Failed to fetch` when the backend is unreachable. Without try/catch, this kills the handler silently. **Fix:** wrap `fetch` in try/catch, return `{success: false, error: msg}`. Wrap button handlers in try/catch + show error to user. See "fetch() Error Handling" section below |

## WebKit Form Styling (Dark Theme)

### Symptom
`<input>`, `<textarea>`, and `<select>` elements render with white backgrounds and dark text, making labels and user-entered text invisible against a dark theme. CSS like `background: var(--bg-secondary); color: var(--text-primary);` appears to be ignored.

### Root Cause
WebKit2GTK (the engine behind Tauri's webview on Linux) applies native form widget styling that takes priority over regular CSS declarations. This is NOT a CSS specificity issue — it's the rendering engine's native theme overriding your styles at the widget level.

### Fix

Apply `!important` to `background` and `color`, plus strip native appearance:

```css
/* All form inputs */
.janus-input, .janus-select, .janus-textarea {
  background: var(--bg-secondary) !important;
  color: var(--text-primary) !important;
  -webkit-appearance: none;
  appearance: none;
}

/* Select dropdown options also need forcing */
.janus-select option {
  background: var(--bg-secondary) !important;
  color: var(--text-primary) !important;
}

/* Chat input textarea (dynamically rendered) */
.chat-input {
  background: var(--bg-tertiary) !important;
  color: var(--text-primary) !important;
  -webkit-appearance: none;
  appearance: none;
}
```

**Every `<textarea>`, `<input>`, and `<select>` in the Tauri app needs this treatment** — including ones rendered dynamically via `innerHTML`. Use a broad selector (class on all form elements) rather than per-element styling.

### Verification
Type into every input field. Text should be clearly visible against the dark background. Select dropdowns should show dark background with light text for both the selected value and the dropdown options.

## fetch() Error Handling in Inline HTML

### Symptom
A button (e.g. "Enter the Grid") that calls `fetch()` to a backend API does nothing when clicked — no error message, no loading state change, the button stays idle. The issue is especially common when the backend at `localhost:PORT` is not running.

### Root Cause
When `fetch()` cannot reach the server, it throws `TypeError: Failed to fetch`. In inline HTML apps (no module system, no error boundary), this exception:
1. Propagates up through the async handler
2. Is NOT caught by any global error handler (the browser logs it to console but the Tauri window has no visible console)
3. The UI appears completely unresponsive — no feedback, no error banner

### Fix: Bulletproof apiCall Pattern

```javascript
async function apiCall(method, path, body = null) {
  try {
    const headers = { 'Content-Type': 'application/json' };
    if (state.authToken) headers['Authorization'] = 'Bearer ' + state.authToken;
    const opts = { method, headers };
    if (body) opts.body = JSON.stringify(body);
    const res = await fetch(API_BASE + path, opts);
    if (!res.ok) {
      var errBody = await res.text().catch(function() { return ''; });
      try { return JSON.parse(errBody); } catch(_) {}
      return { success: false, error: 'Server error: ' + res.status + ' ' + res.statusText };
    }
    return await res.json();
  } catch (e) {
    return { success: false, error: 'Cannot connect to server at ' + API_BASE + '. Is the backend running?' };
  }
}
```

### Fix: Button Handler Pattern

```javascript
async function handleAuth(event) {
  event.preventDefault();
  var btn = event.target.querySelector('.form-submit');
  var origText = btn ? btn.innerHTML : '';
  if (btn) { btn.disabled = true; btn.innerHTML = 'Connecting...'; }
  try {
    // ... api calls ...
    if (!result.success) {
      showError(result.error || 'Authentication failed');
    }
  } catch (e) {
    showError('Unexpected error: ' + (e.message || 'Unknown'));
  } finally {
    if (btn) { btn.disabled = false; btn.innerHTML = origText; }
  }
}
```

Key elements:
- **Button loading state** — disable + change text so user knows something happened
- **try/catch in handler** — even if `apiCall` is safe, the handler itself can fail
- **finally restores button** — always re-enable, even on error
- **Error banner visible to user** — never rely on console.log for user-facing errors in Tauri

## WebView: Inline onclick Not Working

### Symptom
Sidebar links, buttons, and tabs in the Tauri app's frontend don't respond to clicks. No JavaScript errors in the console. The same HTML works perfectly when opened directly in a browser.

### Root Cause
Tauri's webview (webkit2gtk-4.1) may block **inline event handlers** (`onclick="handler()"`, `onsubmit="handler(event)"`, etc.) depending on the Content Security Policy. Even with `"csp": null` (which disables CSP), the webview can still reject inline handlers because they're implemented via DOM attribute reflection rather than `addEventListener`.

### Fix: Event Delegation

Instead of inline onclick on each element:

```html
<!-- DON'T: inline onclick -->
<nav>
  <a onclick="switchView('dashboard')">Dashboard</a>
  <a onclick="switchView('chat')">Chat</a>
</nav>
```

Use a single listener on the parent with `data-*` attributes:

```html
<!-- DO: data-view attributes, no onclick -->
<nav id="sidebar-nav">
  <a data-view="dashboard">Dashboard</a>
  <a data-view="chat">Chat</a>
</nav>
```

```javascript
// Single event delegation handler
document.getElementById('sidebar-nav').addEventListener('click', (e) => {
  const link = e.target.closest('[data-view]');
  if (link) {
    e.preventDefault();
    const view = link.dataset.view;
    if (view) switchView(view);
  }
});
```

For buttons that don't navigate to a view (e.g., theme picker, logout), use `data-action`:

```html
<a data-action="theme">Themes</a>
```

```javascript
document.querySelector('[data-action="theme"]')?.addEventListener('click', (e) => {
  e.preventDefault();
  openThemeDialog();
});
```

This pattern works reliably in Tauri webviews because it uses standard `addEventListener` which is never blocked, rather than inline HTML attributes which the webview may refuse to evaluate.

### Form Delegation (onsubmit)

The same inline handler restriction applies to `onsubmit` on `<form>` elements. Use a global `submit` listener on `document` with `e.target.matches()`:

```html
<!-- DON'T: inline onsubmit -->
<form onsubmit="handleSubmit(event)">
  <button type="submit">Send</button>
</form>
```

```html
<!-- DO: form with an ID, no onsubmit -->
<form id="my-form">
  <button type="submit">Send</button>
</form>
```

```javascript
// Single form submission delegator
document.addEventListener('submit', (e) => {
  if (e.target.matches('#my-form')) {
    e.preventDefault();
    handleSubmit(e);
  }
  // Chain other forms
  if (e.target.matches('#other-form')) {
    // ...
  }
});
```

The `submit` event bubbles in WebKit, so a single `document` listener catches all dynamically-rendered forms.

### Verification
After fixing, test by clicking every interactive element in the Tauri window. Monitor the console for any CSP errors. If all clicks work, the fix is complete. Rebuild with `cargo build --release` since the frontend is embedded at compile time.

### Symptom
The Tauri app opens a window but shows either a completely white screen or a WebKit error page saying "cannot connect to host." The app works fine when run in the browser via `vite dev`.

### Root Cause
Vite's default build output adds a `crossorigin` attribute to `<script type="module">` and `<link rel="stylesheet">` tags in the built `index.html`:

```html
<script type="module" crossorigin src="/assets/index-abc123.js"></script>
<link rel="stylesheet" crossorigin href="/assets/index-def456.css">
```

Tauri 2 serves bundled assets via a custom protocol (e.g. `tauri://localhost` on Linux, `https://tauri.localhost` on Mac). This protocol does NOT set CORS headers. When the WebView encounters a `crossorigin` attribute on a resource load, it expects a CORS response header from the server. Without it, the browser silently rejects the resource — the JS module never executes, the CSS never applies, leaving a white screen.

### Fix: Custom Vite Plugin to Strip crossorigin

**Vite 8+ only** — earlier versions had a `build.crossorigin` config option, but Vite 8 removed it from `BuildEnvironmentOptions`:

```ts
// vite.config.ts
import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

// Removes crossorigin from built HTML for Tauri 2 WebView compatibility.
function removeCrossorigin(): import('vite').Plugin {
  return {
    name: 'remove-crossorigin',
    enforce: 'post',
    transformIndexHtml(html) {
      return html.replaceAll(' crossorigin', '')
    },
  }
}

export default defineConfig({
  plugins: [react(), removeCrossorigin()],
  // ...
})
```

After adding the plugin:
1. `npm run build` — rebuild the frontend
2. `cargo build --release` — rebuild the Rust binary (assets are embedded at compile time)

### CSP Configuration

For Tauri 2 apps using SPA frameworks (React, Vue, Svelte), the Content Security Policy in `tauri.conf.json` should be at minimum:

```json
"security": {
  "csp": "default-src 'self'; connect-src 'self'; script-src 'self' 'unsafe-eval'; style-src 'self' 'unsafe-inline'; img-src 'self' data: blob:;"
}
```

Key additions vs the default `'self'`-only:
- `'unsafe-eval'` — required by some bundler module loaders and source maps
- `blob:` in `img-src` — required for programmatic image generation/canvas-to-blob patterns
- `'unsafe-inline'` in `style-src` — already common but essential for CSS-in-JS

### Verification

```bash
# Build the frontend
cd frontend && npm run build
grep -c 'crossorigin' dist/index.html
# Should output: 0  (no crossorigin attributes)

# Rebuild and test
cd .. && cargo build --release
./target/release/<binary_name>
# Window should display the app UI, not a white screen
```

## Verification: Embedded Frontend

After `cargo build --release`, Tauri compresses frontend assets with **brotli** and embeds them in the binary under `target/release/build/<pkg>-*/out/tauri-codegen-assets/`. The files are named by content hash (e.g. `baf0652b...html`).

### Decompress to verify content

```bash
# Find the assets directory (hash suffix varies)
ASSETS_DIR=$(find target/release/build -type d -name tauri-codegen-assets | head -1)

# Decompress the embedded HTML
cp "$ASSETS_DIR"/*.html /tmp/embedded.br
brotli -d /tmp/embedded.br -o /tmp/embedded.html

# Check index.html for your fix
grep -c 'your-fix-string' /tmp/embedded.html

# Decompress the embedded JS
JS_FILE=$(ls "$ASSETS_DIR"/*.js)
cp "$JS_FILE" /tmp/embedded.js.br
brotli -d /tmp/embedded.js.br -o /tmp/embedded.js

# Check for your fix
grep -c 'setupEventDelegation' /tmp/embedded.js
```

**Do NOT rely on `strings`** to find frontend content — Tauri compresses assets, so `strings` won't find embedded HTML/JS/CSS content.

## Socket.IO WebSocket in Static Tauri Frontend

For real-time messaging in a Tauri app with static HTML/JS (no bundler), load the Socket.IO client from CDN and implement a `SocketManager` class:

### 1. Load Socket.IO Client

```html
<head>
  <script src="https://cdn.socket.io/4.8.1/socket.io.min.js"
    integrity="sha384-mkQ3/7FUtcGyoppY6bz/PORYoGqOl7/aSUMn2ymDOJcapfS6PHqxhRTMh1RR0Q6+"
    crossorigin="anonymous"></script>
</head>
```

### 2. SocketManager Class

```javascript
const SocketManager = {
  socket: null,
  connected: false,
  currentChannelId: null,

  init() {
    if (typeof io === 'undefined') {
      console.warn('Socket.IO not loaded');
      return;
    }
    this.socket = io(API_BASE, {
      transports: ['websocket', 'polling'],
      reconnection: true,
      reconnectionDelay: 2000,
      reconnectionAttempts: Infinity,
    });

    this.socket.on('connect', () => {
      this.connected = true;
      this.authenticate();
      if (this.currentChannelId) this.joinChannel(this.currentChannelId);
    });

    this.socket.on('disconnect', () => { this.connected = false; });
    this.socket.on('message:new', (msg) => this.onMessage(msg));
    this.socket.on('message:stream:start', (data) => this.onStreamStart(data));
    this.socket.on('message:stream:chunk', (data) => this.onStreamChunk(data));
    this.socket.on('message:stream:end', (msg) => this.onStreamEnd(msg));
    this.socket.on('presence:update', (data) => this.onPresence(data));
    this.socket.on('orchestrate:progress', (data) => this.onOrchestration(data));
  },

  authenticate() {
    if (!this.socket || !state.authToken) return;
    this.socket.emit('auth', {
      token: state.authToken,
      userId: state.userId,
      userName: state.userName,
      userType: 'human'
    });
  },

  joinChannel(channelId) {
    if (this.currentChannelId && this.currentChannelId !== channelId) {
      this.socket?.emit('channel:leave', this.currentChannelId);
    }
    this.currentChannelId = channelId;
    this.socket?.emit('channel:join', channelId);
  },

  sendMessage(channelId, content, authorId, authorName, authorType) {
    this.socket?.emit('message:send', {
      channelId, content, authorId, authorName, authorType
    });
  },

  onMessage(msg) {
    // Append to chat DOM without reloading view
    const container = document.getElementById('messages-container');
    if (!container || msg.channelId !== this.currentChannelId) return;
    // Build message bubble and append
    const bubble = document.createElement('div');
    bubble.className = 'chat-message ' + (msg.authorType === 'human' ? 'user' : 'ai');
    bubble.innerHTML = '...'; // format message content
    container.appendChild(bubble);
    container.scrollTop = container.scrollHeight;
  },

  onStreamStart(data) {
    // Create placeholder message with blinking cursor
  },
  onStreamChunk(data) {
    // Append chunk to placeholder content
  },
  onStreamEnd(msg) {
    // Replace placeholder with final message
  },
  onPresence(data) {
    // Update user avatar glow, online indicators
  },
  onOrchestration(data) {
    // Show toast for swarm progress, refresh Swarm view
  }
};
```

### 3. Wire Into Auth Flow

```javascript
// On successful auth:
SocketManager.init();
SocketManager.authenticate();

// On channel select:
SocketManager.joinChannel(channelId);

// On message send (try socket first, fallback to REST):
async function sendChatMessage(event) {
  event.preventDefault();
  const content = document.getElementById('chat-input').value.trim();
  if (!content || !state.currentChannelId) return;

  if (SocketManager.connected) {
    SocketManager.sendMessage(state.currentChannelId, content, state.userId, state.userName, 'human');
    document.getElementById('chat-input').value = '';
    // Optimistic UI: append immediately
  } else {
    // Fallback to REST
    await apiCall('POST', '/api/messages', { ... });
    await loadView('chat'); // reload to show new message
  }
}
```

### 4. Connection Status UI

Update the header status indicator to show "Live" when socket is connected:

```javascript
function setConnectionStatus(connected) {
  const dot = document.getElementById('conn-dot');
  const text = document.getElementById('conn-text');
  if (dot) dot.className = 'dot ' + (connected ? 'connected' : 'disconnected');
  if (text) text.textContent = connected ? 'API Connected ● Live' : 'Disconnected';
}
```

### Key Pitfalls

| Pitfall | Symptom | Fix |
|---------|---------|-----|
| Socket.IO CDN blocked by CSP | `io is not defined` | Add CDN domain to `script-src` in tauri.conf.json security.csp, or use `bundle.resources` to embed the file locally |
| `message:new` not firing | Messages only appear after page reload | Check that `channel:join` was emitted after `auth:success`. The server only broadcasts to joined rooms |
| Stream chunks out of order | AI message shows garbled text | Chunks arrive in order over a single socket connection, but if using multiple sockets they may interleave. Use a single socket per client |
| Socket reconnects but doesn't rejoin channel | No real-time messages after reconnect | Re-emit `channel:join` in the `connect` handler, not just on initial setup |
| `fetch()` fallback called even when socket works | Double messages appear | Check `SocketManager.connected` BEFORE calling `apiCall()`. The socket send and REST post both create messages |

## Verification: Socket.IO Events

After connecting, verify events flow:

```javascript
// In browser DevTools (Tauri: Ctrl+Shift+I in debug mode)
SocketManager.socket.onAny((event, ...args) => {
  console.log('Socket event:', event, args);
});
```

Expected sequence on chat open:
1. `connect` → socket.id assigned
2. `auth` (client→server) → `auth:success` (server→client)
3. `channel:join` (client→server) → `messages:history` (server→client)
4. `message:send` (client→server) → `message:new` (server→all in room)

If any step is missing, check the server Socket.IO handler logs.

## JACK Audio Backend (Linux Pro-Audio)

For Tauri apps that need to appear as a JACK client in qpwgraph / Catia (e.g., guitar amp simulators, DAWs, audio workstations), the standard CPAL backend won't show up in JACK patchbays because CPAL on Linux uses ALSA/PulseAudio by default.

### The Pattern: Custom ProcessHandler with Owned Ports

The `jack` crate 0.9 requires ports to be owned by the `ProcessHandler` struct. You cannot capture `Port<AudioIn>` in a `ClosureProcessHandler` closure because the closure type becomes unnameable and can't be stored in `AsyncClient<N, P>`.

**Solution:** Implement a custom struct that holds both the engine and the ports:

```rust
use jack::{Client, Control, ProcessHandler, ProcessScope, Port, AudioIn, AudioOut};
use std::sync::{Arc, Mutex};

pub struct JackProcessHandler {
    engine: Arc<Mutex<MyEngine>>,
    in_l: Port<AudioIn>,
    in_r: Port<AudioIn>,
    out_l: Port<AudioOut>,
    out_r: Port<AudioOut>,
}

impl ProcessHandler for JackProcessHandler {
    fn process(&mut self, _client: &Client, ps: &ProcessScope) -> Control {
        let in_l_buf = self.in_l.as_slice(ps);
        let in_r_buf = self.in_r.as_slice(ps);
        let out_l_buf = self.out_l.as_mut_slice(ps);
        let out_r_buf = self.out_r.as_mut_slice(ps);

        let n = ps.n_frames() as usize;
        // ... run DSP, write to output buffers ...

        Control::Continue
    }
}
```

**Key rules:**
- Ports are registered on the `Client` BEFORE activation, then moved into the handler struct
- The handler struct is passed to `client.activate_async((), handler)`
- `Port<AudioIn>` is `Send`, so it can live in the handler
- `Port<AudioOut>::as_mut_slice()` requires `&mut self`, so the handler must be `mut` in `process()`
- Do NOT try to store ports in `JackAudioIO` AND the handler — move them into the handler

### Tauri Integration

Add a `jack_audio_io: Mutex<Option<JackAudioIO>>` field to `AppState`. In `start_engine`, branch on `config.audio_backend`:

```rust
match config.audio_backend {
    AudioBackend::Jack => {
        let mut jack_io = state.jack_audio_io.lock()?;
        *jack_io = Some(JackAudioIO::new(JackConfig {
            client_name: "Kicks".to_string(),
        }));
        if let Some(ref mut io) = *jack_io {
            io.start(engine_arc.clone(), Some(cpu_load))?;
        }
    }
    AudioBackend::Cpal => { /* existing CPAL path */ }
}
```

**Port naming convention:** Use `in_l`, `in_r`, `out_l`, `out_r` so qpwgraph shows them as `Kicks:in_l`, `Kicks:out_l`, etc.

**System deps:** `pipewire-jack`, `jack2`, `libjack` development headers. On Arch: `sudo pacman -S pipewire-jack pipewire-audio jack2`.

### Verification

```bash
# After starting the app, check JACK clients
jack_lsp | grep -i kicks
# Expected: Kicks:in_l, Kicks:in_r, Kicks:out_l, Kicks:out_r

# In qpwgraph, look for "Kicks" node with 2 inputs + 2 outputs
# Connect your audio interface capture to Kicks:in_l/in_r
# Connect Kicks:out_l/out_r to your audio interface playback
```

## Verification: Binary + Desktop Integration

```bash
# Check binary exists
file target/release/<binary_name>

# Check shared libraries are linked
ldd target/release/<binary_name> | grep -E "webkit|gtk|soup|javascript"

# Quick smoke test (app should stay alive)
timeout 5 target/release/<binary_name>
# exit 124 = success (killed by timeout, not crash)

# Check desktop file is registered
ls -la ~/.local/share/applications/<APP_ID>.desktop

# Check icons registered
find ~/.local/share/icons/hicolor/ -name "<APP_ID>.png"
```
