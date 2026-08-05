# Open Synth — Android Port Architecture

## Audio Backend Swap: PortAudio → Oboe

The core architectural decision: **identical FFI symbol names across platforms**.

Dart FFI bindings call C functions like `audio_stream_create_for_synth()`.
On desktop, these resolve to PortAudio implementations. On Android, they resolve to Oboe implementations.
Dart code is identical on both platforms — the CMake build determines which backend gets compiled into the .so.

### File Mapping

| Desktop (PortAudio)      | Android (Oboe)             | Purpose                        |
|--------------------------|----------------------------|--------------------------------|
| audio_stream.h/.cpp      | oboe_audio_stream.h/.cpp   | Audio stream (callback-based)  |
| audio_system.h/.cpp      | (not needed)               | Audio system lifecycle         |
| audio_stream_ffi.h/.cpp  | oboe_audio_ffi.h/.cpp      | FFI glue (same C symbol names) |

### CMake Structure (Working — May 2026)

**CRITICAL**: Do NOT use FetchContent for Oboe — it fails in NDK CMake context (git clone silently fails).
Oboe v1.8.0 is vendored at `native/oboe/`.

```cmake
set(COMMON_SOURCES
    src/synth_engine.cpp src/synth_ffi.cpp src/arpeggiator.cpp
    src/voice.cpp src/voice_allocator.cpp src/oscillator.cpp
    src/envelope.cpp src/filter.cpp src/lfo.cpp
    src/legacy_fx.cpp src/fx_engine.cpp src/fx_eq.cpp
    src/fx_limiter.cpp src/fx_rotary.cpp src/fx_tremolo.cpp
    src/synth_mixer.cpp
)

if(ANDROID)
    set(OBOE_DIR ${CMAKE_CURRENT_LIST_DIR}/oboe)
    file(GLOB_RECURSE OBOE_SOURCES
        "${OBOE_DIR}/src/aaudio/*.cpp"
        "${OBOE_DIR}/src/common/*.cpp"
        "${OBOE_DIR}/src/fifo/*.cpp"
        "${OBOE_DIR}/src/flowgraph/*.cpp"
        "${OBOE_DIR}/src/opensles/*.cpp"
    )
    add_library(oboe STATIC ${OBOE_SOURCES})
    target_include_directories(oboe PUBLIC ${OBOE_DIR}/include PRIVATE ${OBOE_DIR}/src)

    add_library(openamp_dart_ffi SHARED
        ${COMMON_SOURCES}
        src/oboe_audio_stream.cpp
        src/oboe_audio_ffi.cpp
    )
    target_include_directories(openamp_dart_ffi PUBLIC include PRIVATE src)
    target_link_libraries(openamp_dart_ffi PRIVATE oboe log OpenSLES)
else()
    # Desktop: PortAudio
    # LIBRARY_OUTPUT_DIRECTORY set here only (NOT on Android)
    find_package(PkgConfig REQUIRED)
    pkg_check_modules(PORTAUDIO REQUIRED portaudio-2.0)
    add_library(openamp_dart_ffi SHARED ${COMMON_SOURCES} ...)
    target_link_libraries(openamp_dart_ffi PRIVATE ${PORTAUDIO_LIBRARIES})
endif()

# LIBRARY_OUTPUT_DIRECTORY must NOT be set for ANDROID — Gradle controls placement
if(NOT ANDROID)
    set_target_properties(openamp_dart_ffi PROPERTIES
        LIBRARY_OUTPUT_DIRECTORY "${CMAKE_CURRENT_LIST_DIR}"
        OUTPUT_NAME "openamp_dart_ffi"
    )
endif()
```

### Gradle Integration

`android/app/build.gradle.kts` must have `externalNativeBuild` blocks:

```kotlin
android {
    defaultConfig {
        externalNativeBuild {
            cmake {
                cppFlags += "-std=c++17"
                arguments += listOf("-DANDROID_STL=c++_shared")
            }
        }
    }
    externalNativeBuild {
        cmake {
            path = file("../../native/CMakeLists.txt")
            version = "3.22.1"
        }
    }
}
```

Without this, Gradle won't compile the C++ code and the APK will have no native library for ARM64.

### Oboe Builder API (v1.8.0)

The first setter uses `.` (object access), subsequent use `->` (pointer access):

```cpp
oboe::AudioStreamBuilder builder;
oboe::Result result = builder
    .setDirection(oboe::Direction::Output)
    ->setPerformanceMode(oboe::PerformanceMode::LowLatency)
    ->setSharingMode(oboe::SharingMode::Exclusive)
    ->setFormat(oboe::AudioFormat::Float)
    ->setChannelCount(2)
    ->setSampleRate(static_cast<int32_t>(sampleRate_))
    ->setBufferCapacityInFrames(static_cast<int32_t>(blockSize_ * 2))
    ->setFramesPerDataCallback(static_cast<int32_t>(blockSize_))
    ->setDataCallback(this)
    ->openStream(stream_);
```

### Oboe Stream Configuration

- **PerformanceMode**: LowLatency
- **SharingMode**: Exclusive (falls back to Shared automatically)
- **Format**: Float (32-bit)
- **ChannelCount**: 2 (stereo)
- **DataCallback**: Fills float buffer via SynthEngine::process()

### Android FFI Stubs

| Function | Desktop (PortAudio) | Android (Oboe) |
|----------|--------------------|--------------------|
| `audio_system_init()` | Pa_Initialize(), cache devices | Return 1 (no-op) |
| `audio_system_shutdown()` | Pa_Terminate() | No-op |
| `audio_get_device_count()` | Returns real count | Returns 1 |
| `audio_get_device_name(0)` | Real device name | "Default" |
| `audio_stream_create_for_synth()` | Pa_OpenStream() | Oboe builder + open() |

### Dart Platform Abstraction

`lib/ffi/audio_platform.dart`:
- `isAndroid` — Platform.isAndroid
- `isMobile` — Platform.isAndroid || Platform.isIOS
- `hasAudioDeviceEnumeration` — !isMobile
- `audioBackendName` — "Oboe" on Android, "PortAudio" on Linux, etc.

Settings screen uses `hasAudioDeviceEnumeration` to hide device picker on mobile.

## Mobile UX (Built — May 2026)

Hamburger drawer navigation (not bottom nav). **Full-width keyboard at bottom, controls above.**

- **MobileShell** — drawer with 5 nav items, Orbitron header, gradient bar
- **MobileSynthScreen** — Column layout (both orientations):
  1. Compact top bar (~48dp): preset name tap-to-cycle, octave up/down, master volume slider, panic button
  2. Oscilloscope + spectrum analyzer row (~40dp)
  3. Expanded scrollable collapsible panels
  4. Full-width KeyboardWidget at bottom (160dp landscape / 180dp portrait)
- **CollapsibleSection** — ExpansionTile wrapper, all panels collapsed by default
- Platform routing via `isMobile` early return in `MainShell` and `SynthScreen`

See `references/mobile-ux-shell.md` for full layout details.

Remaining: multitouch glide, velocity via pressure API, pinch-to-zoom octave, Android latency tuning.

## Build Verification Checklist

After any Android build change, verify:
1. `flutter analyze` — 0 errors
2. `flutter build apk --debug` — succeeds
3. `unzip -l build/app/outputs/flutter-apk/app-debug.apk | grep libopenamp` — shows `lib/arm64-v8a/`
4. `adb install -r` — succeeds on target device
5. Launch on device — audio produces sound

## iOS Future (Not Started)

Same pattern: Audio Toolbox / AUAudioUnit. Same FFI symbol names.
Estimated 3-4 additional days after Android is stable.
