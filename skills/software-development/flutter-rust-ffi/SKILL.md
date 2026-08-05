---
name: flutter-rust-ffi
description: >-
  Embed a Rust backend directly inside a Flutter app via flutter_rust_bridge.
  Covers codegen setup, Rust crate structure, build integration (cargokit + CMake),
  system-Rust workarounds (no rustup), offline-first architecture with local SQLite,
  and the full FFI bridge lifecycle.
version: 1.0.0
author: synthclaw
category: software-development
tags: [flutter, rust, ffi, flutter_rust_bridge, sqlite, native, offline-first]
triggers:
  - "embed Rust in Flutter"
  - "flutter_rust_bridge setup"
  - "Rust native library in Flutter"
  - "offline-first Rust backend"
  - "rusqlite in Flutter"
  - "cargokit build integration"
---

# Flutter + Rust FFI (flutter_rust_bridge)

Use this skill when building a **Flutter app with an embedded Rust native library**. The Rust code compiles to a shared library (.so/.dylib/.dll) that loads into the Flutter process at runtime. No separate server process, no network dependency, no port binding.

Architecture:
```
Flutter (Dart)  ←─ FFI ─→  Rust (cdylib)
                               ↕
                            SQLite (rusqlite bundled)
                               ↕
                         Bundled JSON assets (seeded on first launch)
```

## Quick Start

### Prerequisites

- Rust toolchain (cargo, rustc) — system install (Arch: `pacman -S rust`) or rustup
- flutter_rust_bridge_codegen in PATH
- For mobile: Android NDK + iOS toolchain

### 1. Install the Codegen Tool

```bash
cargo install flutter_rust_bridge_codegen
# Installs to ~/.cargo/bin/flutter_rust_bridge_codegen
```

### 2. Create the Rust Crate

```bash
mkdir -p rust/src/api
```

File: `rust/Cargo.toml`
```toml
[package]
name = "my_app_bridge"
version = "0.1.0"
edition = "2021"

[lib]
crate-type = ["cdylib", "staticlib"]

[dependencies]
flutter_rust_bridge = "=2.12.0"
serde = { version = "1", features = ["derive"] }
serde_json = "1"
rusqlite = { version = "0.32", features = ["bundled"] }
uuid = { version = "1", features = ["v4"] }
chrono = "0.4"
log = "0.4"
```

File: `rust/src/lib.rs`
```rust
mod api;
// Codegen will inject: mod frb_generated;
pub use api::database::Database;
pub use api::model::MyModel;
```

### 3. Write Bridge API Functions

File: `rust/src/api/mod.rs`
```rust
pub mod database;
pub mod model;
```

**Models** (`rust/src/api/model.rs`):
```rust
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MyModel {
    pub id: String,
    pub name: String,
    // ... fields exposed to Dart
}
```

**Database** (`rust/src/api/database.rs`):
```rust
use rusqlite::{Connection, params};
use std::sync::Mutex;
use crate::api::model::MyModel;

pub struct Database {
    conn: Mutex<Connection>,
}

impl Database {
    pub fn open(path: &str) -> Result<Self, String> {
        let conn = Connection::open(path).map_err(|e| format!("DB error: {e}"))?;
        let db = Self { conn: Mutex::new(conn) };
        db.migrate()?;
        Ok(db)
    }

    fn migrate(&self) -> Result<(), String> {
        let conn = self.conn.lock().map_err(|e| format!("Lock: {e}"))?;
        conn.execute_batch(
            "CREATE TABLE IF NOT EXISTS my_table (...) ;"
        ).map_err(|e| format!("Migration: {e}"))?;
        Ok(())
    }
}
```

### 4. Configure + Generate

File: `flutter_rust_bridge.yaml` (at Flutter project root)
```yaml
rust_input: crate::api
dart_output: lib/src/rust/
```

Run codegen:
```bash
cd app/
~/.cargo/bin/flutter_rust_bridge_codegen generate
```

This creates:
- `lib/src/rust/frb_generated.dart` — bridge runtime
- `lib/src/rust/api/database.dart` — generated Dart Database class
- `lib/src/rust/api/model.dart` — generated Dart model classes
- Modifies `rust/src/lib.rs` to add `mod frb_generated;`
- Adds `flutter_rust_bridge` and `rust_lib_sc_synthesis` deps to pubspec.yaml

