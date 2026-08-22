# Verifying Tauri Embedded Frontend Assets

Tauri 2 compresses frontend assets with brotli before embedding them in the binary via `tauri_build::build()`. To inspect what's actually inside the binary without running it, decompress the embedded assets.

## Locate the assets directory

The assets directory name includes a content hash that varies per build:

```bash
ASSETS_DIR=$(find src-tauri/target/release/build -type d -name "tauri-codegen-assets" | head -1)
echo "$ASSETS_DIR"
# Example: src-tauri/target/release/build/tauri-<hash>/out/tauri-codegen-assets
```

## Decompress index.html

```bash
brotli -d "$ASSETS_DIR/index.html.br" -o /tmp/embedded-index.html
cat /tmp/embedded-index.html | head -30
```

Check for:
- Expected CSS variable declarations (theme init script)
- Correct JS chunk references
- No stale content from a previous build

## Decompress JS chunks

```bash
for f in "$ASSETS_DIR"/*.js.br; do
  brotli -d "$f" -o "/tmp/$(basename "$f" .br)"
done
ls -la /tmp/*.js
```

## Decompress CSS

```bash
for f in "$ASSETS_DIR"/*.css.br; do
  brotli -d "$f" -o "/tmp/$(basename "$f" .br)"
done
```

## Verify a specific fix is embedded

After making a frontend change and rebuilding:

```bash
# 1. Rebuild both
cd project-root
npm run build
cd src-tauri && cargo build --release

# 2. Decompress and check
ASSETS_DIR=$(find target/release/build -type d -name "tauri-codegen-assets" | head -1)
brotli -d "$ASSETS_DIR/index.html.br" -o /tmp/check.html

# 3. Grep for the fix
grep -c "your-fix-string" /tmp/check.html
# >0 = fix is embedded in the binary
```

## Why `strings` doesn't work

```bash
strings target/release/<binary> | grep "some-frontend-string"
# Returns nothing — assets are brotli-compressed, not stored as raw strings
```

Tauri's `tauri_build::build()` compresses assets with brotli (or gzip in some configs) before embedding. The binary contains compressed blobs, not plain text. Always use brotli decompression to inspect.

## Install brotli if missing

```bash
sudo pacman -S brotli    # Arch/CachyOS
# or
pip install brotlipy     # Python brotli bindings (alternative)
```

## Common findings

| Finding | Meaning |
|---------|---------|
| `index.html` references `/_app/immutable/chunks/X.js` but that file is missing from assets dir | Stale build — `npm run build` wasn't run before `cargo build --release` |
| Theme init script missing from `index.html` | `app.html` was edited after last `npm run build`, or build output is stale |
| `index.html` has `url` meta or redirect to localhost | `tauri.conf.json` `url` field is set — remove it for release |
| JS chunks present but app still blank | CSS/content issue, not asset embedding issue — check CSS vars, theme init, devUrl |
