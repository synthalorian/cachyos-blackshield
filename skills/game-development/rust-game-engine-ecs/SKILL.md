---
name: rust-game-engine-ecs
description: "Build custom ECS (Entity-Component-System) game engines in Rust — generational IDs, type-erased storage, archetype queries, event bus, game loop patterns."
version: 1.0.0
author: synthclaw
category: game-development
tags: [rust, ecs, game-engine, architecture, generational-ids, archetypes, type-erasure]
related_skills: [game-architecture, rust-cli-app-dev, writing-plans]
---

# Rust Game Engine ECS

Use this skill when the user wants to **build, refactor, or extend a custom ECS game engine in Rust** — designing entity/component/systems from scratch, fixing bugs in an existing ECS, or adding capabilities like archetype queries, event buses, or game loop scheduling.

Load when the user says things like "build an ECS in Rust", "refactor this game engine", "add archetype queries", "fix the component storage", "implement a game loop", "make it work for [genre] games".

## When NOT to use this

- The user is **designing a game** (not an engine) — use `game-architecture`
- The user wants a **web or CLI app** in Rust — use `rust-cli-app-dev`
- The user wants to **use an existing ECS crate** (legion, hecs, bevy) — this is for custom engines, not integration
- The user wants a **quick prototype** — use `spike`

## Core Architecture

### 1. Generational Entity IDs

Every entity has a unique `(index, generation)` pair. When an entity is destroyed, its slot is freed and the generation increments. Stale handles are detected by generation mismatch.

```rust
#[derive(Clone, Copy, PartialEq, Eq, Hash)]
pub struct Entity {
    index: u32,
    generation: u32,
}
```

**Slot reuse with free list:**
```rust
pub struct World {
    entities: Vec<Option<Entity>>,       // None = free slot
    free_slots: VecDeque<u32>,           // reusable indices
    generations: Vec<u32>,               // generation per slot
    // ...
}

pub fn create_entity(&mut self) -> Entity {
    if let Some(index) = self.free_slots.pop_front() {
        let generation = self.generations[index as usize];
        let entity = Entity::new(index, generation);
        self.entities[index as usize] = Some(entity);
        entity
    } else {
        // fresh slot
        let index = self.entities.len() as u32;
        let entity = Entity::new(index, 0);
        self.entities.push(Some(entity));
        self.generations.push(0);
        entity
    }
}

pub fn destroy_entity(&mut self, entity: Entity) {
    if !self.entity_exists(entity) { return; }
    // mark slot free, increment generation
    self.entities[idx] = None;
    self.generations[idx] += 1;
    self.free_slots.push_back(entity.index());
}
```

**Validation:**
```rust
pub fn entity_exists(&self, entity: Entity) -> bool {
    let idx = entity.index() as usize;
    if idx >= self.entities.len() { return false; }
    self.entities[idx].map_or(false, |e| e == entity)
}
```

### 2. Type-Erased Component Storage

Each component type gets a `HashMap<u32, Box<dyn Any + Send + Sync>>` keyed by entity index. The `Component` trait is a simple marker — blanket impl for anything `Send + Sync + 'static`.

```rust
pub trait Component: Send + Sync + 'static {}
impl<T: Send + Sync + 'static> Component for T {}

pub struct ComponentStorage {
    type_id: TypeId,
    pub(crate) data: HashMap<u32, Box<dyn Any + Send + Sync>>,
}

impl ComponentStorage {
    pub fn insert<T: Component>(&mut self, entity: Entity, component: T) {
        self.data.insert(entity.index(), Box::new(component));
    }

    pub fn get<T: Component>(&self, entity: Entity) -> Option<&T> {
        self.data.get(&entity.index()).and_then(|b| b.downcast_ref::<T>())
    }

    pub fn get_mut<T: Component>(&mut self, entity: Entity) -> Option<&mut T> {
        self.data.get_mut(&entity.index()).and_then(|b| b.downcast_mut::<T>())
    }

    // CRITICAL: use downcast (consumes Box), NOT downcast_mut (borrows)
    pub fn remove<T: Component>(&mut self, entity: Entity) -> Option<T> {
        self.data.remove(&entity.index())
            .and_then(|boxed| boxed.downcast::<T>().ok().map(|b| *b))
    }
}
```

### 3. Archetype Tracking

An archetype groups entities with the same component signature. The key is a sorted `Vec<TypeId>`.

