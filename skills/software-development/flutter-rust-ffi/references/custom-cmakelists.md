# Custom CMakeLists.txt for Pre-Built Rust .so

Use this when cargokit's CMake builder fails (rustup not found, toolchain issues)
and you only need Linux desktop builds. This replaces the generated CMakeLists
for the rust_lib_sc_synthesis plugin.

## File to Replace

`linux/flutter/ephemeral/.plugin_symlinks/rust_lib_sc_synthesis/linux/CMakeLists.txt`

## Replacement Content

```cmake
cmake_minimum_required(VERSION 3.10)
set(PROJECT_NAME "rust_lib_sc_synthesis")
project(${PROJECT_NAME} LANGUAGES CXX)

# Point directly to pre-built Rust library
set(RUST_LIB_PATH "${CMAKE_SOURCE_DIR}/../rust/target/debug/libsc_synthesis_bridge.so")
if(NOT EXISTS "${RUST_LIB_PATH}")
    message(FATAL_ERROR "Rust library not found at ${RUST_LIB_PATH}. Run: cd rust && cargo build")
endif()

add_library(${PROJECT_NAME} SHARED IMPORTED)
set_target_properties(${PROJECT_NAME} PROPERTIES
    IMPORTED_LOCATION "${RUST_LIB_PATH}"
)

set(rust_lib_sc_synthesis_bundled_libraries
    "${RUST_LIB_PATH}"
    PARENT_SCOPE
)
```

## Build Order

```bash
cd rust && cargo build           # 1. Build Rust first
cd app && flutter build linux    # 2. Build Flutter (CMake finds .so)
```

## Caveats

- **Linux desktop only.** Android/iOS builds need the cargokit Gradle/Xcode integration for NDK detection and ABI-specific builds.
- **Debug vs Release.** The example points at `target/debug/`. For release builds, change to `target/release/` or build both.
- **Path resolution.** `CMAKE_SOURCE_DIR` is the Flutter Linux runner directory (`app/linux/`). The `../rust/` path resolves to `app/rust/` relative to that.
- **Symlinks.** If the plugin symlink structure changes (e.g., after `flutter pub get` re-creates `.plugin_symlinks`), the path may need updating.
