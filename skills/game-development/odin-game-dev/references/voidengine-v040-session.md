# VoidEngine v0.3.0 → v0.4.0 Session (2026-07-24)

Repo: `~/Projects/active/voidengine` (github.com/synthalorian/voidengine). Odin + SDL2, single-package layout in `src/core/`.

## Commit sequence

1. `f7f20ae` — ECS memory ownership fix + Makefile `.PHONY` for binary targets
2. `2f5b69b` — `[dynamic]^Entity` pointer-stability rework
3. `7130781` — v0.4.0: sprite.odin / tilemap.odin / particles.odin + `.gitignore` `/core` anchor fix

## What was broken and how it was fixed

**Leak**: `odin test` memory tracker flagged 320B leaks at `entity_add_component` (engine.odin:518). Root cause was NOT component data (tests freed those manually) but the per-entity `components: map[typeid]rawptr` never being deleted, plus scenes heap-alloc'd in `scene_create` never freed (`engine_shutdown` ignored `engine.scene.scenes`).

**Ownership convention adopted** (was ambiguous: examples leaked everything, tests freed manually):
- `entity_add_component(entity, T, component)` — engine takes ownership; component must be `new(T)`; engine frees.
- `entity_destroy(scene, entity)` — nil-safe, idempotent: frees each component rawptr, `delete(components)`, map = nil, active = false. Slot stays (pointer stability).
- `scene_cleanup(scene)` — works on STACK scenes (tests): entity_destroy + free each entity, delete entities array.
- `scene_destroy(scene)` — for scenes from `scene_create`: cleanup + `unordered_remove` from `engine.scene.scenes` + `free(scene)`.
- `engine_shutdown` drains: `for len(engine.scene.scenes) > 0 { scene_destroy(scenes[len-1]) }` then `delete(scenes)`.
- Tests updated: `defer engine.scene_cleanup(&scene)` replaced `defer delete(scene.entities)` + manual `free()`s (which became double-frees).

**Pointer landmine**: `entity_create` returned `&scene.entities[len-1]` into a `[dynamic]Entity`. Append-driven realloc invalidated earlier `^Entity`s (tests held `a` across `entity_create(b)` and passed by luck). Fix: `[dynamic]^Entity` + `new(Entity)` per entity. Only touch points: Scene struct, scene_create, entity_create, scene_cleanup, physics_update, find_collisions, one shmup line (`&e.scene.current_scene.entities[0]` → drop the `&`). Examples otherwise never touched `.entities` directly. Regression test `entity_pointers_stay_valid`: hold first entity, append 256, verify id/active/component intact.

## Feature module APIs (src/core, package voidengine)

**sprite.odin**
- `TextureManager{textsures: map[string]^SDL.Texture, renderer}` on Engine as `textures` subsystem; init/shutdown wired into engine_init/engine_shutdown. Map keys are `strings.clone(name)`d.
- `texture_load(engine, name, path) -> ^SDL.Texture` (cached, IMG.Load → CreateTextureFromSurface), `texture_get(engine, name)`.
- `Sprite` extended: `texture: ^SDL.Texture` (nil → colored rect), `flip: SDL.RendererFlip`. `color` doubles as RGBA mod via SetTextureColorMod/AlphaMod.
- `Animation{frame_width, frame_height, columns, frames: []i32, frame_time, timer, current, loop, playing}`; `make_animation`, `animation_update(scene, dt)` (accumulator with carried remainder), `animation_src_rect` (frame % columns, frame / columns).
- `sprite_render(scene, renderer)`: RenderCopyEx w/ rad→deg rotation (×57.29578), scale-aware dst rect, anim src rect when Animation present.

**tilemap.odin**
- `Tilemap{width, height, tile_size, tiles: []i32, solid_ids: map[i32]bool}`; id 0 = always empty.
- `tilemap_create/destroy/get/set/set_solid/is_solid/is_solid_at_world`.
- `tilemap_load_csv(path, tile_size)` — newline rows, comma cells, trims whitespace, skips empty lines. Uses `os.read_entire_file_from_path` with `err != nil` check.
- `tilemap_collide(entity, tm)` — AABB (Transform+Collider) vs overlapped solid tiles.
- `tilemap_render(renderer, tm, tileset=nil, columns=1, offset_x=0, offset_y=0)` — tile ids are 1-based into sheet (`frame := id - 1`); nil tileset → debug rects (solid=magenta, other=dim gray).

**particles.odin**
- `ParticleEmitter` ECS component: rate emission (`emit_accum`), `particle_burst(emitter, pos, count)`, gravity, lifetime min/max, angle/speed ranges, size_start→end + color_start→end lerp.
- `particle_update(scene, dt)` — spawn at Transform position if present; expiry via `unordered_remove` swap-compaction.
- `particle_render(scene, renderer)` — alpha-fading rects.
- CLEANUP GOTCHA: emitter owns `[dynamic]ParticleInstance`; engine component teardown only frees the struct. Callers must `particle_emitter_destroy(emitter)` before scene teardown (tests use `defer` before `scene_cleanup`).

## Test suite layout (tests/test_engine.odin)

17 tests, all memory-tracked: config, transform/sprite/collider helpers, layer/mask, entity_components, 2× AABB collision, pointer-stability regression, math helpers, 3× animation (loop wrap, non-loop stop, src_rect), 2× tilemap (CSV roundtrip via /tmp file, solid collision), 2× particles (burst+expiry, rate emission ±10% tolerance).

Gotcha hit: animation wrap test needed carried-remainder math — after `animation_update(0.15)` with frame_time 0.1, timer carries 0.05; a following 0.25 yields 3 advances not 2.

## Environment notes

- Odin dev-2026-07 from cachyos-extra-v3. One flaky segfault under `make` parallel build; clean retry passed.
- sdl2-compat 2.32.70 provides `sdl2=2.32.70`; sdl2_mixer 2.8.2, sdl2_image 2.8.12 already installed.
- `.gitignore` had `core`/`core.*` (core dumps) which ignored `src/core/` entirely — engine.odin survived (tracked before gitignore), new files silently blocked. Fixed to `/core`, `/core.*`.
- Versioned as v0.4.0 in commit message; README feature list + deps (sdl2_image) updated in same commit.
