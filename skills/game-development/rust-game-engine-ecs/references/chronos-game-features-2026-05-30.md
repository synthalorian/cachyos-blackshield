# Game Binary Feature Integration — Session 2026-05-30

## Context

Adding 5 standard RTS/RPG features to a wgpu-rendered game binary: selection box, encounter tooltips, minimap, sound, and save/load UI. All implemented via colored quads (no texture atlas dependencies).

## Feature 1: Selection Box (Left-Click Drag)

Track drag state in the game app struct:

```rust
struct GameApp {
    // ... existing fields ...
    selection_drag: Option<[f32; 2]>,  // world coords of drag start
    selection_current: [f32; 2],       // current world coords
}
```

Input handling:
```rust
// In WindowEvent::MouseInput
MouseButton::Left => {
    if state.is_pressed() {
        let world = self.screen_to_world(pos.x as f32, pos.y as f32);
        self.selection_drag = Some(world);
        self.selection_current = world;
    } else if let Some(start) = self.selection_drag.take() {
        // Finish selection — call game.selection.finish_box_select()
        if let Some(game) = &mut self.game {
            let min_x = start[0].min(self.selection_current[0]);
            let max_x = start[0].max(self.selection_current[0]);
            let min_y = start[1].min(self.selection_current[1]);
            let max_y = start[1].max(self.selection_current[1]);
            game.selection.finish_box_select(min_x, min_y, max_x, max_y);
        }
    }
}

// In WindowEvent::CursorMoved
if let Some(_) = &self.selection_drag {
    self.selection_current = self.screen_to_world(pos.x as f32, pos.y as f32);
}
```

Render the selection box as a translucent quad:
```rust
if let Some(start) = self.selection_drag {
    let min_x = start[0].min(self.selection_current[0]);
    let max_x = start[0].max(self.selection_current[0]);
    let max_y = start[1].max(self.selection_current[1]);  // Y grows up in world
    let min_y = start[1].min(self.selection_current[1]);
    let cx = (min_x + max_x) / 2.0;
    let cy = (min_y + max_y) / 2.0;
    let w = max_x - min_x;
    let h = max_y - min_y;
    sprites.push(RenderSprite::new(cx, cy, w, h)
        .with_color(0.3, 0.7, 1.0, 0.25)  // translucent blue
        .with_layer(999));  // on top of everything
}
```

## Feature 2: Encounter Tooltips (Hover)

Detect encounter under mouse each frame:
```rust
fn encounter_under_mouse(&self, world_x: f32, world_y: f32) -> Option<u32> {
    let game = self.game.as_ref()?;
    let cell_size = game.config.cell_size;
    for (id, encounter) in &game.encounters.encounters {
        let ex = encounter.x * cell_size * 20.0 - (map_width as f32 * cell_size * 20.0) / 2.0;
        let ey = encounter.y * cell_size * 20.0 - (map_height as f32 * cell_size * 20.0) / 2.0;
        let dx = world_x - ex;
        let dy = world_y - ey;
        if dx * dx + dy * dy < 400.0 {  // 20px radius squared
            return Some(*id);
        }
    }
    None
}
```

Render tooltip as a panel of quads:
```rust
fn render_tooltip(&self, sprites: &mut Vec<RenderSprite>, id: u32, screen_x: f32, screen_y: f32) {
    let game = self.game.as_ref().unwrap();
    let enc = &game.encounters.encounters[&id];
    let panel_w = 180.0;
    let panel_h = 80.0;
    // Background
    sprites.push(RenderSprite::new(screen_x + panel_w/2.0, screen_y - panel_h/2.0, panel_w, panel_h)
        .with_color(0.05, 0.05, 0.08, 0.9)
        .with_layer(1000));
    // Title bar
    sprites.push(RenderSprite::new(screen_x + panel_w/2.0, screen_y - 10.0, panel_w, 20.0)
        .with_color(0.2, 0.15, 0.1, 1.0)
        .with_layer(1001));
    // Pixel-font text rendered as colored dot patterns (see visuals reference)
}
```

## Feature 3: Minimap (Top-Right Corner)

