# Gameplay Simulation Wiring — Session 2026-05-31

## Context

The Chronos Company demo had all engine systems (ECS, combat, pathfinding, encounters, AI, progression) built and tested, but the demo binary (`chronos-game.rs`) was essentially a screensaver — it rendered the world but no actual gameplay executed. This reference covers wiring simulation systems into the game loop and making the demo interactive.

## Problem: Systems Exist But Don't Run

**Symptom:** Terrain renders, units are visible, encounters pulse on the map, HUD shows stats. But units don't move, encounters don't spawn enemies, combat never happens, clicking does nothing.

**Root cause:** The `GameSimulation` system (movement, encounters, AI, progression) was already implemented in `src/game/simulation.rs` and wired into `ChronosCompanyGame::tick()` in `runner.rs`. But the demo binary's rendering code didn't show enemies, didn't let players interact with encounters, and didn't auto-target enemies.

## Fix 1: Render Enemy Entities

The demo only rendered squad units. Enemy entities (spawned from encounters) were invisible.

```rust
// In gather_sprites() — after squad units, before player leader
let enemy_entities: Vec<_> = game.world.get_entities_with::<Team>()
    .into_iter()
    .filter(|e| {
        game.world.get_component::<Team>(*e)
            .map(|t| *t == Team::Enemy)
            .unwrap_or(false)
    })
    .collect();

for entity in enemy_entities {
    if let Some(pos) = game.world.get_component::<Position>(entity) {
        let px = offset_x + pos.x * 20.0;
        let py = offset_y + pos.y * 20.0;

        // Enemy body (distinct color from player units)
        sprites.push(RenderSprite::new(px, py, 16.0, 16.0)
            .with_color(0.7, 0.1, 0.6, 1.0)  // purple/magenta
            .with_layer(10));
        // Red border
        sprites.push(RenderSprite::new(px, py, 18.0, 18.0)
            .with_color(0.9, 0.1, 0.1, 0.4)
            .with_layer(9));

        // Health bar (same pattern as squad)
        if let Some(hp) = game.world.get_component::<Health>(entity) {
            let hp_pct = hp.current as f32 / hp.max as f32;
            let bar_w = 20.0;
            let bar_h = 3.0;
            let bar_x = px - bar_w / 2.0;
            let bar_y = py - 14.0;
            sprites.push(RenderSprite::new(bar_x + bar_w / 2.0, bar_y, bar_w, bar_h)
                .with_color(0.2, 0.2, 0.2, 1.0)
                .with_layer(15));
            let fill_color = if hp_pct > 0.5 {
                [0.9, 0.2, 0.2, 1.0]
            } else if hp_pct > 0.25 {
                [0.9, 0.5, 0.2, 1.0]
            } else {
                [0.9, 0.1, 0.1, 1.0]
            };
            sprites.push(RenderSprite::new(
                bar_x + (bar_w * hp_pct) / 2.0, bar_y, bar_w * hp_pct, bar_h)
                .with_color(fill_color[0], fill_color[1], fill_color[2], fill_color[3])
                .with_layer(16));
        }
    }
}
```

**Key:** Filter by `Team::Enemy` component. Enemies are spawned by `GameSimulation::spawn_encounter_enemies()` with `Team::Enemy` and `EncounterEnemy` marker components.

## Fix 2: Camera Follows Squad Center

Without camera follow, the player pans manually and loses track of units during combat.

```rust
// In update(), after game.tick()
let mut squad_center = [0.0_f32; 2];
let mut squad_count = 0;
for entity in &game.squad_entities {
    if let Some(pos) = game.world.get_component::<Position>(*entity) {
        squad_center[0] += pos.x * 20.0 - map_offset_x;
        squad_center[1] += pos.y * 20.0 - map_offset_y;
        squad_count += 1;
    }
}
if squad_count > 0 {
    let inv = 1.0 / squad_count as f32;
    squad_center[0] *= inv;
    squad_center[1] *= inv;
    // Smooth follow — lerp toward squad center
    let follow_speed = 3.0 * dt;
    self.camera.position[0] += (squad_center[0] - self.camera.position[0]) * follow_speed;
    self.camera.position[1] += (squad_center[1] - self.camera.position[1]) * follow_speed;
}
```

**Note:** The 20.0 factor converts from game grid units to world render units. The map offset centers the terrain at origin.

## Fix 3: Right-Click on Encounter = Engage

Hovering shows tooltip but clicking did nothing. Right-click on a hovered encounter should move the squad toward it and auto-target enemies.

```rust
if self.input.just_pressed("move_order") && !self.is_selecting {
    // If hovering an encounter, move toward it and prepare to engage
    if let Some(enc_id) = self.hovered_encounter {
        if let Some(enc) = game.encounter_manager.encounters.get(&enc_id) {
            game.order_move([enc.x, enc.y, enc.z]);
            // Auto-target any existing enemies
            let enemies: Vec<_> = game.world.get_entities_with::<Team>()
                .into_iter()
                .filter(|e| {
                    game.world.get_component::<Team>(*e)
                        .map(|t| *t == Team::Enemy)
                        .unwrap_or(false)
                })
                .collect();
            for enemy in enemies {
                for _ in &game.selection.selected_entities.clone() {
                    game.order_attack(enemy);
                }
            }
        }
    } else {
        // Normal move-to-ground
        let game_x = (world_pos[0] - offset_x) / 20.0;
        let game_z = (world_pos[1] - offset_y) / 20.0;
        game.order_move([game_x, 0.0, game_z]);
    }
}
```

**Pattern:** Check `hovered_encounter` before computing ground move. If set, use encounter position as move target. The simulation system handles enemy spawning when squad gets within 15 units.

## Fix 4: Auto-Target Acquisition

