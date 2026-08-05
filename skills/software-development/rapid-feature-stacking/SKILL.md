---
name: rapid-feature-stacking
description: Workflow for rapidly iterating and stacking new features on GUI/desktop applications (especially egui/Rust) even when the codebase has pre-existing structural or syntax issues. Prioritizes momentum and visible progress over immediate cleanup.
---

# Rapid Feature Stacking

Use this skill when the user signals a desire to keep adding features quickly without stopping for refactors or fixes.

## Triggers
- User replies with short affirmatives: "ok", "yes", "go for it", "continue", "c", "stack more"
- User explicitly says "keep stacking" or similar
- Session context shows repeated feature addition requests despite known code issues

## Core Behavior
- **Prioritize momentum**: Add new UI sections, controls, panels, and functionality via targeted patches even if `cargo check` would currently fail due to pre-existing problems.
- **Accept messy state**: Do not volunteer to clean up syntax, indentation, or structural issues unless the user explicitly asks for it.
- **Stack in batches**: When given a list of features, implement multiple in sequence without pausing for verification between each one.
- **Document what was added**: After a stacking burst, give a clear bullet-point summary of new capabilities.

## Anti-Patterns to Avoid
- Suggesting "let's fix the file first so it compiles" when user is in stacking mode
- Asking for permission to clean up after every few features
- Treating pre-existing lint errors as blockers during active stacking
- Excessive narration or "I'm now going to..." preambles during active stacking (user will ask "are you actually doing anything?")
- Running commands that could kill the Hermes process (hermes update, pip install --upgrade) without warning the user first
- **The `read_file` loop trap** — When `read_file` returns "BLOCKED: You have called read_file on this exact region N times and the file has NOT changed", STOP. Do not retry with identical arguments. The tool has a hard limit (typically 10-15 retries) after which it permanently blocks the path for the session. Pivot immediately: use `browser_vision`, `terminal` with `cat/head`, or proceed with the information you already have. This trap is especially common when reading large files in chunks and losing track of which offsets were already read.
- **Oboe API deprecation pitfall** — Oboe 1.9+ split `AudioStreamCallback` into `AudioStreamDataCallback` + `AudioStreamErrorCallback`, and deprecated `setDataCallback()`/`setErrorCallback()` in favor of `setCallback()` which accepts the unified `AudioStreamCallback*`. If you get "no matching member function for call to 'setDataCallback'" errors, switch to `setCallback(this)` on the builder. The unified callback still works for both data and error callbacks.

## Verbosity Rule
When the user is in rapid stacking mode, **do the edit first**, then give a short confirmation. Long explanations of intent should be avoided unless the user explicitly asks for status or the stacking phase has naturally paused.

## When to Exit Stacking Mode
- User says "clean up", "make it compile", "fix the errors", or asks for a review/build check
- Natural pause after a large batch of features has been added
- Compilation completely breaks and small patches become ineffective

## Advanced Pattern: Full Rewrite After Heavy Stacking
When repeated patching has created overlapping remnants, duplicate code blocks, and mismatched delimiters (common after 10+ feature additions), do **not** attempt incremental fixes. Instead:
1. Offer a clean rewrite of the main UI file (`main.rs`).
2. Preserve every stacked feature in the rewrite.
3. Use the rewrite opportunity to also improve structure and readability.

This pattern was highly effective in GridOS egui sessions. Users in stacking mode prefer this over prolonged debugging of patch damage.

## Stacking Pattern: Backend-Infrastructure-First

When a codebase has solid bones (combat, pathfinding, encounters, AI, progression) but the demo is just a screensaver, the fastest path to playable is **wiring existing systems together** rather than writing new ones.

**Diagnose what's missing:**
1. Systems exist in library code but aren't called from the binary
2. Components have data but no system moves them (NavigationAgent has path/speed but no movement system)
3. Encounters spawn on map but never create actual enemy entities
4. Combat system resolves attacks but player units never acquire targets
5. Camera is static even though squad moves

**Wiring checklist (in order):**
1. **Render what's missing** — Add enemy rendering loop to `gather_sprites()`
2. **Connect input to action** — Right-click on encounter → move squad + auto-target
3. **Add auto-behaviors** — Camera follows squad center, units auto-acquire nearby enemies
4. **Verify simulation runs** — Ensure `GameSimulation::tick()` is called from main loop
5. **Test end-to-end** — Build both binaries, verify launch path, test from launcher