Render scaled-down world in a fixed screen corner:
```rust
fn render_minimap(&self, sprites: &mut Vec<RenderSprite>, vp_w: f32, vp_h: f32) {
    let mm_size = 150.0;
    let mm_x = vp_w - mm_size - 10.0;
    let mm_y = 10.0;
    
    // Background
    sprites.push(RenderSprite::new(mm_x + mm_size/2.0, mm_y + mm_size/2.0, mm_size, mm_size)
        .with_color(0.02, 0.02, 0.04, 0.85)
        .with_layer(900));
    
    let game = self.game.as_ref().unwrap();
    let scale_x = mm_size / (map_width as f32 * cell_size * 20.0);
    let scale_y = mm_size / (map_height as f32 * cell_size * 20.0);
    
    // Terrain dots
    for y in 0..map_height {
        for x in 0..map_width {
            let dot_x = mm_x + x as f32 * scale_x * cell_size * 20.0;
            let dot_y = mm_y + y as f32 * scale_y * cell_size * 20.0;
            let color = terrain_color(game.terrain.grid[y][x].terrain_type);
            sprites.push(RenderSprite::new(dot_x, dot_y, 2.0, 2.0)
                .with_color(color[0], color[1], color[2], 1.0)
                .with_layer(901));
        }
    }
    
    // Unit dots
    for entity in &game.squad_entities {
        if let Some(pos) = game.world.get_component::<Position>(*entity) {
            let dot_x = mm_x + pos.x * scale_x * cell_size * 20.0;
            let dot_y = mm_y + pos.y * scale_y * cell_size * 20.0;
            sprites.push(RenderSprite::new(dot_x, dot_y, 3.0, 3.0)
                .with_color(0.2, 0.8, 0.3, 1.0)
                .with_layer(902));
        }
    }
    
    // Camera rect
    let cam_w = (vp_w / self.camera.zoom) * scale_x;
    let cam_h = (vp_h / self.camera.zoom) * scale_y;
    let cam_x = mm_x + (self.camera.position[0] + map_width as f32 * cell_size * 10.0) * scale_x;
    let cam_y = mm_y + (self.camera.position[1] + map_height as f32 * cell_size * 10.0) * scale_y;
    sprites.push(RenderSprite::new(cam_x, cam_y, cam_w, cam_h)
        .with_color(1.0, 1.0, 1.0, 0.3)
        .with_layer(903));
}
```

## Feature 4: Sound (Ambient + Combat)

Initialize audio engine:
```rust
// In GameApp::new() after renderer init
let audio = AudioEngine::new().ok();  // Option<AudioEngine>
if let Some(ref audio) = audio {
    if let Some(mut music) = audio.create_music_player() {
        let _ = music.play("assets/audio/ambient.ogg", 0.4);
    }
}
```

Combat SFX on encounter trigger:
```rust
// In update(), when checking encounter proximity
if let Some(ref audio) = self.audio {
    if let Some(ref mut sfx) = audio.create_sfx_player() {
        let buffer = audio.load_sound("assets/audio/combat_hit.ogg").ok();
        if let Some(buf) = buffer {
            let _ = sfx.play_cached(&buf, "combat_hit", 0.6);
        }
    }
}
```

**Pitfall:** `AudioEngine::new()` can fail if no audio backend is available. Always wrap in `Option` and use `if let Some(ref audio) = audio` pattern. Don't unwrap — the game should run silently if audio is unavailable.

## Feature 5: Save/Load (F5/F9 + Notification)

Key bindings:
```rust
gameplay = gameplay.bind("quicksave", Binding::single(InputSource::Key(KeyCode::F5)));
gameplay = gameplay.bind("quickload", Binding::single(InputSource::Key(KeyCode::F9)));
```

Action handling:
```rust
if input.pressed("quicksave") {
    if let Some(game) = &mut self.game {
        match game.save_game(0) {
            Ok(_) => self.save_notification = Some(("SAVED", 2.0)),
            Err(e) => self.save_notification = Some(("SAVE FAILED", 2.0)),
        }
    }
}
if input.pressed("quickload") {
    if let Some(game) = &mut self.game {
        match game.load_game(0) {
            Ok(_) => self.save_notification = Some(("LOADED", 2.0)),
            Err(e) => self.save_notification = Some(("LOAD FAILED", 2.0)),
        }
    }
}
```