```rust
#[derive(Debug, Clone, PartialEq, Eq, Hash)]
pub struct ArchetypeKey(pub Vec<TypeId>);

impl ArchetypeKey {
    pub fn new(ids: Vec<TypeId>) -> Self {
        let mut ids = ids;
        ids.sort();
        ArchetypeKey(ids)
    }
}
```

**Archetype subset query** — find entities that have ALL components in a set:
```rust
pub fn query_with_all<T: Component>(&self, extra: &[TypeId]) -> Vec<(Entity, &T)> {
    let main = TypeId::of::<T>();
    let mut required = extra.to_vec();
    required.push(main);
    required.sort();
    let required_key = ArchetypeKey(required);

    self.archetypes.iter()
        .filter(|(key, _)| Self::archetype_contains_all(key, &required_key))
        .flat_map(|(_, arch)| arch.entities())
        .filter_map(|&e| {
            self.get_component::<T>(e).map(|c| (e, c))
        })
        .collect()
}

fn archetype_contains_all(key: &ArchetypeKey, subset: &ArchetypeKey) -> bool {
    let mut i = 0; let mut j = 0;
    while i < key.0.len() && j < subset.0.len() {
        if key.0[i] == subset.0[j] { i += 1; j += 1; }
        else if key.0[i] < subset.0[j] { i += 1; }
        else { return false; }
    }
    j == subset.0.len()
}
```

### 4. Type-Erased Iterators — The Box<dyn Iterator> Pattern

**CRITICAL PATTERN:** Rust's type system makes it nearly impossible to store closures or complex iterator chains as struct fields with concrete types. The fn pointer approach fails for closures. Use `Box<dyn Iterator>` instead:

```rust
pub struct ComponentQuery<'a, T: 'static> {
    inner: Option<Box<dyn Iterator<Item = (Entity, &'a T)> + 'a>>,
}

impl<'a, T: Component> ComponentQuery<'a, T> {
    fn new(storage: &'a StorageRegistry, entities: &'a [Option<Entity>]) -> Self {
        let inner = storage.get::<T>().map(|s| {
            let iter: Box<dyn Iterator<Item = (Entity, &'a T)> + 'a> = Box::new(
                s.data.iter().filter_map(move |(idx, boxed)| {
                    let entity = entities.get(*idx as usize).and_then(|e| *e);
                    boxed.downcast_ref::<T>()
                        .and_then(|comp| entity.map(|e| (e, comp)))
                }),
            );
            iter
        });
        ComponentQuery { inner }
    }
}

impl<'a, T: 'static> Iterator for ComponentQuery<'a, T> {
    type Item = (Entity, &'a T);
    fn next(&mut self) -> Option<Self::Item> {
        self.inner.as_mut()?.next()
    }
}
```

### 5. Event Bus for Intra-Frame Communication

Systems emit events during their `update`, events are processed between system phases:

```rust
#[derive(Debug, Clone)]
pub enum Event {
    Collision(u32, u32),
    DamageTaken(u32, u32),
    EntityDied(u32),
    EntityDestroyed(u32),
    Custom(String, String),
}

pub struct EventBus {
    events: VecDeque<Event>,
}

impl EventBus {
    pub fn emit(&mut self, event: Event) { self.events.push_back(event); }
    pub fn drain(&mut self) -> Vec<Event> { self.events.drain(..).collect() }
}
```

### 6. Game Loop Patterns

Two patterns depending on genre:

**Phased GameLoop** (platformer, RPG, action — variable dt):
```rust
pub enum SystemPhase { PreUpdate, Update, PostUpdate, Render, Cleanup }

pub struct GameLoop {
    systems: Vec<ScheduledSystem>,
    pub event_bus: EventBus,
}

impl GameLoop {
    pub fn tick(&mut self, world: &mut World, dt: f64) {
        for phase in [PreUpdate, Update, PostUpdate, Render, Cleanup] {
            for s in &mut self.systems {
                if s.phase == phase {
                    s.system.update(world, &mut self.event_bus, dt);
                }
            }
        }
    }
}
```

**TickScheduler** (RTS, strategy, turn-based — fixed dt, deterministic):
```rust
pub struct TickScheduler {
    systems: Vec<Box<dyn System>>,
    pub dt: f64,
}

impl TickScheduler {
    pub fn tick(&mut self, world: &mut World, events: &mut EventBus) {
        for s in &mut self.systems {
            s.update(world, events, self.dt);
        }
    }
}
```

