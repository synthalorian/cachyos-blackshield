---
name: open-fit-build-setup
description: Android build configuration fixes for Open Fit / Isar 3.x Flutter projects
---

# Open Fit Android Build Fixes

**Project:** Open Fit — Flutter fitness app with Isar 3.1.0, flutter_local_notifications, mobile_scanner

## Gradle & AGP Fixes (Flutter 3.41.9, Gradle 8.10.2)

The project was originally generated with AGP 7.3.0 and Kotlin 1.7.10, which are incompatible with modern Gradle 8.x and JDK 21. Required changes:

### 1. `android/settings.gradle` — Upgrade AGP & Kotlin
```groovy
plugins {
    id "dev.flutter.flutter-plugin-loader" version "1.0.0"
    id "com.android.application" version "8.3.0" apply false
    id "org.jetbrains.kotlin.android" version "1.9.22" apply false
}
```

### 2. `android/app/build.gradle` — Java 17 + desugaring
```groovy
compileOptions {
    sourceCompatibility = JavaVersion.VERSION_17
    targetCompatibility = JavaVersion.VERSION_17
    coreLibraryDesugaringEnabled true
}

kotlinOptions {
    jvmTarget = "17"
}

defaultConfig {
    minSdk = 21  // Explicit, not flutter.minSdkVersion
}

dependencies {
    coreLibraryDesugaring "com.android.tools:desugar_jdk_libs:2.1.5"
}
```

### 3. `android/gradle.properties` — Fix JAVA_HOME
```properties
org.gradle.java.home=/home/synth/.sdkman/candidates/java/current
```

### 4. `~/.pub-cache/hosted/pub.dev/isar_flutter_libs-3.1.0+1/android/build.gradle` — Add namespace
```groovy
android {
    namespace 'dev.isar.isar_flutter_libs'
    compileSdkVersion 30
    ...
}
```

**Build command:** `flutter build apk --debug --android-skip-build-dependency-validation`

## Flutter Analysis & Code Fixes
- Replace `withOpacity(x)` → `withValues(alpha: x)` across all files
- Replace `CardTheme` → `CardThemeData` in `ThemeData.cardTheme`
- Replace `DropdownButtonFormField(value:)` → `DropdownButtonFormField(initialValue:)`

## Verification
- `dart analyze` — 0 errors, 0 warnings
- `flutter test` — all 13 model tests pass
- `flutter build apk --debug` — builds to `build/app/outputs/flutter-apk/app-debug.apk`