Notification render:
```rust
// Decay timer in update()
if let Some((ref text, ref mut timer)) = self.save_notification {
    *timer -= dt;
    if *timer <= 0.0 { self.save_notification = None; }
}

// Render in gather_sprites()
if let Some((text, timer)) = &self.save_notification {
    let alpha = (timer / 2.0).min(1.0);
    let notif_w = 120.0;
    let notif_h = 30.0;
    let notif_x = vp_w / 2.0;
    let notif_y = vp_h - 40.0;
    sprites.push(RenderSprite::new(notif_x, notif_y, notif_w, notif_h)
        .with_color(0.1, 0.3, 0.2, alpha * 0.9)
        .with_layer(1000));
    // Pixel-font "SAVED" text at (notif_x - 20.0, notif_y)
}
```

## Layer Z-Index Convention

Use consistent layer values to avoid z-fighting:
- 0-100: Terrain tiles
- 100-200: Units, encounters
- 200-300: Health bars, selection indicators
- 500-600: HUD elements (gold, time, squad count)
- 700-800: Minimap
- 900: Selection box
- 1000+: Tooltips, notifications, modal overlays

## Pitfalls

- **Selection box world vs screen coords:** The box must be tracked in WORLD coordinates (not screen), because the camera moves. Convert start/current to screen only at render time.
- **Tooltip screen coords:** Tooltips render at fixed screen positions (not world), so they don't need camera transform. Use the mouse screen position directly.
- **Minimap click-to-pan:** On left-click inside minimap bounds, compute normalized position (0-1) and set camera position to world equivalent.
- **AudioEngine optional:** Always treat audio as optional. The game must run without sound.
- **Save slot 0 convention:** Slot 0 is typically auto-save. For quicksave, use slot 0 or find the first empty slot 1..max.

### Borrow Checker: Mutable Game + Immutable Self Methods

**Problem:** In the `update()` method, you need to mutably borrow `self.game` (to call `game.selection.finish_box_select()`, `game.save_game()`, etc.) AND also call `self.world_to_screen()` (which borrows `self` immutably, including `self.camera`, `self.window_size`, etc.). Rust rejects this because `game` is borrowed from `self`.

**Error pattern:**
```rust
if let Some(game) = &mut self.game {      // mutable borrow of self.game starts
    game.selection.finish_box_select(...); // uses mutable borrow
    for id in &game.encounter_manager.active_encounters {
        if let Some(enc) = game.encounter_manager.encounters.get(id) {
            let screen_pos = self.world_to_screen(ex, ey); // ERROR: immutable borrow of self
            //                                               while game (from self) is mutably borrowed
        }
    }
}
```

**Solution: Split into separate scopes.** Do all mutable `game` operations first, then drop the mutable borrow and do immutable operations in a second scope:

```rust
// Scope 1: mutable game operations
if let Some(game) = &mut self.game {
    if self.input.just_pressed("select") {
        game.selection.begin_box_select(world_pos[0], world_pos[1]);
    }
    if self.is_selecting {
        game.selection.update_box_select(world_pos[0], world_pos[1]);
    }
    if self.input.just_released("select") && self.is_selecting {
        game.selection.finish_box_select(&mut game.world);
    }
    if self.input.just_pressed("quicksave") {
        let _ = game.save_game(99);
    }
}

// Scope 2: immutable game operations (game borrowed immutably, self accessible)
if let Some(game) = &self.game {
    let mut closest_dist = 30.0;
    for id in &game.encounter_manager.active_encounters {
        if let Some(enc) = game.encounter_manager.encounters.get(id) {
            let ex = offset_x + enc.x * 20.0;
            let ey = offset_y + enc.z * 20.0;
            let screen_pos = self.world_to_screen(ex, ey); // OK: self not mutably borrowed
            // ...
        }
    }
}
```

**Key insight:** The mutable borrow of `self.game` is a reborrow of `&mut self`. Any method on `self` (even immutable) conflicts because the compiler sees it as potentially invalidating the mutable borrow. Splitting scopes is cleaner than trying to extract all data before the mutable borrow.
