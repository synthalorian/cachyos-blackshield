---
name: odin-game-dev
description: Use for Odin + SDL2 engine/game work (VoidEngine).
---

# Odin Game Development (Odin + SDL2)

Use when working on VoidEngine (`~/Projects/active/voidengine`) or any Odin + SDL2 engine/game project on CachyOS.

## Environment

- Odin: `sudo pacman -S odin` (CachyOS repos, dev-rolling build)
- SDL: `sdl2-compat` (SDL2-on-SDL3 shim, provides `sdl2`) satisfies the dependency — do NOT try to install real `sdl2`, it conflicts. `sdl2_mixer`, `sdl2_image` install normally on top.
- Odin vendor bindings: `vendor:sdl2`, `vendor:sdl2/mixer`, `vendor:sdl2/image` — no extra binding setup needed.

## Workflow

- `make check` (odin check, fast type-check) → `make test` (odin test, memory-tracked) → `make` builds. Run all three before committing.
- Makefile binary targets (`shmup`, `demo`, ...) MUST be in `.PHONY` — otherwise existing binaries silently skip rebuilds.
- `odin test` has a built-in memory tracker: leak warnings per test with allocation site. Treat any leak warning as a failing test; fix ownership, don't suppress.

## Odin Language Gotchas

- **Packages are directory-based**: every `.odin` file in `src/core/` is the same package. Add features as new files (`sprite.odin`, `tilemap.odin`) — no imports needed between them, no merge conflicts on a single mega-file.
- `os.read_entire_file_from_path` returns `([]u8, os.Error)` — check `err != nil`, NOT `if !ok`. (API changed; old bool-return snippets are stale.)
- `os.write_entire_file_from_bytes(path, bytes)` returns `os.Error` too.
- `free(rawptr)` works untyped — an ECS can free component `rawptr`s without knowing their type.
- Dynamic arrays of structs (`[dynamic]Entity`) REALLOC-MOVE elements on append — never return/hold `&arr[i]` across appends. Use `[dynamic]^Entity` with `new()` per element for pointer-stable handles.
- `unordered_remove(&arr, i)` swaps last into slot i — safe self-removal pattern when draining a list from the back.
- Unused proc PARAMETERS are fine; unused local variables are compile errors.
- `transmute([]u8)some_string` for writing string literals to files in tests.

## ECS Ownership Pattern (VoidEngine convention)

- `entity_add_component` takes OWNERSHIP: component must be heap-allocated via `new(T)`; engine frees it. Document this on the proc — ambiguity here caused double-frees in tests vs leaks in examples.
- Teardown chain: `entity_destroy` (frees components + map, marks inactive, keeps slot for pointer stability) → `scene_cleanup` (stack scenes: destroys + frees entities, deletes array) → `scene_destroy` (heap scenes: cleanup + unregister from engine + free Scene) → `engine_shutdown` drains `scene.scenes` from the back.
- Components owning inner allocations (e.g. ParticleEmitter's dynamic array) leak their backing store on `free()` — provide a per-component `*_destroy` helper and document that callers must invoke it before scene teardown.

## Pitfalls

- **Flaky compiler segfault**: `odin build` segfaulted once under parallel make; clean retry succeeded. Retry pattern, not a code bug. If recurring, pin an Odin release instead of rolling dev builds.
- **`.gitignore` `core` pattern swallows `src/core/`**: core-dump ignore entries (`core`, `core.*`) match the source DIRECTORY. Anchor them: `/core`, `/core.*`. Symptom: old files in the dir stay tracked (edits commit fine) but NEW files are silently ignored — `git add` fails with "paths are ignored".
- sdl2-compat conflict: `sudo pacman -S sdl2` errors with "sdl2 and sdl2-compat are in conflict" — just use what's installed.
- SDL2 alone loads only BMP; PNG/JPG need `vendor:sdl2/image` (`IMG.Init(IMG.INIT_PNG | IMG.INIT_JPG)`, `IMG.Load`).
- When extending a component struct (e.g. adding `texture` to Sprite), keep zero-value = old behavior (nil texture → colored rect fallback) so existing examples compile unchanged.
- Test expectations for accumulator-style animation timers must account for carried remainder time (`anim.timer` persists between updates).

## References

- `references/voidengine-v040-session.md` — full v0.3→v0.4 session detail: commit sequence, ownership fix diffs, feature module APIs (TextureManager/Animation/Tilemap/ParticleEmitter), test suite layout.
