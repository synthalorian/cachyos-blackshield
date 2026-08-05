# Verifying Tauri 2 Embedded Frontend Assets

After `cargo build --release`, Tauri compresses frontend files (index.html, app.js, styles.css) with **brotli** and embeds them in the binary via `tauri::generate_context!()`.

## Quick Check

```bash
# Find the generated assets
ASSETS_DIR=$(find target/release/build -type d -name tauri-codegen-assets 2>/dev/null | head -1)
ls "$ASSETS_DIR"
# Shows: *.html, *.js, *.css, *.png (all brotli-compressed, content-hash named)
```

## Decompress & Inspect

```bash
# Decompress HTML
cp "$ASSETS_DIR"/*.html /tmp/check.html.br
brotli -d /tmp/check.html.br -o /tmp/check.html
grep 'if (!window.__TAURI__)' /tmp/check.html

# Decompress JS
JS_FILE=$(ls "$ASSETS_DIR"/*.js | head -1)
cp "$JS_FILE" /tmp/check.js.br
brotli -d /tmp/check.js.br -o /tmp/check.js
grep -c 'setupEventDelegation' /tmp/check.js

# Decompress CSS
CSS_FILE=$(ls "$ASSETS_DIR"/*.css | head -1)
cp "$CSS_FILE" /tmp/check.css.br
brotli -d /tmp/check.css.br -o /tmp/check.css
wc -l /tmp/check.css
```

## Verify Binary Size Changed

```bash
ls -la target/release/<binary_name>
# If size hasn't changed, the build script cached — run cargo clean
```

## Key Insight

- `strings` on the binary will **NOT** find embedded frontend content — it's compressed
- The build script (`build.rs` -> `tauri_build::build()`) outputs `cargo:rerun-if-changed=tauri.conf.json` but does NOT watch `dist/` files
- After modifying `dist/`, you MUST do `cargo clean && cargo build --release` to force the build script to re-run and re-embed the frontend
- Python `brotli` module (`pip install brotli`) can decompress these files too:

```python
import brotli
with open('/path/to/asset.html', 'rb') as f:
    data = brotli.decompress(f.read())
    print(f'Decompressed: {len(data)} bytes')
    print(data[:500].decode())
```
