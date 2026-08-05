# Chronos Engine Architecture (v1.0.0)

A custom ECS game engine in Rust. **~53,000 lines** across **96 source files**. **971 tests** (946 unit + 25 integration). Zero `unsafe` blocks.

**GitHub**: `synthalorian/chronos-engine`

## Module Layout

```
src/
├── lib.rs                  — Public API — re-exports all modules
├── main.rs                 — Terminal demos
│
│  ═══ ECS Core ═══
├── entity.rs               — Generational entity IDs
├── component.rs            — Component trait + 11 built-in types
├── storage.rs              — Type-erased component storage
├── world.rs                — World — entity lifecycle, archetypes, queries
│
│  ═══ Systems & Scheduling ═══
├── system.rs               — 8 systems, GameLoop, TickScheduler, EventBus
├── input.rs                — Input system — keyboard, mouse, gamepad
│
│  ═══ Spatial & Physics ═══
├── spatial.rs              — Quadtree, AABB, Ray (2D)
├── octree.rs               — Octree, AABB3D, Ray3D (3D)
├── physics2d.rs            — 2D physics — rigid bodies, contact solver, raycasting
├── physics3d.rs            — 3D physics — rigid bodies, constraints, collision response
│
│  ═══ Rendering ═══
├── render.rs               — 2D sprite batch renderer (wgpu 23)
├── render3d.rs             — 3D renderer with depth buffer
├── texture.rs              — Texture atlas + frame extraction
├── font.rs                 — Bitmap font rendering
├── tilemap.rs              — Chunked tile map with frustum culling
├── particle.rs             — Particle emitter + presets (explosion/smoke/trail)
├── postprocess.rs          — Post-processing — color grading, bloom, vignette, CRT/noir/sunset
├── obj_loader.rs           — Wavefront .obj parser
│
│  ═══ Animation & Materials ═══
├── animation.rs            — State machine, blend tree, sprite animation, timeline
├── skeletal.rs             — Skeletal animation — joints, poses, SLERP, blending
├── material.rs             — Material system — 7 built-in presets
├── shader.rs               — Shader graph — 28 node types, WGSL generation, hot-reload
│
│  ═══ Advanced Systems ═══
├── lighting.rs             — 2D lighting + shadow casting
├── fog_of_war.rs           — Fog of war + line-of-sight
├── ui.rs                   — UI widgets — Button, Slider, Label, Panel
├── general_systems.rs      — Camera2D, TilemapEx, Pathfinder2D, AudioZone, Footsteps
│
│  ═══ Scene & Assets ═══
├── scene.rs                — Scene/level serialization
├── audio.rs                — Audio engine (rodio)
├── asset.rs                — Asset pipeline + hot reload
│
│  ═══ Editor ═══
├── editor.rs               — Developer overlay
├── editor_app.rs           — Editor desktop app (winit + wgpu + egui)
├── editor_panels/          — Editor UI panels
│   ├── mod.rs              — EditorPanel trait, EditorState, shared types
│   ├── viewport.rs         — Scene viewport (camera, grid, FPS, gizmo)
│   ├── hierarchy.rs        — Entity tree (add/delete/duplicate/search)
│   ├── inspector.rs        — Component property editor (drag sliders, 11 types)
│   ├── asset_browser.rs    — File browser (list/grid views, type detection)
│   ├── console.rs          — Log output + command processor (help/clear/echo/entities)
│   ├── toolbar.rs          — Play/Pause/Stop, gizmo mode, snap toggle
│   ├── menu_bar.rs         — File/Edit/View/Help menus, shortcuts dialog, about dialog
│   └── welcome.rs          — Welcome screen — new project, open recent, templates
├── editor_workspace/       — Editor workspace tools
│   ├── mod.rs              — Shared types (PickResult, SelectionRect, snap_to_grid)
│   ├── undo.rs             — UndoStack + EditorCommand trait (dual-stack, type-erased)
│   ├── grid.rs             — Infinite ground grid renderer (axis coloring, snap)
│   ├── gizmo.rs            — Translate/Rotate/Scale gizmos (mouse drag, axis hit-test)
│   ├── selection.rs        — Viewport click-pick (ray), box select, multi-select
│   ├── shortcuts.rs        — Configurable keybindings (Blender-style defaults)
│   ├── settings.rs         — Settings dialog (rendering/editor/shortcuts tabs)
│   └── docking.rs          — Panel docking — tree layout, drag-drop, serialize/restore
├── editor_project/         — Project management
│   ├── mod.rs              — Project module root
│   └── project.rs          — ProjectManager — open/save/validate, templates, recent
│
│  ═══ Scripting ═══
├── scripting/              — Rhai scripting engine
│   ├── mod.rs              — Scripting module root
│   ├── bridge.rs           — Rhai engine bridge — register ECS types, compile/eval
│   ├── component.rs        — ScriptComponent, ScriptHandle, ScriptRegistry
│   ├── lifecycle.rs        — ScriptLifecycle — on_start/on_update/on_destroy/on_collision
│   ├── api.rs              — Script API — math, entity, debug, time, input, audio, physics
│   ├── hotreload.rs        — Script hot-reload — polling watcher, configurable policies
│   └── modloader.rs        — ModLoader, ModMetadata, ModBuilder, sandboxing
│
│  ═══ Asset Import Pipeline ═══
├── import/                 — Advanced asset importers
│   ├── mod.rs              — Import module root
│   ├── audio_import.rs     — WAV/OGG/MP3/FLAC → PCM buffers (symphonia)
│   ├── font_import.rs      — TTF/OTF → bitmap glyph atlases (ab_glyph)
│   ├── gltf_import.rs      — glTF/GLB → meshes, materials, animations, skins
│   ├── image_import.rs     — PNG/JPG/BMP/TGA → RGBA + mipmaps (box-filter)
│   ├── metadata.rs         — .meta files — GUIDs, import settings, staleness detection
│   └── registry.rs         — GUID-based asset registry — ref counting, GC
│
│  ═══ Networking ═══
├── net/                    — Multiplayer networking
│   ├── mod.rs              — Net module root
│   ├── transport.rs        — UDP transport layer
│   ├── lobby.rs            — Matchmaking lobby
│   ├── lockstep.rs         — Deterministic lockstep scheduler
│   ├── rollback.rs         — Input prediction + rollback
│   ├── entity_sync.rs      — Entity state synchronization
│   ├── lag_compensation.rs — Hit registration with lag compensation
│   └── voice_chat.rs       — Voice chat (Opus codec, jitter buffer, spatial audio)
│
│  ═══ Platform ═══
├── platform/               — Platform abstraction
│   ├── mod.rs              — Platform module root
│   ├── linux.rs            — Linux-specific (config dir, dialogs)
│   ├── windows.rs          — Windows-specific
│   ├── macos.rs            — macOS-specific
│   ├── wasm.rs             — WebAssembly-specific
│   └── fallback.rs         — Fallback stubs
│
│  ═══ Plugin System ═══
├── plugin/                 — Runtime plugin system
│   ├── mod.rs              — Plugin module root
│   ├── api.rs              — Plugin API surface
│   └── editor.rs           — Editor plugin integration
│
│  ═══ Demo Game ═══
└── game/                   — Chronos Company — demo RPG (28 modules)
    ├── mod.rs              — Game module root
    ├── components.rs       — Game components (11 types)
    ├── mercenary.rs        — Mercenary factory + Warrior/Archer/Mage/Scout templates
    ├── terrain.rs          — Terrain grid + procedural heightmap
    ├── navigation.rs       — A* pathfinding on terrain
    ├── camera.rs           — Tabletop/isometric camera (orbit, pan, zoom, auto-follow)
    ├── selection.rs        — Unit selection system
    ├── squad.rs            — Squad controller + 4 formations (Line/Column/Circle/Wedge)
    ├── ai.rs               — Enemy AI state machine (patrol, aggro, chase, combat)
    ├── combat.rs           — Combat system (melee/ranged/magic, STR/DEX/INT scaling)
    ├── ability.rs          — Ability system (6 types, cooldowns, mana, 4 slots/unit)
    ├── loot.rs             — Loot drops, auto-pickup, gold stacking
    ├── stats.rs            — STR/DEX/INT/VIT, leveling, XP, stat allocation
    ├── equipment.rs        — 7 equipment slots, stat bonuses, level gating
    ├── jobs.rs             — Procedural bounty/contract generation (6 types, 5 tiers)
    ├── dialogue.rs         — Branching NPC conversations, condition gates
    ├── factions.rs         — 7 factions, reputation, pricing modifiers
    ├── inventory_ui.rs     — Item management, sorting, filtering, drag-drop
    ├── world_map.rs        — Procedural biomes, exploration
    ├── poi.rs              — Points of interest — towns, dungeons, camps, discovery
    ├── daynight.rs         — Day/night cycle, 6-phase lighting
    ├── encounters.rs       — Random encounters, ambushes, difficulty scaling
    ├── save.rs             — Save/load, versioning, checksums, auto-save
    ├── minimap.rs          — Explored/fog cells, POI/enemy markers, terrain colors
    ├── hud.rs              — Health/mana/XP bars, tooltips, notifications, squad panel
    ├── screens.rs          — Screen stack, transitions, button layouts, presets
    ├── effects.rs          — 16 visual effect types, particle profiles
    ├── ambience.rs         — Sound zones, music triggers, footstep tracking
    └── tutorial.rs         — Objectives, hints, guided sequences
```