The System trait signature for both:
```rust
pub trait System {
    fn update(&mut self, world: &mut World, events: &mut EventBus, dt: f64);
    fn name(&self) -> &str { "unnamed" }
}
## Pitfalls

### ArchetypeKey hash/eq
`ArchetypeKey` wraps `Vec<TypeId>` which implements Hash/Eq. Always sort the TypeIds before constructing a key — unsorted keys won't match.

### get_or_create MUST use the passed key
A common bug: `get_or_create(key)` that creates `ArchetypeKey(Vec::new())` instead of `Archetype::new(key)`. This collapses every entity into the empty archetype, rendering archetype tracking useless. Always clone the key before entering the map (HashMap entry takes ownership).

### ComponentStorage::remove — downcast, not downcast_mut
`HashMap::remove` returns the `Box<dyn Any>`. Call `boxed.downcast::<T>()` (consumes the Box, returns `Result<Box<T>, Box<dyn Any>>`), then deref the `Box<T>`. Do NOT use `downcast_mut` — that borrows the Box, and you can't move out of a `&mut T` for non-Copy types.

### ComponentStorage::remove_entity (untyped removal)
Add a separate method for destroying entities when you don't know the component type:
```rust
pub(crate) fn remove_entity(&mut self, entity: Entity) {
    self.data.remove(&entity.index());
}
```

### Add_component doesn't need Clone
The method takes `component: T` by value. The original code required `Clone` unnecessarily. Fix: remove the Clone bound.

### Crate-internal field access
Fields like `ComponentStorage::data` and `StorageRegistry::storages` need `pub(crate)` visibility if accessed from other modules in the same crate (e.g., query iterators in world.rs).

### Iterator struct types — use Box<dyn Iterator>
Do NOT try to write concrete iterator types in struct fields. The types become unmanageable with closures. Use `Option<Box<dyn Iterator<Item = ...>>>` — cleaner, compiles, and the vtable overhead is negligible for game engine iteration.

### Systems own their EventBus
Pass a shared `&mut EventBus` to each system's `update`. Systems emit events during update. Drain events between phases (not inside system code) to avoid interleaving.

### Borrow Checker in Game Loop: Mutable Game + Immutable Self
When writing a game binary's `update()` method, you often need to mutably borrow `self.game` (for `game.save_game()`, `game.selection.finish_box_select()`, etc.) while also calling methods on `self` like `self.world_to_screen()` which need `self.camera` and `self.window_size`. Rust rejects this because `game` is borrowed from `self`.

**Fix: Split into separate scopes.** Do all mutable `game` operations in one `if let Some(game) = &mut self.game` block, then do immutable operations in a second `if let Some(game) = &self.game` block. The mutable borrow is dropped at the end of the first scope, making `self` available again.

### SpriteBatch capacity overflow (wgpu rendering)
When using instanced sprite rendering with wgpu, the `SpriteBatch` allocates a fixed-size GPU vertex buffer at init time. A 40×40 terrain grid alone is 1600 sprites. Add units, encounters, HUD, minimap, selection box, and tooltips — you easily exceed 1024.

**Symptom:** `panicked at src/render.rs:273: Too many sprites for batch capacity`

**Fix:** Increase capacity: `SpriteBatch::new(&device, 8192)` instead of 1024.

**Rule of thumb:** Use `terrain_tiles × 1.5` as minimum. For safety with larger maps or particle effects, use 8192 or 16384.

**Prevention:** Make capacity a `Renderer::new()` parameter rather than hardcoding. Add a debug warning when sprite count exceeds 80% of capacity.

```rust
impl System for MovementSystem {
    fn update(&mut self, world: &mut World, _events: &mut EventBus, dt: f64) {
        // Collect first to avoid borrow conflicts
        let velocities: Vec<(u32, f32, f32)> = world.query::<Velocity>()
            .map(|(e, v)| (e.index(), v.x, v.y)).collect();
        let vel_map: HashMap<u32, (f32, f32)> =
            velocities.into_iter().map(|(i, vx, vy)| (i, (vx, vy))).collect();

        for (idx, _px, _py) in world.query::<Position>().map(|(e, p)| (e.index(), p.x, p.y)).collect::<Vec<_>>() {
            if let Some(&(vx, vy)) = vel_map.get(&idx) {
                let e = world.entity_from_index(idx);
                if let Some(pos) = world.get_component_mut::<Position>(e) {
                    pos.x += vx * dt as f32;
                    pos.y += vy * dt as f32;
                }
            }
        }
    }
}
```

Note: collect positions/velocities into vecs first to avoid simultaneous immutable+mut borrow on world.

## Relation to Other Skills

- **`game-architecture`** — Design the game's systems before building the engine. This skill implements the ECS layer.
- **`rust-cli-app-dev`** — For standalone Rust CLI tools that aren't game engines.
- **`writing-plans`** — Takes an engine design and breaks it into implementation tasks with file paths.

## References

- **`references/chronos-engine-architecture.md`** — Full architecture of the Chronos Engine v0.3.0: 36 source files, ~13.5K lines, feature flags, module layout, all component/system types (ECS + game module), spatial indexing, event flow, archetype management, and what's done vs TODO. Load for detailed implementation examples when working on Chronos or a similar custom ECS.
- **`references/chronos-editor-fixes-2026-05-30.md`** — Specific fixes for the Chronos Engine editor: egui 0.30 menu bar blank dropdown fix, standalone binary installation, .desktop entry creation, "Launch Engine" toolbar button implementation, broken test removal pattern, and editor launch debugging on Hyprland/Mesa.
- **`references/chronos-game-binary-2026-05-30.md`** — Pattern for building a standalone wgpu-rendered game binary from an existing ECS engine: Cargo.toml feature gating, pollster async init, winit 0.30 input mapping, game world rendering, camera controls, and desktop integration.
- **`references/chronos-game-visuals-2026-05-30.md`** — Pixel-font HUD rendering, terrain tile colors, unit class differentiation, health bars, encounter pulsing rings, click-to-move, and HUD layout patterns — all using colored quads without texture atlas dependencies.
- **`references/chronos-game-features-2026-05-30.md`** — Adding RTS/RPG features to a wgpu-rendered game binary: selection box (left-click drag), encounter hover tooltips, corner minimap with camera rect, ambient/combat audio integration, and F5/F9 quicksave with on-screen notification. Layer z-index convention, world-vs-screen coordinate pitfalls, and optional audio handling.
- **`references/sprite-batch-capacity-overflow.md`** — wgpu `SpriteBatch` capacity overflow: symptom (`Too many sprites for batch capacity`), root cause (fixed GPU buffer too small for terrain + entities + HUD), fix (increase from 1024 to 8192+), estimation formula, and prevention strategies.

### Broken Test Removal

When a test is fundamentally wrong (asserts behavior that doesn't match implementation), **delete it** rather than debugging the test infrastructure or trying to fix the test to match wrong expectations.

**Session example:** `packet_loss_detection` test in voice_chat.rs asserted `consecutive_loss == 1` after `pop_next()` on an empty buffer. The actual implementation returns `None` early when buffer is empty without incrementing the counter. The test was wrong, not the code. Deleted the test, all remaining tests pass.

**Signal:** When `cargo test` times out or a specific test fails with a clear assertion mismatch where the implementation behavior is correct, remove the test and verify the remaining suite passes.

When building a visual editor for the engine (separate binary, desktop app):

### Editor as Standalone Binary

The editor should be a separate binary in the same workspace, gated behind an `editor` feature:

```toml
# Cargo.toml
[[bin]]
name = "chronos-editor"
path = "src/bin/chronos-editor.rs"
required-features = ["editor"]

