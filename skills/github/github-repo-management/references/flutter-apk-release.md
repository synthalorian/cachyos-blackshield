# Flutter APK Release Pipeline

Full workflow for building and shipping a Flutter APK (with or without Rust FFI) to GitHub releases.

## Standard Release Cycle

```bash
# 1. Build the APK
cd app && flutter build apk --release

# 2. Verify it built
ls -lh build/app/outputs/flutter-apk/app-release.apk

# 3. Commit any code changes
git add -A && git commit -m "vX.Y.Z — Description"

# 4. Push code
git push

# 5. Create release + upload APK in one command
#    The # renames the asset file on GitHub
gh release create vX.Y.Z \
  --title "vX.Y.Z — Description" \
  --notes "## Notes\n\n- Change 1\n- Change 2" \
  app/build/app/outputs/flutter-apk/app-release.apk#App-Name-vX.Y.Z.apk
```

## Quick Iteration (no new tag)

```bash
flutter build apk --release
git add -A && git commit -m "Fix bug" && git push
gh release upload vX.Y.Z \
  app/build/app/outputs/flutter-apk/app-release.apk#App-Name-vX.Y.Z.apk \
  --clobber
```

**⚠️ Clobber pitfall:** `gh release upload --clobber` with `#NewName.apk` sometimes ignores the rename and stores the file as `app-release.apk` (the original name) instead. When that happens:

```bash
# 1. Find the asset IDs
gh release view vX.Y.Z --json assets

# 2. Delete both the old-named and new-named assets
gh api -X DELETE /repos/OWNER/REPO/releases/assets/ASSET_ID

# 3. Re-upload with curl to force the filename
GH_TOKEN=$(gh auth token)
curl -X POST \
  -H "Authorization: token $GH_TOKEN" \
  -H "Content-Type: application/vnd.android.package-archive" \
  "https://uploads.github.com/repos/OWNER/REPO/releases/RELEASE_ID/assets?name=App-Name-vX.Y.Z.apk" \
  --data-binary @build/app/outputs/flutter-apk/app-release.apk
```

The asset ID comes from `gh release view` under each `assets[].id`. The release ID is in the release URL path (e.g., `/releases/323785317`).

## Version Bump vs Same-Tag Rebuild

Two valid approaches for updating a release:

### Approach A: Bump patch version (recommended for code changes)

```bash
# Update pubspec.yaml version, build, commit, push with new tag
gh release create v1.0.1 --title "v1.0.1" --notes "## Notes" app.apk#App-v1.0.1.apk
```
Clean history, clear version lineage, fresh timestamp.

### Approach B: Delete + recreate same tag (suitable for icon-only / asset-only changes)

When only branding/assets changed (no code logic, same version):

```bash
# 1. Package the new builds
cp app-release.apk dist/App-v0.1.0.apk

# 2. Delete old release + remote tag
gh release delete v0.1.0 --repo owner/repo --yes
git push --delete origin v0.1.0

# 3. Re-tag and push
git tag -f v0.1.0
git push origin v0.1.0

# 4. Create fresh release with new assets
gh release create v0.1.0 \
  --repo owner/repo \
  --title "App v0.1.0" \
  --notes "## Notes\n\n- Icon update: new branding" \
  dist/App-v0.1.0.apk
```

Use this when you want to keep the same version number but replace the downloadable artifacts. The release gets a fresh timestamp.
```

## Version Numbering

Update these when bumping:
1. `pubspec.yaml`: `version: X.Y.Z+N`
2. Settings screen: `vX.Y.Z` text
3. GitHub release tag: `vX.Y.Z`

## Flutter + Rust (flutter_rust_bridge)

When the app has an embedded Rust library:

1. The Rust crate must be built with `cdylib` in Cargo.toml
2. `flutter_rust_bridge_codegen generate` generates Dart FFI bindings
3. `flutter_rust_bridge_codegen integrate` sets up cargokit cross-compilation
4. `flutter build apk --release` handles Rust cross-compilation automatically via cargokit
5. The .so files for all 4 Android ABIs are embedded in the APK

**Prerequisites for Rust cross-compilation:**
- Android Rust targets installed: `rustup target add aarch64-linux-android armv7-linux-androideabi x86_64-linux-android`
- Android NDK installed (detected automatically by cargokit)
- For Linux desktop: also need `x86_64-unknown-linux-gnu` target

## Verification

```bash
# Check APK size
ls -lh build/app/outputs/flutter-apk/app-release.apk

# Check release is live
gh release list --limit 5

# Browse
open https://github.com/OWNER/REPO/releases/tag/vX.Y.Z
```
