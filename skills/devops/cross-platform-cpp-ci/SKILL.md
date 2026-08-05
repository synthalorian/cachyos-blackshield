---
name: cross-platform-cpp-ci
description: "Use for cross-platform C++/CMake CI and tag releases."
---

# Cross-Platform C++ CI (GitHub Actions)

Bringing a CMake/C++ project (especially JUCE audio apps) green on Linux + Windows + macOS, plus tag-triggered release automation.

## Trigger

Use when: adding CI to a CMake/C++ repo, fixing per-OS CI failures, wiring release-asset upload on tags, or debugging "works on my machine" portability errors that only CI caught.

## Core Workflow Pattern

Matrix over `ubuntu-latest` / `windows-latest` / `macos-latest`. Steps: checkout (submodules: false) → init submodules explicitly → install Linux deps (JUCE: libasound2-dev libx11-dev libxext-dev libxinerama-dev libxrandr-dev libxcursor-dev libgl1-mesa-dev libfreetype6-dev libfontconfig1-dev) → `cmake -S . -B build -DCMAKE_BUILD_TYPE=Release` → `cmake --build build --config Release` → run tests → package (tar on Linux, Compress-Archive via pwsh on Windows, zip on macOS) → upload-artifact → on tags: create-or-update GitHub release + upload assets.

Non-negotiables:
- `permissions: contents: write` at workflow level, or `gh release create/upload` 403s ("Resource not accessible by integration").
- Gate heavyweight submodule checkouts (sample/asset libs) behind `if: startsWith(github.ref, 'refs/tags/')`; keep push/PR runs lean.
- Release step must be self-sufficient: `gh release create "$TAG" --generate-notes || true; gh release upload "$TAG" dist/* --clobber` — works whether or not the release pre-exists.

## Gotcha Checklist (all earned in production)

1. **Submodule traps**: `git submodule update --init <path>` → "pathspec did not match" means the path isn't in `.gitmodules` — read it first. Nested submodules need `--recursive`. If a dep isn't a submodule at all (e.g. JUCE living in `~/.juce`), clone the pinned tag in CI and pass `-D<VAR>_DIR=`.
2. **MSVC `M_PI: undeclared`** → CMake-level fix: `if(MSVC) add_compile_definitions(_USE_MATH_DEFINES NOMINMAX) endif()`. NOMINMAX also fixes std::min/std::max macro collisions.
3. **`std::tanhf` / `std::sqrtf` etc. not standard** → use `std::tanh` / `std::sqrt` (float overloads). Older GCC accepts the `f` variants; newer toolchains don't.
4. **LNK2019 on MSVC but links on GCC/Clang** → suspect a forward declaration in the wrong namespace (global `struct Foo;` vs `ns::Foo`). MSVC mangles strictly; GCC may tolerate.
5. **Multi-config generators** (Visual Studio, Xcode): binaries in `build/Release/`, single-config (Ninja/Make) in `build/`. Gate test/exec steps: `if [ -x ./build/t ]; then ./build/t; else ./build/Release/t.exe; fi`.
6. **Windows Git Bash has no `zip`** → pwsh step + `Compress-Archive`.
7. **Pushing branch+tag together** (`git push origin master v2.0.2`) fires TWO runs; tag-only steps execute only on the tag-ref run. Verify which run you're watching via the REF column in `gh run list`.
8. **Tag re-runs use the ORIGINAL workflow snapshot** — fixing a workflow on master does NOT fix an existing tag's run. Cut a NEW tag (never force-push tags without explicit user consent — see below).

## Release Etiquette (user preference — synth)

Never force-push tags or rewrite pushed history without explicit consent. If a tag's CI run is broken, propose: (a) new tag/version bump, (b) manual asset upload from the CI artifacts, or (c) explicit delete+recreate — and let the user pick. (synth denied a tag force-push on 2026-07-25.)

## References

- `references/juce-ci-notes.md` — JUCE-specific CI + packaging detail: icon embedding, Linux desktop icon association (XWayland/WM_CLASS), social preview upload, sample bundling.