## Binaries

| Binary | Path | Features | Purpose |
|--------|------|----------|---------|
| `chronos` | `src/bin/chronos-cli.rs` | default | CLI — `new`, `build`, `run`, `test`, `package` |
| `chronos-editor` | `src/bin/chronos-editor.rs` | `editor` | Visual editor — winit + wgpu + egui |

## Feature Flags

| Flag | Dependencies | What |
|------|-------------|------|
| *(default)* | **None** — pure `std` | ECS core, systems, spatial indexing, input, physics, animations, materials, shaders, tilemaps, particles, lighting, fog of war |
| `render` | wgpu 23, winit 0.30, bytemuck, rand, tokio, image | 2D/3D rendering, UI, post-processing, developer overlay |
| `serialize` | serde, serde_json | Scene/level serialization, entity prefabs |
| `audio` | rodio 0.20 | Audio engine, spatial audio, music crossfade |
| `dev-tools` | notify 7, serde, serde_json | Asset pipeline, hot reload |
| `game` | render (transitive) | Chronos Company demo game modules |
| `editor` | egui 0.30, egui-wgpu, egui-winit, wgpu, winit, pollster, serde, serde_json | Desktop editor application |
| `scripting` | rhai 1 | Rhai scripting engine, component scripts, modding |
| `asset-pipeline` | gltf, symphonia, ab_glyph, uuid, serde, serde_json, image | Advanced importers (glTF, audio, fonts, images), GUID registry, metadata |
| `net` | serde, serde_json, rand | Multiplayer networking (transport, lobby, lockstep, rollback) |
| `voice-chat` | audiopus | Voice chat (Opus codec, jitter buffer) |
| `full` | all of the above | Everything |

