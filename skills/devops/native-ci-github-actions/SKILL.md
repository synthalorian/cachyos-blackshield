---
name: native-ci-github-actions
description: Use when building CI for native C++/CMake/JUCE apps.
---

# Native App CI/CD with GitHub Actions

Battle-tested patterns from shipping a JUCE 8 synth (Standalone+VST3+CLAP) across Linux/Windows/macOS runners — 8 CI runs of real failures condensed.

## Core workflow shape

- Trigger on `push` (branches + `tags: ['v*']`), `pull_request`, `workflow_dispatch`. Add `concurrency` with `cancel-in-progress: true`.
- **Top-level `permissions: contents: write`** — without it, release steps die with `HTTP 403: Resource not accessible by integration`.
- Matrix over `ubuntu-latest` / `windows-latest` / `macos-latest`; `fail-fast: false`.
- Run the sample-free test suite on every platform as the gate.
- A full working example lives in `templates/juce-build.yml` — copy and adapt.

## Dependency fetching

- **JUCE is usually NOT a git submodule** (local dev leans on `~/.juce`). CI must `git clone --depth 1 --branch <pinned-tag> https://github.com/juce-framework/JUCE.git` and pass `-DJUCE_DIR=...`.
- Nested submodules (e.g. clap-juce-extensions → clap-libs/clap, clap-helpers) need `git submodule update --init --recursive <path>`.
- Big asset submodules (sample libraries, GBs): only fetch `if: startsWith(github.ref, 'refs/tags/')` so PR/branch builds stay fast.

## Portability traps MSVC/GCC catch (fix in CMakeLists/code, not CI)

- MSVC: `M_PI` undeclared → `add_compile_definitions(_USE_MATH_DEFINES NOMINMAX)` inside `if(MSVC)`. NOMINMAX also fixes windows.h min/max macro clashes with `std::min/max`.
- `std::tanhf` / `std::sinf` etc. are NOT standard C++ — newer GCC rejects; use `std::tanh` (float overloads exist).
- Forward declarations must be inside the correct namespace. GCC/Clang silently tolerate a global fwd-decl + namespaced definition mismatch; MSVC link fails with LNK2019. MSVC is the strictest link checker — let CI be the cop.
- Runner GCC is often NEWER/stricter than the dev machine's — green local ≠ green CI.

## Runner shell/packaging quirks

- **Windows default shell is pwsh**, which eats `${VAR}` (expands to empty). Any step using `${GITHUB_REF_NAME}` or bash syntax MUST set `shell: bash` (Git Bash exists on Windows runners).
- No `zip` in Git Bash → package Windows with PowerShell `Compress-Archive`; Linux `tar -czf`; macOS `zip` works in bash.
- Multi-config generators (Visual Studio, Xcode) put binaries under `build/Release/` — test steps should probe both `./build/fx_tests` and `./build/Release/fx_tests.exe`.

## Release automation on tags

- Pushing branch + tag together fires TWO runs (one per ref). Tag-only steps are skipped on the branch run — watch the TAG run for asset uploads.
- Pattern: `gh release create "$TAG" --title "$TAG" --generate-notes || true` then `gh release upload "$TAG" dist/* --clobber` (tolerates a pre-existing release).
- `GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}` env is required for gh CLI in steps.
- **Re-pointing a tag:** the user denies `git push -f` on tags. Use delete + recreate: `git push origin :refs/tags/vX`, `git tag -d vX`, re-tag, plain push. Never bundle force-push with other commands — a denial blocks the whole bundle.

## Repo surfaces with no API

- **Social preview (og-image) has NO REST endpoint** (404). Prepare a 1280x640 PNG in the repo and have the user upload via Settings → General → Social preview.

## Verification loop

`gh run list --workflow=<file>`, `gh run watch <id> --exit-status`, `gh run view <id> --log-failed | grep -iE "error|FAILED"` — then drill into a single job's log via `gh api repos/<o>/<r>/actions/jobs/<jobid>/logs`. Fix one class of error per push; expect ~5-8 iterations for first-time cross-platform CI.