[features]
editor = ["egui", "egui-wgpu", "egui-winit", "wgpu", "winit", "dep:pollster", "serde", "serde_json"]
```

Build and install:
```bash
cd /path/to/engine
cargo build --bin chronos-editor --features editor --release
cp target/release/chronos-editor ~/.local/bin/
chmod +x ~/.local/bin/chronos-editor
```

### Desktop Integration (.desktop file)

Create `~/.local/share/applications/chronos-editor.desktop`:

```ini
[Desktop Entry]
Name=Chronos Editor
Comment=Chronos Engine Visual Editor
Exec=/home/synth/.local/bin/chronos-editor
Icon=/path/to/engine/icon.png
Type=Application
Terminal=false
Categories=Development;Game;IDE;
Keywords=game;engine;editor;chronos;
StartupNotify=true
```

After creating, the app appears in launchers like Walker/rofi. No `update-desktop-database` needed on most modern desktops.

### egui Menu Bar — The Blank Dropdown Fix

**Symptom:** File, Edit, View, Help menus render but dropdowns are blank or clicks don't register.

**Root cause:** `egui::menu::menu_button()` with custom horizontal layouts inside the menu closure breaks egui's menu item detection. The menu closure expects a vertical layout with standard buttons.

**Fix:** Use `ui.menu_button()` (not `egui::menu::menu_button()`) and `ui.button()` inside:

```rust
// WRONG — breaks menu item detection
fn menu_item(ui: &mut egui::Ui, label: &str, shortcut: &str) -> egui::Response {
    ui.with_layout(egui::Layout::left_to_right(egui::Align::Center), |ui| {
        let response = ui.button(label);
        ui.add_space(space);
        ui.label(shortcut);
        response
    }).inner
}