## Editor Status (Phase 7)

The editor is functional and standalone:

- **Menu bar** — File/Edit/View/Help with working dropdowns (fixed egui menu pattern)
- **Toolbar** — Play/Pause/Stop, gizmo mode (translate/rotate/scale), snap toggle, grid toggle, **Launch Engine** button
- **Viewport** — Camera controls, grid overlay, FPS counter, gizmo rendering
- **Hierarchy** — Entity tree, add/delete/duplicate, search, selection sync
- **Inspector** — Component property editor with drag sliders for all 11 built-in types
- **Asset Browser** — File browser with list/grid views, type detection
- **Console** — Log output with severity filters, command processor
- **Welcome Screen** — New project wizard (Empty, 2D Platformer, 3D Shooter, RPG), recent projects
- **Undo/Redo** — Dual-stack with type-erased commands
- **Project Management** — New/Open/Save/Close, `.chronos` project format, templates, recent list
- **Settings Dialog** — Rendering/editor/shortcuts tabs
- **Auto-save** — Every 60 seconds when project is loaded
- **Keyboard Shortcuts** — Blender-style defaults (W/E/R for gizmo, Ctrl+Z/Y for undo/redo, etc.)

**Launch:** `cargo run --bin chronos-editor --features editor` or `chronos-editor` (if installed to PATH)

## Key Architecture Patterns

1. **Generational IDs with free list** — slot reuse, stale handles never alias live entities
2. **Box<dyn Any> storage** — zero unsafe, type-erased per-component HashMaps
3. **Archetype tracking** — sorted TypeId keys, two-pointer subset matching for queries
4. **Feature-gated modules** — core is std-only, optional subsystems behind cargo features
5. **Dual schedulers** — GameLoop (variable) for action games, TickScheduler (fixed) for RTS/sims
6. **EventBus** — VecDeque-based, drain between phases for clean system decoupling
7. **Editor as separate binary** — `chronos-editor` binary with `editor` feature, not the default
8. **Desktop integration** — `.desktop` file + `~/.local/bin` install for launcher visibility