Player squad members without a target should automatically acquire the nearest enemy within range.

```rust
// In update(), after game.tick()
let enemies: Vec<_> = game.world.get_entities_with::<Team>()
    .into_iter()
    .filter(|e| {
        game.world.get_component::<Team>(*e)
            .map(|t| *t == Team::Enemy)
            .unwrap_or(false)
    })
    .collect();

for squad_member in &game.squad_entities.clone() {
    let has_target = game.world
        .get_component::<CombatState>(*squad_member)
        .and_then(|cs| cs.target)
        .is_some();

    if !has_target {
        if let Some(spos) = game.world.get_component::<Position>(*squad_member) {
            let mut nearest: Option<(Entity, f32)> = None;
            for enemy in &enemies {
                if let Some(epos) = game.world.get_component::<Position>(*enemy) {
                    let dx = spos.x - epos.x;
                    let dy = spos.y - epos.y;
                    let dist_sq = dx * dx + dy * dy;
                    if dist_sq < 8.0 * 8.0 {  // 8-unit aggro radius
                        let dist = dist_sq.sqrt();
                        match nearest {
                            None => nearest = Some((*enemy, dist)),
                            Some((_, best)) if dist < best => nearest = Some((*enemy, dist)),
                            _ => {}
                        }
                    }
                }
            }
            if let Some((target, _)) = nearest {
                game.order_attack(target);
            }
        }
    }
}
```

**Key:** Clone `squad_entities` before iterating — `order_attack()` mutably borrows `game` which would conflict with iterating `game.squad_entities`.

## How the Simulation System Works

`GameSimulation::tick(game, dt)` runs four subsystems in order:

1. **update_movement** — For each `NavigationAgent` + `Transform`:
   - If `MoveTarget` exists but no path → compute A* path via `Pathfinder`
   - Move toward current waypoint at `speed * dt`
   - Within 0.2 units of waypoint → advance to next
   - Path exhausted → remove `MoveTarget`

2. **update_encounters** — For each active hostile encounter:
   - If squad center within 15 units → spawn enemy entities (reduced stats, `Team::Enemy`)
   - If all spawned enemies dead → complete encounter, award gold/XP

3. **update_ai** — For each enemy with `CombatState`:
   - No target + player within aggro radius → acquire nearest player as target
   - Has target but out of melee range → set `MoveTarget` toward target
   - Combat system handles actual damage when in range

4. **update_progression** — Check XP thresholds:
   - Level = 1 + xp / 100
   - Level up → +1 to all stats, HUD notification

## Editor Launch Path Resolution

The editor's "Launch Engine" button originally tried `Command::new("chronos-game")` which only works if the binary is in `$PATH`. The fix resolves the binary relative to the editor's own executable:

```rust
fn launch_engine(&mut self) {
    let is_engine_source = std::env::current_exe()
        .ok()
        .and_then(|p| p.to_str().map(|s| s.contains("chronos-engine")))
        .unwrap_or(false);

    if is_engine_source {
        let game_binary = std::env::current_exe()
            .ok()
            .and_then(|p| p.parent().map(|d| d.join("chronos-game")))
            .filter(|p| p.exists())
            .or_else(|| {
                // Fallback: try debug/ then release/ relative to exe dir
                std::env::current_exe().ok().and_then(|p| {
                    let d = p.parent()?;
                    let debug = d.join("chronos-game");
                    if debug.exists() { Some(debug) } else {
                        let release = d.parent()?.join("release").join("chronos-game");
                        if release.exists() { Some(release) } else { None }
                    }
                })
            });

        let mut cmd = match game_binary {
            Some(path) => std::process::Command::new(&path),
            None => std::process::Command::new("chronos-game"), // PATH fallback
        };
        match cmd.spawn() { /* ... */ }
    }
}
```

**Pattern:** `std::env::current_exe()` → `parent()` → join binary name → check `exists()`. Fallback to `debug/` and `release/` subdirectories. Final fallback to bare name for `$PATH`.

## cargo test Hang Pitfall

**Symptom:** `cargo test` hangs indefinitely on a wgpu/winit project.

**Root cause:** Integration tests or doc tests spawn windows (winit event loops, wgpu surfaces) which block the test runner. The test process never exits because the window event loop runs forever.

**Fix:** Use `cargo check` for compilation validation instead of `cargo test` when you just need to verify the code compiles:

```bash
# DON'T — hangs on window-spawning tests
cargo test --features "game render chronos-game"

# DO — fast, no execution, verifies compilation
cargo check --bin chronos-game --features "game render chronos-game"
cargo check --bin chronos-editor --features editor
```

**If you need to run tests:** Use `--lib` to skip integration tests, or identify and remove broken window-spawning tests:

```bash
# Run only unit tests (skips integration tests that spawn windows)
cargo test --lib --features "game render chronos-game"

# Or run a specific test
cargo test --lib test_name --features "game render chronos-game"
```

**Prevention:** Don't write tests that create winit windows or wgpu surfaces. Test ECS logic, component systems, and game state in isolation. Windowing code is integration-tested by running the actual binary.

## Verification Checklist

After wiring gameplay simulation, verify:

- [ ] `cargo check --bin chronos-game --features "game render chronos-game"` compiles
- [ ] `cargo check --bin chronos-editor --features editor` compiles
- [ ] Right-click on encounter → squad moves toward it
- [ ] Squad within 15 units of encounter → enemies spawn (purple squares)
- [ ] Enemies move toward squad (chase AI)
- [ ] Combat resolves (health bars decrease, enemies die)
- [ ] Encounter clears → gold/XP awarded, HUD notification
- [ ] Camera follows squad center smoothly
- [ ] Squad auto-targets nearby enemies
- [ ] Game over when all squad members die
