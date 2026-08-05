# Flutter Android Build on Linux

Setting up Flutter Android builds on a Linux host (Arch, Ubuntu, etc.) requires explicit configuration that `flutter create` doesn't handle automatically.

## JDK Version

Gradle 8.10+ requires JDK 17-21. JDK 25+ (bleeding edge on Arch) will fail with no stack trace:

```bash
# Check current JDK
java -version

# Install JDK 21 if needed (Arch)
sudo pacman -S jdk21-openjdk

# Set before every build
export JAVA_HOME=/usr/lib/jvm/java-21-openjdk
flutter build apk --release
```

**Failure signal:** Gradle fails instantly (< 1s) with the error message being just the JDK version number (`26.0.1`). No stack trace, no explanation. It's always a JDK version mismatch.

## gradle.properties — JDK Path

Android Gradle defaults to whatever `java` is on `$PATH`. On Linux with multiple JDKs, the wrong one may be selected. Set explicitly:

```properties
# android/gradle.properties
org.gradle.jvmargs=-Xmx4G -XX:+HeapDumpOnOutOfMemoryError -Dfile.encoding=UTF-8
android.useAndroidX=true
org.gradle.java.home=/usr/lib/jvm/java-21-openjdk
```

## Keystore Generation (Signing)

A release APK must be signed. Flutter's default template looks for `android/key.properties`:

```bash
# Generate a release keystore
keytool -genkey -v \
  -keystore android/app/release.keystore \
  -alias release \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000 \
  -storepass YOUR_PASSWORD \
  -keypass YOUR_PASSWORD \
  -dname "CN=Your Name, OU=Dev, O=Your Org, L=City, ST=State, C=US"
```

Create `android/key.properties`:

```properties
storeFile=../app/release.keystore
storePassword=YOUR_PASSWORD
keyAlias=release
keyPassword=YOUR_PASSWORD
```

**The build.gradle reads `rootProject.file('key.properties')`** (note: `key.properties`, NOT `keystore.properties` — that's a common typo that causes silent signing failures).

### Signing Config Error

```
SigningConfig "release" is missing required property "storeFile"
```

This means `keystore.properties` was loaded but the `storeFile` path is wrong or the file doesn't exist. Verify:

1. The properties file is at `android/key.properties` (not `android/keystore.properties`)
2. The `storeFile` path is relative to the `android/` directory: `../app/release.keystore`
3. The keystore actually exists at `android/app/release.keystore`

### .gitignore

Add to `.gitignore`:

```
*.keystore
key.properties
```

These are secrets — never commit them. Each developer generates their own.

## Common Build Failures on Linux

| Symptom | Cause | Fix |
|---------|-------|-----|
| Build fails <1s, shows JDK version | JDK too new (25/26) | Use JDK 21 |
| `SigningConfig "release" is missing required property "storeFile"` | Missing or misnamed key.properties | Create `android/key.properties` |
| `Java home supplied is invalid` | `gradle.properties` points to Windows path | Point to local JDK 21 |
| `Could not resolve all files for configuration` | Dependency download failure | `flutter pub cache repair` |
| `Deprecated Gradle features` | Outdated Gradle wrapper | `flutter upgrade` then build |
| `checkReleaseAarMetadata` fails — glance dependency requires SDK 37 / AGP 9.1+ | `home_widget 0.9.x` pulls `glance-appwidget:1.3.0-alpha01` which requires SDK 37 + AGP 9.1+ | Downgrade to `home_widget:0.7.0` (uses `glance-appwidget:1.0.0`), or migrate to AGP 9.1+ |

## APK Size: Debug vs Release, and GitHub's 100 MB Hard Limit

Debug APKs embed Flutter engine ABI variants for **every** target (arm64-v8a, armeabi-v7a, x86_64), plus full debug symbols. Typical sizes for a multi-screen app:

| Build | Size |
|-------|------|
| `flutter build apk --debug` | **130–170 MB** |
| `flutter build apk --release` | **10–50 MB** (tree-shaken) |
| `flutter build appbundle --release` | **5–25 MB** (Play Store optimized) |

**GitHub enforces a 100 MB hard per-object limit for git-tracked files.** A debug APK will be rejected. Even some release APKs for large apps can exceed it. The fix is two-part:

**Part 1 — Exclude from git before staging:**
Add `*.apk` to `.gitignore` before running `git add`. Never commit build artefacts:

```bash
echo '*.apk' >> .gitignore
git add .gitignore
git commit -m "chore: exclude APK build artefacts from tracking"
```

**Part 2 — Attach to a GitHub Release, not the repo:**
Build → create release → upload APK as a release asset. Release assets are exempt from the git object limit:

```bash
JAVA_HOME=/usr/lib/jvm/java-21-openjdk flutter build apk --debug
ls -lh build/app/outputs/flutter-apk/app-debug.apk   # confirm size < 100 MB before git add
gh release create v0.1.0 \
  --title "v0.1.0" --notes "Initial release" \
  build/app/outputs/flutter-apk/app-debug.apk#MyApp-v0.1.0-debug.apk
```

**Recovery — APK accidentally committed before .gitignore existed:**

```bash
# Remove from the index (file stays on disk)
git rm --cached build/app/outputs/flutter-apk/*.apk

# Update .gitignore
echo '*.apk' >> .gitignore
git add .gitignore

# Amend the last commit to remove the APK from history
git commit --amend --no-edit

# Push the amended history (replaces remote's branch head)
git push --force-with-lease
```

> **See also:** `github-repo-management` → `references/flutter-apk-release.md` for the full release workflow, including asset rename quirks and split-ABI release strategies.

## flutter analyze — Zero-Warnings Policy

```bash
flutter analyze --no-fatal-infos
```

`--no-fatal-infos` promotes info-level diagnostics to warnings (warnings are fatal by default in newer Flutter). For a clean ship:

- **Exit code must be 0**
- **Zero errors, zero warnings, zero infos**

| Signal | Fix |
|--------|-----|
| `Unused private field '_pxPerUnit'` | Delete the dead field from the State class |
| `The method '_update' isn't used` | Delete the dead method or add its missing call site |
| `LateInitializationError on _unitLabel` | Replace `late String _unitLabel = ...` with a `String get _unitLabel => ...` getter — eliminates the late-init risk entirely |
| `!` non-null assertion on nullable display | Keep `double?` arithmetic; drop the `!`; use `?? 0` or null-coalescing in the display string |
| `final prev = _display;` unused | Delete the dead variable assignment line |

**Rule:** When `flutter analyze` emits anything, look for a one-line fix (dead var, wrong type, missing null check) before considering a refactor. Most Flutter warnings are trivially removable. If a warning needs a structural change, it's a real issue — don't suppress it.
