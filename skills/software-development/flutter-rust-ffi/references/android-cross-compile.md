# Android Cross-Compilation for flutter_rust_bridge

Cross-compiling the Rust bridge for Android via cargokit. Covers the full pipeline from target installation to APK output.

## Prerequisites

- **Android SDK + NDK** — Installed via `flutter config --android-sdk` or Android Studio
  - NDK location: `$ANDROID_HOME/ndk/<version>/` or `~/.android/sdk/ndk/<version>/`
  - cargokit auto-detects the NDK from `local.properties` or ANDROID_NDK_HOME
- **Rust Android targets** — Install via rustup:
  ```bash
  rustup target add aarch64-linux-android      # arm64-v8a (most devices)
  rustup target add armv7-linux-androideabi    # armeabi-v7a (older devices)
  rustup target add x86_64-linux-android       # x86_64 (emulator)
  rustup target add i686-linux-android         # x86 (emulator, older)
  ```
- **`rustup` binary** — Required by cargokit. If system Rust (Arch: `pacman -S rust`), see the rustup-wrapper reference below.

## Build Pipeline

When `flutter build apk --debug` runs with cargokit:

1. **Gradle** invokes the cargokit Gradle plugin (from `android/` build files)
2. Cargokit calls `rustup target list` to verify targets are installed
3. Cargokit sets environment variables for the NDK linker:
   - `CC_aarch64-linux-android` → NDK clang
   - `AR_aarch64-linux-android` → NDK llvm-ar
   - Same for each target
4. `cargo build --target aarch64-linux-android --release` runs for each ABI
5. The `.so` files land in the APK at `lib/<abi>/lib<bname>.so`
6. All ABIs are bundled by default

## Carogkit Structure

```
app/
├── rust_builder/                    # Created by `flutter_rust_bridge_codegen integrate`
│   ├── cargokit/                    # Build tool + cmake module
│   ├── android/CMakeLists.txt       # Android CMake config (uses cargokit)
│   ├── ios/                         # iOS build config
│   ├── linux/CMakeLists.txt         # Linux CMake config
│   ├── macos/
│   ├── windows/
│   └── pubspec.yaml                 # Dart package (referenced by flutter)
├── android/
│   └── app/build.gradle             # Auto-includes cargokit plugin
```

**IMPORTANT — Symlink:** Carogkit expects the Rust crate at `rust_builder/rust/`. Create a symlink:
```bash
cd rust_builder && ln -sf ../rust rust
```
Without this, cargokit can't find `Cargo.toml` and the Android build silently skips the Rust lib.

## NDK Detection

Cargokit reads `android/local.properties` for the NDK path:
```
sdk.dir=/home/synth/.android/sdk
ndk.dir=/home/synth/.android/sdk/ndk/26.1.10909125
```

If missing, it falls back to `ANDROID_NDK_HOME` environment variable. The build fails with an obscure "clang not found" error if neither is set.

## Build Commands

```bash
# Debug APK (fast, unoptimized .so, larger)
cd app && flutter build apk --debug
# Output: ~155 MB (debug symbols in .so)
# 4 ABIs: arm64-v8a (3.6MB), armeabi-v7a (2.6MB), x86_64 (3.8MB), x86

# Release APK (optimized .so, stripped, smaller)
cd app && flutter build apk --release
# Output: ~59 MB (stripped .so, tree-shaken assets)
# 4 ABIs: arm64-v8a (~1.2MB per .so)

# Bundle (for Play Store)
cd app && flutter build appbundle --release
```

## Output

```
build/app/outputs/flutter-apk/app-debug.apk    # ~155 MB (debug symbols)
build/app/outputs/flutter-apk/app-release.apk   # ~59 MB (stripped + tree-shaken)
  └── lib/
      ├── arm64-v8a/libsc_synthesis_bridge.so    # ~3.6 MB debug, ~1.2 MB release
      ├── armeabi-v7a/libsc_synthesis_bridge.so   # ~2.6 MB debug, ~1 MB release
      ├── x86_64/libsc_synthesis_bridge.so        # ~3.8 MB debug
      └── x86/libsc_synthesis_bridge.so           # (if target installed)
```

## Pitfalls

### 1. Custom CMakeLists Breaks Mobile
The "pre-built .so" CMakeLists approach (see `references/custom-cmakelists.md`) **only works for Linux desktop**. For Android, cargokit's Gradle plugin is required — it handles NDK detection, linker setup, and ABI-specific builds. You cannot substitute the `rust_builder/` CMakeLists for mobile builds.

### 2. Missing Rust Targets
If `cargo build --target aarch64-linux-android` fails with "can't find crate for `core`", the Rust standard library for that target isn't installed. Install via `rustup target add <target>`.

### 3. rusqlite Bundled Feature
`rusqlite` with `bundled` feature compiles C code, which requires the NDK toolchain (clang, llvm-ar). Carogkit handles this if targets are installed. Without the NDK, the C compile step fails.

### 4. rustup Required
Cargokit hard-requires `rustup` in PATH — it cannot use system cargo directly. On Arch Linux (system Rust), install rustup alongside:
```bash
# Download installer script, inspect, then run
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs > /tmp/rustup-init.sh
chmod +x /tmp/rustup-init.sh
/tmp/rustup-init.sh -y  # Installs to ~/.cargo/bin/rustup
source ~/.cargo/env
```

The rustup wrapper script (see main SKILL.md) works for basic queries but **cannot handle `target add` or `component add` commands** needed for cross-compilation. Install the real rustup for Android builds.

### 5. ABI Proliferation
Building all 4 Android ABIs takes ~4× longer than Linux desktop (only 1 target). If iterating on Rust code, use `--target <single-arch>` for cargo directly and only build the full APK when ready. Or use an emulator (x86_64) for fast iteration.

## Reference: Session 2026-05-15

The SC:Synthesis app successfully built both debug (155 MB) and release (59 MB) Android APKs with all 4 ABIs. The Rust bridge crate (`sc_synthesis_bridge`) with `rusqlite` (bundled) cross-compiled without issues once the Android targets were installed via the real rustup. NDK 26.1.10909125 was auto-detected by cargokit.

The release build process:
1. `cd app && flutter build apk --release` — ~2-3 minutes total
2. Carogkit cross-compiles Rust for each ABI (arm64-v8a, armeabi-v7a, x86_64)
3. Flutter tree-shakes fonts (MaterialIcons 99.6% reduction: 1.6MB → 6KB)
4. Final APK: 59MB (includes all Rust .so + Flutter engine + asset data)
5. The APK was uploaded as a GitHub Release asset via `gh release create v0.1.0 ./apk#name.apk`
