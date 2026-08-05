# Flutter Android Build — v1 Embedding Fix & Dependency Debugging

Flutter 3.27+ (released late 2024) **deleted the Android v1 embedding API** (`flutter-embedding.jar`). Apps declaring `flutterEmbedding = 1` or using plugins that depend on v1 will fail with:

```
Build failed due to use of deleted Android v1 embedding.
```

## Root Cause: AndroidManifest.xml flutterEmbedding Value

The `<meta-data>` entry in `android/app/src/main/AndroidManifest.xml` controls embedding version:

```xml
<!-- WRONG — Flutter 3.27+ rejects v1 -->
<meta-data
    android:name="flutterEmbedding"
    android:value="1" />

<!-- RIGHT — v2 embedding (required since Flutter 3.27+) -->
<meta-data
    android:name="flutterEmbedding"
    android:value="2" />
```

**Fix:** Change `android:value="1"` to `android:value="2"` in `AndroidManifest.xml`. This is safe — all plugins that have been updated for v2 work with value `2`.

## Root Cause: Plugin Dependency Chain

Even with `flutterEmbedding = 2`, some plugins still pull in v1 embedding via transitive dependencies. Common culprits:

| Plugin | Transitive dependency | Issue |
|--------|---------------------|-------|
| `just_audio` (0.9.x) | `path_provider` → `path_provider_android` → `jni` 1.0.0 | v1 embedding |
| `audioplayers` (6.x) | `audioplayers_android` → `path_provider_android` → `jni` 1.0.0 | v1 embedding |
| `record` (5.x) | `record_android` → `jni_flutter` → `jni` 1.0.0 | v1 embedding |
| `home_widget` (0.9.x) | `glance-appwidget:1.3.0-alpha01` → SDK 37/AGP 9.1+ | Wrong SDK |

**Detection:** Run `flutter pub deps --json` and check for `jni` or `jni_flutter` in the dependency tree:

```bash
# Check for JNI deps (should be 0 for a clean build)
flutter pub deps --json | python3 -c "
import sys, json
tree = json.load(sys.stdin)
def has_jni(nodes):
    for n in nodes:
        if 'jni' in n.get('name', '').lower():
            print(f'JNI found: {n[\"name\"]} {n.get(\"version\", \"?\")}')
            return True
        if has_jni(n.get('dependencies', [])): return True
    return False
has_jni(tree.get('children', []))
"
```

**Fix:** Remove or replace the problematic plugin. For audio, use vibration-only as a fallback. For other plugins, find a v2-compatible alternative or remove the feature.

## flutter_local_notifications — Core Library Desugaring

`flutter_local_notifications` requires core library desugaring for Java 8+ features:

```kotlin
// android/app/build.gradle.kts
android {
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true  # REQUIRED
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
}
```

**Without this:** `flutter_local_notifications` fails with unimplemented method errors during Gradle build.

## Build Output Splitting Pitfall

When using `--split-per-abi`, do NOT also set NDK abiFilters in `defaultConfig`:

```kotlin
defaultConfig {
    # DON'T do this with --split-per-abi:
    ndk {
        abiFilters += listOf("armeabi-v7a", "arm64-v8a", "x86_64")  # CONFLICT
    }
}

# RIGHT — just use the CLI flag:
# flutter build apk --debug --split-per-abi
```

`--split-per-abi` sets ABI filters internally. Setting them in `defaultConfig` produces:

```
Conflicting configuration : 'armeabi-v7a,arm64-v8a,x86_64' in ndk abiFilters
cannot be present when splits abi filters are set : armeabi-v7a,x86_64,arm64-v8a
```

## Quick Checklist for Failing Android Builds

1. `flutter analyze` — zero errors? If not, fix code first.
2. `android/app/src/main/AndroidManifest.xml` — `flutterEmbedding = "2"`?
3. `flutter pub deps --json` — any `jni` or `jni_flutter` in the tree?
4. `android/app/build.gradle.kts` — `coreLibraryDesugaringEnabled = true` if using `flutter_local_notifications`?
5. `android/gradle.properties` — `org.gradle.java.home` points to JDK 21?
6. Build with `--split-per-abi` AND without `ndk.abiFilters` in defaultConfig?
7. Build output directory: `build/app/outputs/flutter-apk/*.apk` — if empty, check `~/.gradle/daemon/*/logs/` for the actual error.