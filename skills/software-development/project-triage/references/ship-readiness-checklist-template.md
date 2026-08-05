# Ship-Readiness Checklist Template

Copy this per-project when a user asks "is X ready to ship?" or during triage.

## Project: [name]

### Rust Core
- [ ] `cargo check` passes (core crate)
- [ ] `cargo test` — all green
- [ ] No dead code warnings
- [ ] No unused import warnings

### Bridge (Rust → Flutter)
- [ ] `flutter_rust_bridge_codegen` is installed
- [ ] `flutter_rust_bridge_codegen generate` has been run (check for `lib/src/rust/`)
- [ ] Flutter app calls `RustLib.init()` in `main()` (not mocked strings)
- [ ] Bridge functions return real data, not dummy/hardcoded values

### Desktop
- [ ] `cargo build --release` succeeds
- [ ] All themes render correctly
- [ ] Core features work (synthesis, storage, etc.)

### Mobile
- [ ] `flutter pub get` resolves all dependencies
- [ ] `flutter analyze` passes
- [ ] `flutter build apk --debug` or `--release` succeeds
- [ ] App icon embedded in Android mipmap folders (not just assets/)

### CI & Infrastructure
- [ ] CI workflow runs from the correct directory (workspace Cargo.toml vs subdirectory)
- [ ] CI pins compatible SDK versions
- [ ] Build scripts exist in `scripts/` and are `chmod +x`
- [ ] `.gitignore` covers build artifacts and nested repos

### Documentation
- [ ] README describes actual features (not "A new Flutter project")
- [ ] Version bumped in Cargo.toml / pubspec.yaml
- [ ] Release notes or changelog exists

## Critical Gap

The single thing that blocks ship:

> [one sentence: e.g., "flutter_rust_bridge codegen has not been run — mobile app uses mocked data"]