### 5. Integrate the Build System

Run `flutter_rust_bridge_codegen integrate` to set up `rust_builder/` (cargokit build system).

**CRITICAL — Carogkit needs `rustup`:** If using system Rust (Arch package) instead of rustup, the cargokit builder fails with "rustup not found in PATH." Create a rustup wrapper (see reference: `rustup-wrapper.sh`).

**Alternative — Pre-built .so (simpler):** Replace the cargokit CMakeLists.txt with one that points directly at the pre-compiled Rust library:

File: `linux/flutter/ephemeral/.plugin_symlinks/rust_lib_sc_synthesis/linux/CMakeLists.txt`
```cmake
cmake_minimum_required(VERSION 3.10)
set(PROJECT_NAME "rust_lib_sc_synthesis")
project(${PROJECT_NAME} LANGUAGES CXX)

# Point to pre-built Rust library
set(RUST_LIB_PATH "${CMAKE_SOURCE_DIR}/../rust/target/debug/libmy_app_bridge.so")
if(NOT EXISTS "${RUST_LIB_PATH}")
    message(FATAL_ERROR "Rust library not found. Run: cd rust && cargo build")
endif()

add_library(${PROJECT_NAME} SHARED IMPORTED)
set_target_properties(${PROJECT_NAME} PROPERTIES
    IMPORTED_LOCATION "${RUST_LIB_PATH}"
)

set(rust_lib_sc_synthesis_bundled_libraries
    "${RUST_LIB_PATH}" PARENT_SCOPE)
```

Build the Rust library before Flutter:
```bash
cd rust && cargo build      # debug (22MB .so, fast iteration)
cd rust && cargo build --release  # release (3.3MB .so, stripped)
```

### 6. Initialize in Dart

File: `lib/core/data/rust_service.dart`
```dart
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:my_app/src/rust/frb_generated.dart';
import 'package:my_app/src/rust/api/database.dart';

class RustService {
  static final RustService _instance = RustService._();
  factory RustService() => _instance;
  RustService._();

  Database? _db;
  bool _ready = false;

  Future<void> init() async {
    if (_ready) return;
    await RustLib.init();  // loads native .so
    final dir = await getApplicationDocumentsDirectory();
    _db = await Database.open(path: '${dir.path}/app.db');
    // Seed from bundled JSON if empty
    if (!(await _db!.hasShips())) {
      final json = await rootBundle.loadString('assets/data/seed.json');
      await _db!.importData(json: json);
    }
    _ready = true;
  }

  Database get db {
    if (!_ready) throw StateError('Not initialized. Call init() first.');
    return _db!;
  }
}
```

Call in app startup:
```dart
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  RustService().init();  // fire-and-forget, completes before first tab load
  runApp(const MyApp());
}
```

### 7. Use in Screens

```dart
final service = RustService();
await service.init();
final items = await service.db.getAllItems();
```

## Build Integration Options

### Option A: Cargokit (default, complex)
- Run `flutter_rust_bridge_codegen integrate`
- Creates `rust_builder/` with cargokit build system
- Requires `rustup` for toolchain management
- Cross-compiles for all target platforms (Linux, Android, iOS, macOS, Windows)
- Works with `flutter build linux`, `flutter build apk`, etc.

**Symlink required:** Cargokit expects the Rust crate at `rust_builder/rust/`. Create a symlink:
```bash
cd rust_builder && ln -sf ../rust rust
```
Without this, the Rust crate won't be found during any cargokit build.

### Option B: Pre-built .so (simpler, Linux desktop only)
- Replace CMakeLists.txt to skip cargokit entirely
- Manually run `cargo build` before `flutter build linux`
- Only works for Linux desktop — see reference: `custom-cmakelists.md`
- Faster iteration (no cargokit overhead)
- **Does NOT work for Android/iOS** — mobile builds need cargokit's NDK/toolchain management

## Android Cross-Compilation

Building for Android requires the full cargokit pipeline (Option A). See the dedicated reference: `references/android-cross-compile.md`.

