# README Polish Standard

## Scope
Safe doc-only cleanup across many repos at once. Intended for batch polish work where source code/configs should not change.

## Top-of-file badge minimum
For most repos, add these when missing:
- License badge derived from LICENSE file
- Engine/platform/status badge when the repo type is obvious from context
- Do NOT invent capabilities the repo does not have

## Build/Run section standard
- Unity project: keep existing Unity build instructions rather than inventing code commands
- Flutter project: `flutter pub get`, `flutter run -d linux`, `flutter build apk`
- Rust/Odin/C++ project: actual `make`/`cargo`/`odin` commands from the repo
- Website/static: `open index.html` or deploy instructions that actually exist

## Hard rules
- Touch `README.md`, `CONTRIBUTING.md`, docs only. Do NOT push `.gradle/`, build artifacts, generated shaders/binaries.
- If a repo has no README, create one before polishing.
- If a repo already has solid docs/README, leave it alone rather than fake-polishing.
- Workspace/meta repos with AGENTS.md/SOUL.md identity content: do not rewrite from scratch; make targeted additions only.
