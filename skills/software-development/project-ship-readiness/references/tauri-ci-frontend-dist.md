# Tauri CI: `frontendDist` Must Exist Before `cargo clippy`

## Problem

In a Tauri project, `cargo clippy` compiles the Rust backend crate (`src-tauri/`). The entry point calls `tauri::generate_context!()`, a proc macro that reads `tauri.conf.json` at compile time and validates that `frontendDist` points to an existing directory.

If your CI workflow has separate jobs for "Rust quality" and "Frontend build", the Rust job fails because `frontend/dist` doesn't exist yet:

```
error: proc macro panicked
   --> src-tauri/src/lib.rs:187:14
    |
187 |         .run(tauri::generate_context!())
    |              ^^^^^^^^^^^^^^^^^^^^^^^^^^^
    |
    = help: message: The `frontendDist` configuration is set to "../frontend/dist" but this path doesn't exist
```

## Root Cause

`tauri::generate_context!()` is not just a runtime helper — it embeds asset metadata at compile time. It needs the built frontend to exist during `cargo check`, `cargo clippy`, and `cargo build`.

## Fix

Add Node setup and frontend build steps to the Rust quality job **before** clippy:

```yaml
  quality:
    name: Rust — fmt, clippy, build, test
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v4

      - name: Install Rust toolchain
        uses: dtolnay/rust-toolchain@stable
        with:
          components: clippy, rustfmt

      - name: Install system dependencies
        run: |
          sudo apt-get update
          sudo apt-get install -y libjack-jackd2-dev libasound2-dev \
            libwebkit2gtk-4.1-dev libgtk-3-dev libayatana-appindicator3-dev

      # === ADD THESE STEPS ===
      - name: Setup Node
        uses: actions/setup-node@v4
        with:
          node-version: 22
          cache: npm
          cache-dependency-path: frontend/package-lock.json

      - name: Install frontend dependencies
        run: npm ci
        working-directory: frontend

      - name: Build frontend
        run: npm run build
        working-directory: frontend
      # ========================

      - name: Rust Cache
        uses: Swatinem/rust-cache@v2
        with:
          workspaces: "src-tauri -> target"

      - name: Check formatting
        run: cargo fmt --check

      - name: Clippy
        run: cargo clippy --all-targets --all-features -- -D warnings

      - name: Build
        run: cargo build --all-features

      - name: Test
        run: cargo test --all-features
```

## Alternative: Dummy `frontend/dist`

If you want to keep jobs parallel and the frontend build is slow, you can create a minimal dummy `frontend/dist/index.html` before clippy. However, this may cause `generate_context!()` to emit different metadata than a real build, which can lead to subtle runtime issues. The frontend build step is the recommended approach.

## Verification

Before pushing, verify locally:

```bash
cd frontend && npm run build && cd ..
cargo clippy --all-targets --all-features -- -D warnings
```

If this passes locally but fails in CI, the CI is missing the frontend build step.

## Related

- Tauri docs: https://tauri.app/v1/api/config/#buildconfig
- `tauri::generate_context!()` source: validates `frontendDist` path existence at macro expansion time