Quick start:
```bash
# 1. Install real rustup (wrapper can't handle target add)
rustup target add aarch64-linux-android armv7-linux-androideabi x86_64-linux-android

# 2. Ensure NDK is installed in Android SDK
ls ~/.android/sdk/ndk/     # Should show NDK versions

# 3. Build debug APK
cd app && flutter build apk --debug
```

Cargokit handles NDK detection, linker configuration (CC/AR env vars), and ABI-specific builds automatically once the Rust targets are installed.

### Rustup Wrapper (for system Rust without rustup)

If Rust was installed via package manager (Arch: `pacman -S rust`), there's no `rustup` binary. Carogkit requires it for basic Linux desktop builds. Create a wrapper script:

```bash
# ~/.local/bin/rustup
#!/bin/bash
# Delegates to real rustup if installed, otherwise fakes responses
REAL_RUSTUP="$HOME/.cargo/bin/rustup"
if [ -x "$REAL_RUSTUP" ]; then
    exec "$REAL_RUSTUP" "$@"
fi

# Fallback: fake responses for cargokit basic queries
case "$1" in
    toolchain) echo "stable-x86_64-unknown-linux-gnu (system)"; exit 0 ;;
    target) echo "x86_64-unknown-linux-gnu (installed)"; exit 0 ;;
    which) echo "/usr/bin/$2"; exit 0 ;;
    show) /usr/bin/rustc --version; exit 0 ;;
    version|--version) echo "rustup wrapper v1 (system Rust)"; exit 0 ;;
    *) exit 0 ;;
esac
```

Ensure `~/.local/bin` is in PATH.

