# Standalone Game Binary Pattern — Session 2026-05-30

## Context

Built `chronos-game` — a standalone windowed executable for the Chronos Company RPG, separate from the editor and from the engine library. Uses the existing wgpu renderer and ECS game module.

## Cargo.toml Setup

```toml
# Feature that pulls in everything the game binary needs
chronos-game = ["game", "render", "dep:pollster"]

[[bin]]
name = "chronos-game"
path = "src/bin/chronos-game.rs"
required-features = ["chronos-game"]
```

Note: `pollster` is an optional dependency gated behind `editor` feature by default. The `chronos-game` feature adds it explicitly so the binary can use `pollster::block_on` for async wgpu init.

## Binary Structure

```rust
use chronos_engine::{Camera, InputEvent, InputManager, KeyCode, MouseButton, Position, RenderSprite, Renderer};
use chronos_engine::game::runner::{ChronosCompanyGame, GameConfig, GameMode};

struct GameApp {
    window: Arc<Window>,
    renderer: Option<Renderer>,
    camera: Camera,
    white_texture: Option<wgpu::Texture>,
    white_view: Option<wgpu::TextureView>,
    sampler: Option<wgpu::Sampler>,
    game: Option<ChronosCompanyGame>,
    input: InputManager,
    // ... timing, state
}
```

Key design: all wgpu resources are `Option<T>` so the struct can be constructed before async init completes. `pollster::block_on` is used in `GameApp::new()` to initialize wgpu synchronously.

## Input Binding Pattern

The engine's `InputContext::bind()` returns `Self` (consumes and returns), so bindings must be chained:

```rust
let mut gameplay = InputContext::new("gameplay");
gameplay = gameplay.bind("move_up", Binding::single(InputSource::Key(KeyCode::W)));
gameplay = gameplay.bind("move_down", Binding::single(InputSource::Key(KeyCode::S)));
// ... etc
input.add_context(gameplay);
input.set_context("gameplay");
```

Check action state with `input.pressed("action_name")` (not `is_action_pressed` which doesn't exist).

## winit 0.30 Key Mapping

winit 0.30 uses `winit::keyboard::KeyCode` which is different from the engine's `KeyCode`. Map between them:

```rust
fn winit_to_chronos_key(code: winit::keyboard::KeyCode) -> KeyCode {
    use winit::keyboard::KeyCode as W;
    match code {
        W::KeyW => KeyCode::W,
        W::KeyA => KeyCode::A,
        W::KeyS => KeyCode::S,
        W::KeyD => KeyCode::D,
        // ... full mapping for all used keys
        _ => KeyCode::Space,
    }
}
```

Handle in `WindowEvent::KeyboardInput`:
```rust
WindowEvent::KeyboardInput { event, .. } => {
    if let PhysicalKey::Code(code) = event.physical_key {
        let key = winit_to_chronos_key(code);
        if event.state.is_pressed() {
            input.process_event(&InputEvent::KeyPressed(key));
        } else {
            input.process_event(&InputEvent::KeyReleased(key));
        }
    }
}
```

## Rendering the Game World

The game uses `Position { x, y }` (2D). Scale up for rendering:

```rust
fn gather_sprites(&self) -> Vec<RenderSprite> {
    let mut sprites = Vec::new();
    let cell_size = 20.0;  // visual scale
    let offset_x = -(map_width as f32 * cell_size) / 2.0;
    let offset_y = -(map_height as f32 * cell_size) / 2.0;

    // Terrain grid
    for y in 0..map_height {
        for x in 0..map_width {
            let px = offset_x + x as f32 * cell_size;
            let py = offset_y + y as f32 * cell_size;
            let color = if (x + y) % 2 == 0 { [0.15, 0.18, 0.12, 1.0] }
                        else { [0.12, 0.15, 0.10, 1.0] };
            sprites.push(RenderSprite::new(px, py, cell_size - 1.0, cell_size - 1.0)
                .with_color(color[0], color[1], color[2], color[3]));
        }
    }

    // Squad units
    for entity in &game.squad_entities {
        if let Some(pos) = game.world.get_component::<Position>(*entity) {
            let px = offset_x + pos.x * cell_size;
            let py = offset_y + pos.y * cell_size;
            sprites.push(RenderSprite::new(px, py, 14.0, 14.0)
                .with_color(0.2, 0.6, 1.0, 1.0));
        }
    }

    sprites
}
```

## Camera Controls

- WASD: Pan camera (with momentum/decay for smooth feel)
- Mouse scroll: Zoom in/out, clamped to [0.2, 5.0]
- Camera position tracks world coordinates; sprites are offset by map center

```rust
fn screen_to_world(&self, sx: f32, sy: f32) -> [f32; 2] {
    let size = self.window.inner_size();
    let hw = size.width as f32 / 2.0;
    let hh = size.height as f32 / 2.0;
    let zoom = self.camera.zoom;
    [
        self.camera.position[0] + (sx - hw) / zoom,
        self.camera.position[1] + (sy - hh) / zoom,
    ]
}
```

## Build and Install

```bash
cd /path/to/chronos-engine
cargo build --bin chronos-game --features "chronos-game" --release
cp target/release/chronos-game ~/.local/bin/chronos-game
chmod +x ~/.local/bin/chronos-game
```

Desktop entry (`~/.local/share/applications/chronos-game.desktop`):
```ini
[Desktop Entry]
Name=Chronos Company
Comment=Chronos Company RPG
Exec=/home/synth/.local/bin/chronos-game
Icon=/path/to/engine/icon.png
Type=Application
Terminal=false
Categories=Game;RolePlaying;
Keywords=game;rpg;chronos;company;
StartupNotify=true
```

## Pitfalls

- **Feature name vs binary name:** The feature is `chronos-game`, the binary is also `chronos-game`. Cargo resolves this correctly — `cargo build --bin chronos-game --features chronos-game` works.
- **pollster dependency:** Must be explicitly added via `dep:pollster` in the feature. It's not automatically available just because `render` pulls in wgpu.
- **Renderer::render() takes `&mut [RenderSprite]`:** The method mutates the slice (for GPU upload). Clone if you need to gather sprites while also borrowing renderer fields.
- **InputContext::bind() consumes self:** Must reassign: `gameplay = gameplay.bind(...)` not `gameplay.bind(...)`.
- **winit 0.30 ApplicationHandler:** Use `resumed()`, `window_event()`, `about_to_wait()`. No more `Event::MainEventsCleared` — request redraw in `about_to_wait()`.