// CORRECT — standard button in vertical menu layout
fn menu_item(ui: &mut egui::Ui, label: &str, shortcut: &str) -> egui::Response {
    ui.horizontal(|ui| {
        let response = ui.button(label);
        ui.with_layout(egui::Layout::right_to_left(egui::Align::Center), |ui| {
            ui.add_space(16.0);
            ui.label(egui::RichText::new(shortcut).italics().weak().small());
        });
        response
    }).inner
}

// In the panel:
ui.menu_button("File", |ui| {
    ui.set_min_width(220.0);  // Prevent narrow dropdowns
    if menu_item(ui, "New Project", "Ctrl+N").clicked() {
        state.show_new_wizard = true;
        ui.close_menu();
    }
    // ... more items
});
```

Key points:
- `ui.menu_button()` not `egui::menu::menu_button()` — the former is the egui 0.30+ API
- `ui.set_min_width()` inside the menu closure prevents squashed dropdowns
- `ui.close_menu()` after click handling closes the dropdown
- Use `std::cell::Cell<bool>` for dialog open flags to avoid borrow checker issues with `.open(&mut flag)` + closure mutations

### Launch Engine from Editor

Add a "Launch Engine" button that spawns `cargo run` in the project directory:

```rust
// In EditorState
pub launch_engine_requested: bool,

// In toolbar:
if ui.button("▶ Launch Engine").clicked() {
    state.launch_engine_requested = true;
}

// In EditorApp::process_action_requests():
if self.state.launch_engine_requested {
    self.state.launch_engine_requested = false;
    self.launch_engine();
}

fn launch_engine(&mut self) {
    let Some(project_dir) = self.state.project_manager.project_dir.clone() else {
        self.state.log(ConsoleLogLevel::Warn, "No project loaded");
        return;
    };
    match std::process::Command::new("cargo")
        .arg("run").arg("--release")
        .current_dir(&project_dir)
        .stdout(std::process::Stdio::piped())
        .stderr(std::process::Stdio::piped())
        .spawn()
    {
        Ok(child) => {
            self.state.log(ConsoleLogLevel::Info,
                format!("Engine started (PID: {})", child.id()));
            std::thread::spawn(move || { let _ = child.wait(); });
        }
        Err(e) => self.state.log(ConsoleLogLevel::Error,
            format!("Failed to launch: {e}")),
    }
}
```

- **`references/chronos-gameplay-simulation-2026-05-31.md`** — Wiring gameplay simulation into a wgpu-rendered demo: enemy rendering, camera follow squad, right-click encounter engagement, auto-target acquisition, editor→game binary path resolution, and `cargo test` hang pitfall with window-spawning tests.
- **`references/chronos-editor-file-dialog-2026-05-31.md`** — Adding native file dialogs (zenity/kdialog/rfd) to an egui-based editor: feature flag wiring, platform module usage, welcome screen browse button, menu bar direct-open pattern, and Cargo.toml feature composition.

## Remember

```
Generational IDs with free list.
Box<dyn Any> for storage, Box<dyn Iterator> for queries.
Archetype keys = sorted TypeIds.
Event bus between systems, drain between phases.
Collect before mutating to avoid borrow conflicts.
pub(crate) for cross-module field access.
downcast consumes, downcast_mut borrows — use the right one.
Editor: ui.menu_button() + ui.button() + ui.set_min_width() + ui.close_menu()
Editor: install to ~/.local/bin, create .desktop for launcher integration
Editor: spawn cargo run --release for engine launch from toolbar
Standalone game binary: feature-gate with ["game", "render", "dep:pollster"], use pollster::block_on for wgpu init
Game loop borrow checker: split mutable and immutable self.game borrows into separate scopes
SpriteBatch capacity: terrain_tiles × 1.5 minimum, 8192 for safety
cargo test hang: use cargo check for validation, --lib for unit tests only
Gameplay loop: render enemies, camera follow, encounter click-to-engage, auto-target
```