**IMPORTANT:** The wrapper is sufficient for Linux desktop builds. For **Android cross-compilation**, the real rustup is required (the wrapper can't handle `rustup target add`). Install it alongside:
```bash
curl -sSf https://sh.rustup.rs | sh -s -- -y
source ~/.cargo/env
```
The real rustup coexists fine with system Rust — it uses its own toolchain directory and doesn't conflict with the system `rustc`/`cargo`.

## Data Seeding Pattern

Bundle a static dataset as a JSON asset and seed it into SQLite on first launch. This gives you offline-first operation with efficient SQL queries.

### Workflow

1. **Fetch** the data once from an API (or manually curate)
2. **Bundle** it as `assets/data/seed.json` (register in pubspec.yaml under `flutter:` → `assets:`)
3. **Seed** on first app launch via the Rust bridge:
   ```rust
   if !db.has_ships()? {
       let json = std::fs::read_to_string(path)?;  // passed from Dart
       db.import_ships(&json)?;
   }
   ```
4. **Query** from SQLite thereafter (no network needed)

### Rust Import Function Pattern

```rust
pub fn import_ships(&self, json: &str) -> Result<i64, String> {
    let items: Vec<ImportItem> = serde_json::from_str(json)
        .map_err(|e| format!("JSON parse: {e}"))?;
    let conn = self.conn.lock().map_err(|e| format!("Lock: {e}"))?;
    conn.execute_batch("BEGIN TRANSACTION")
        .map_err(|e| format!("TX: {e}"))?;
    let mut imported = 0i64;
    for item in &items {
        conn.execute("INSERT OR REPLACE INTO ships (...) VALUES (?1, ...)",
            params![...])
            .map_err(|e| format!("Insert: {e}"))?;
        imported += 1;
    }
    conn.execute_batch("COMMIT").map_err(|e| format!("TX: {e}"))?;
    Ok(imported)
}
```

### Dart Side

```dart
// In RustService.init():
final json = await rootBundle.loadString('assets/data/seed.json');
final count = await _db!.importShips(json: json);
```

### SC:Synthesis Example

238 ships fetched from `api.fleetyards.net/v1/models?perPage=240`, compacted to 152KB `assets/data/ships.json`. Imported into SQLite in a single transaction on first launch. Subsequent launches skip the seed check.

```
my-flutter-app/
├── rust/                          # Rust crate (cdylib)
│   ├── Cargo.toml
│   └── src/
│       ├── lib.rs
│       ├── frb_generated.rs       # Generated by codegen
│       └── api/
│           ├── mod.rs
│           ├── model.rs           # Data structs (exposed to Dart)
│           └── database.rs        # SQLite operations (Mutex<Connection>)
├── lib/
│   ├── main.dart
│   ├── app.dart
│   ├── src/rust/                  # Generated Dart bindings (DO NOT EDIT)
│   │   ├── frb_generated.dart
│   │   ├── frb_generated.io.dart
│   │   └── api/
│   │       ├── database.dart
│   │       └── model.dart
│   └── core/data/
│       └── rust_service.dart      # Singleton wrapper
├── assets/data/
│   └── seed.json                  # Data seeded into SQLite on first launch
├── rust_builder/                  # Carogkit build system (generated)
│   ├── cargokit/
│   └── linux/CMakeLists.txt
├── flutter_rust_bridge.yaml
├── pubspec.yaml                   # Deps: flutter_rust_bridge, rust_lib_sc_synthesis, path_provider
└── linux/                         # Flutter Linux platform directory
```

## Pitfalls

### 1. Rustup Required by Cargokit
Cargokit's builder finds `rustup` via PATH searching and uses it for toolchain/target management. Without rustup, the build fails with "rustup not found in PATH." Fix: rustup wrapper for basic builds (see above) or install real rustup for cross-compilation.

### 2. rust_builder/rust Symlink
After `flutter_rust_bridge_codegen integrate`, cargokit expects the Rust crate at `rust_builder/rust/`. If the crate is at `rust/` (project root), create a symlink:
```bash
cd rust_builder && ln -sf ../rust rust
```
Without this, cargokit silently skips the Rust build, and the .so is missing at install time.

### 3. CMakeLists Generator Expressions
The default cargokit CMakeLists uses `$<CONFIG>` generator expressions for output paths. When running cargokit standalone via env vars (not through CMake), these aren't resolved, and the build tool may write output to an unexpected location. Use Option B (pre-built .so) for simpler Linux desktop debugging.

### 4. flutter_rust_bridge_codegen Overwrites main.dart + Creates Test Fixtures
The `integrate` step may overwrite `lib/main.dart` with a demo template that imports `simple.dart` (a template file). It also creates `test_driver/integration_test.dart` and `integration_test/simple_test.dart` that reference the demo `MyApp` class. After codegen:
- Restore `lib/main.dart` if it was clobbered
- Remove `lib/src/rust/api/simple.dart` (generated template)
- Remove `test_driver/integration_test.dart` and `integration_test/simple_test.dart` (reference MyApp)
- Run `flutter analyze` to verify nothing else references the demo code

### 5. `.so` Path Expectations
The default `ExternalLibraryLoaderConfig` in `frb_generated.dart` looks for the library at `rust/target/release/` relative to the Flutter project root. This works for development but may not in production. For production builds, the CMakeLists install step copies the .so to the bundle.

### 6. Mutable Cross-Sibling Data (Mutex)
Database methods must use `Mutex<Connection>` (not `RefCell`) since flutter_rust_bridge may call methods from different isolates. Use `self.conn.lock().map_err(|e| format!("Lock: {e}"))?` pattern.

### 7. String Error Type
Bridge API functions should return `Result<T, String>` (not `anyhow::Result`) because flutter_rust_bridge v2 generates Dart `Future<T>` for `Result<T, String>`. `anyhow::Error` doesn't auto-convert.

### 8. Seed-once Logic
Importing data on every `init()` would be slow. Check `has_ships()` before seeding:
```rust
if !db.has_ships()? {
    db.import_ships(json_str)?;
}
```

### 9. Custom CMakeLists Kills Mobile Builds
The "pre-built .so" approach (Option B) works for Linux desktop but **breaks Android/iOS builds**. Mobile platforms need cargokit's Gradle/Xcode integration for NDK detection, linker setup, and ABI-specific builds. Keep the cargokit CMakeLists for cross-platform projects.

### 10. Android NDK Required
If `flutter build apk` fails with "clang not found" or "linker error", the NDK is missing or not detected. Ensure:
- `android/local.properties` has `ndk.dir=...` or
- `ANDROID_NDK_HOME` environment variable is set

### 11. Rustup Alongside System Rust
If Rust was installed via package manager (Arch: `pacman -S rust`) and you need Android cross-compilation, the rustup wrapper can't handle `rustup target add`. Install real rustup alongside:

```bash
curl -sSf https://sh.rustup.rs | sh -s -- -y
source ~/.cargo/env
```

This coexists with system Rust — uses its own toolchain directory under `~/.rustup/` and doesn't conflict with `/usr/bin/rustc` or `/usr/bin/cargo`. The wrapper script at `~/.local/bin/rustup` should delegate to the real binary when present.

### 12. flutter_rust_bridge_codegen `integrate` Creates Test Files
The `flutter_rust_bridge_codegen integrate` command creates `test_driver/` and `integration_test/` directories with demo test files that reference a `MyApp` class from the template. These will cause `flutter analyze` failures. Always remove after integration:
```bash
rm -f test_driver/integration_test.dart
rm -f integration_test/simple_test.dart
```

### 13. Rebuild Rust .so After Codegen Changes
After running codegen (which modifies `rust/src/lib.rs`), the Rust crate must be recompiled before the next Flutter build:
```bash
cd rust && cargo build
```

### 14. `url_launcher` `canLaunchUrl()` Returns False on Android 11+
On Android 11+ (API 30+), `canLaunchUrl()` returns `false` for HTTPS URLs unless the manifest includes a `<queries>` element for browser intent handling. If your app has external links (FleetYards, GitHub, Buy Me a Coffee), the default `canLaunchUrl()` → `launchUrl()` pattern silently fails — the button appears to do nothing.

**Fix:** Remove the `canLaunchUrl` guard. Just wrap `launchUrl` in a try/catch:

```dart
// ❌ Broken on Android 11+
Future<void> openLink() async {
  if (await canLaunchUrl(uri)) {      // ← returns false silently
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

// ✅ Works everywhere
Future<void> openLink() async {
  try {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    // Browser not available — fail silently
  }
}
```

Alternative: add a `<queries>` element to `android/app/src/main/AndroidManifest.xml`:
```xml
<queries>
    <intent>
        <action android:name="android.intent.action.VIEW" />
        <data android:scheme="https" />
    </intent>
</queries>
```
But try/catch is simpler and doesn't need manifest changes.

**Apply this pattern to ALL url_launcher calls** — openFleetYards, openBuyMeACoffee, GitHub links, and any other external URL in the app. Test on a physical Android device (emulators sometimes behave differently).
## Absorbed Skills (Consolidated References)

The following sibling skills were consolidated into this umbrella on 2026-05-27:

- **flutter-rust-bridge** — Core patterns for existing Rust codebases + FRB v2. Key refs: `references/v2-gotchas.md`, `references/doc-comment-ordering.md`
- **flutter-rust-bridge-integration** — Wayland/egui workarounds, module doc pitfalls. Key ref: `references/frb-v2-migration.md`
- **flutter-rust-embedded** — Cargokit integration, cross-compilation, system-Rust workarounds. Content fully covered by sections above.
- **rust-flutter-bridge** — Bridge setup, codegen troubleshooting. Key ref: `references/frb-codegen-troubleshooting.md`, `references/bridge-setup.md`, `references/common-compilation-fixes.md`

All unique reference files from these siblings now live in this skill's `references/` directory.

## Related Skills

- `flutter-backend-integration` — REST API + Axum server pattern (separate process). Use when you need external site scraping, auth proxies, or multi-user sync alongside or instead of embedded Rust.
- `flutter-app-scaffolding` — Project setup, navigation, theming for Flutter apps.
- `game-data-population` — Harvesting and bundling external game data (FleetYards, etc.).

## Reference Files

- `references/custom-cmakelists.md`
- `references/rustup-wrapper.sh` — Complete rustup wrapper script for system Rust (Arch Linux).
- `references/bridge-api-pattern.md` — Pattern for designing bridge API functions (open → migrate → CRUD → search), including dynamic SQL query building.
- `references/seed-json-format.md` — Expected JSON structure for seed data import.
- `references/android-cross-compile.md` — Android cross-compilation setup: rustup targets, NDK detection, cargokit Gradle integration, ABIs, pitfalls.
- `references/android-build-config.md` — App icon, display name, version management, url_launcher Android 11+ fix.
- `references/cross-tab-singleton-pattern.md` — Singleton service pattern for cross-tab navigation (ThemeManager, RustDatabaseService, UserShipData).