**Key insight:** The simulation system (`GameSimulation`) already existed in `src/game/simulation.rs` with movement, encounter spawning, AI, and progression. It just needed to be called from `ChronosCompanyGame::tick()`. The demo binary (`chronos-game.rs`) had `game.tick(dt)` but the simulation wasn't wired into the runner's tick method.

**Anti-pattern to avoid:** Don't write new movement code when `NavigationAgent` + `Pathfinder` already exist. Don't spawn enemies manually when `EncounterManager` + `MercenaryFactory` already handle it. The skill is in **discovering and connecting** existing systems, not reinventing them.
When adding many features that span both backend and frontend (e.g., Rust backend + Flutter GUI):
1. **Build ALL backend endpoints first** — every new feature gets a backend endpoint before any frontend work
2. **Verify each endpoint with curl** — confirm each works before building the GUI for it
3. **Build frontend UIs in order of priority** — start with the one the user asked for first
4. **Defer shared infrastructure** — build the generic CLI proxy endpoint early so later features can use it without custom endpoints
5. **Batch rebuild** — compile backend once after all endpoints are added, compile Flutter once after all UI work is batched
This avoids the pattern of "compile → test → add one more → compile again" which wastes time on large projects.

## Stacking Pattern: CLI Audit First
When wrapping an existing CLI tool in a GUI:
1. Run `<tool> --help` and trace every subcommand tree
2. Classify each: interactive (needs custom endpoint) vs batch (use generic proxy)
3. Build the generic proxy (`POST /command {args: [...]}`) early — it covers the long tail
4. Build custom endpoints for the top 20% of commands the user interacts with most
5. The generic proxy + a single "CLI Tools" screen with action buttons + output viewer covers the remaining 80% of features with minimal UI work

## Stacking Pattern: Python Helper Bridge
When the backend (Rust) needs to manipulate file formats that are easier in Python (.env, config files):
- Write a compact Python helper script
- Create-if-not-exists pattern: check for script, write it if missing, then call it
- Call via `Command::new("python3")` from Rust
- This avoids complex text parsing in Rust for quick env/config manipulation tasks

## Stacking Pattern: Git Commit Hygiene for Native Projects

When working on C++ / NDK / CMake projects that generate massive build artifacts:

1. **Before committing**, run `git status` and review the output carefully
2. **Build artifacts to NEVER commit:** `.cxx/`, `.gradle/`, `build/`, `*.o`, `*.so` (except deliberate `jniLibs/`), `compile_commands.json`, CMake cache files
3. **Use `git add <specific-file>`** instead of `git add -A` when build artifacts are present in the working tree
4. **If `git add -A` was already used**, reset with `git reset` and stage only source files
5. **Verify with `git diff --cached --stat`** before committing — the stat should only show source files
6. **For repos with submodules** (like Oboe), check `git diff third_party/` — submodule pointer changes show as `+Subproject commit ...` and should be reverted unless you intentionally updated the submodule

**Session example (OpenAmp):** After building Android APK, `git status` showed 200+ modified files in `.cxx/`, `.gradle/`, `build/`, and `linux/build/`. The correct path was `git reset && git add <source-files-only> && git commit`. Committing build artifacts would bloat the repo with machine-specific paths and generated binaries.

## Related Skills
- `spike` — for throwaway experiments
- `writing-plans` — when user wants structured planning instead of rapid stacking
- `concise-implementation` — minimum-narration execution mode

## References
- `references/gridos-egui-stacking-session.md` — detailed notes from a long GridOS egui desktop stacking session (May 2026) including observed user tolerance for technical debt and the effectiveness of full rewrites after heavy patching.
- `references/verbosity-correction-2026-05.md` — user signal about excessive narration during active stacking ("are you actually doing anything?") and the resulting verbosity rule.
- `references/hermes-wingman-architecture.md` — three-layer architecture pattern (Flutter → Rust Axum → Python helpers) used for the Hermes Wingman GUI, including CLI audit methodology and schema-based dynamic form pattern.