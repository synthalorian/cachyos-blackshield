---
name: cpp-cross-platform-ci
description: Use for CMake C++ CI on Linux/Windows/macOS builds.
---

# C++ Cross-Platform CI (CMake / JUCE / desktop apps)

Battle-tested path for taking a locally-built CMake C++ project to green 3-OS GitHub Actions builds. Distilled from bootstrapping Open Synth (JUCE 8 audio plugin): it took FIVE iterations to green — every failure mode is documented below so you hit them zero times.

## The template

`templates/gha-cmake-3os.yml` — copy into `.github/workflows/build.yml` and adjust:
- Matrix: `ubuntu-latest`, `windows-latest`, `macos-latest`.
- Submodules OFF at checkout; init selectively (see pitfalls).
- Build: `cmake --build build --config Release` (the `--config` is required for MSVC multi-config, harmless elsewhere).
- Test/binary paths must handle multi-config generators (see pitfall 6).
- Tag builds attach artifacts to the GitHub release via `gh release upload "$GITHUB_REF_NAME" dist/* --clobber` with `GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}`.

## Pitfalls (in the order you'll hit them)

1. **Don't assume dependency locations.** Verify `.gitmodules` before writing `git submodule update --init <path>` — CI fails with `pathspec did not match`. JUCE projects often resolve JUCE via `-DJUCE_DIR` / env / `~/.juce` fallback instead of a submodule; in CI, `git clone --depth 1 --branch <pinned-tag> https://github.com/juce-framework/JUCE.git` and pass `-DJUCE_DIR`. Pin the exact version the dev machine uses (`git describe --tags` in the local JUCE dir).
2. **Nested submodules need `--recursive`.** E.g. `clap-juce-extensions` contains `clap-libs/clap` + `clap-helpers`; non-recursive init fails at CMake configure with "does not contain a CMakeLists.txt". `git submodule update --init --recursive <path>`.
3. **MSVC: `M_PI` and min/max.** MSVC hides `M_PI` unless `_USE_MATH_DEFINES` is defined before `<cmath>`, and `windows.h` `min`/`max` macros break `std::min/std::max`. Fix globally: `if(MSVC) add_compile_definitions(_USE_MATH_DEFINES NOMINMAX) endif()` in the root CMakeLists — do NOT sprinkle #defines through sources.
4. **`std::tanhf` is not standard C++.** Newer GCC rejects it ("not a member of std"); older GCC/glibc let it slide. Use `std::tanh` (has float overloads since C++11). Same class: prefer `std::sin/cos/exp` over `sinf/cosf/expf` in `std::`.
5. **Namespace-mismatched forward declarations link on GCC/Clang, fail on MSVC.** A forward declaration OUTSIDE a namespace (`struct Foo;` at global scope) while the real definition lives inside `namespace ns` creates two distinct types. GCC/Clang may tolerate the mismatch at link time; MSVC emits LNK2019 with a mangled name pointing at the real namespace (`PEAUDrumKitPreset@opensynth`). Rule: forward declarations go INSIDE the same namespace as the definition.
6. **Multi-config generators relocate binaries.** On Windows (Visual Studio generator) executables land in `build/Release/foo.exe`, not `build/foo`. Test steps: `if [ -x ./build/foo_tests ]; then ./build/foo_tests; else ./build/Release/foo_tests.exe; fi` with `shell: bash`.
7. **Linux JUCE deps** (minimal set for a headless CI runner): `libasound2-dev libx11-dev libxext-dev libxinerama-dev libxrandr-dev libxcursor-dev libgl1-mesa-dev libfreetype6-dev libfontconfig1-dev` — webkit only if the project uses WebBrowserComponent.

## Verification loop

Push → `gh run list --workflow=<file> --limit 1` → `gh run watch <id> --exit-status` (background) → on failure `gh run view <id> --log-failed | grep -iE "error|FAILED" | sort -u`. Fix ONE class of error per iteration; push; repeat. Typical bootstrap is 3-5 iterations — that's normal, not a smell.

## Large asset submodules

If the repo bundles big asset submodules (sample libraries, game assets), gate them: checkout with `submodules: false`, init code submodules always, init asset submodules only on tag builds (`if: startsWith(github.ref, 'refs/tags/')`). Keeps PR/branch builds fast; release artifacts still bundle everything.
