# Standalone Game Binary with wgpu Rendering — Visual Features

Pattern for building a visually rich standalone game binary from an existing ECS engine, using only colored quads (no texture atlas needed for basic visuals).

## Feature-Gated Binary

```toml
# Cargo.toml
[features]
game = ["render"]
chronos-game = ["game", "render", "dep:pollster"]

[[bin]]
name = "chronos-game"
path = "src/bin/chronos-game.rs"
required-features = ["game", "render", "chronos-game"]
```

Build: `cargo build --bin chronos-game --features "chronos-game" --release`

## Pixel Font for HUD (No Texture Atlas)

When you need text but don't have a bitmap font atlas set up, use a 5×3 pixel pattern approach:

```rust
const PIXEL_FONT: &[(char, [u8; 15])] = &[
    ('0', [1,1,1, 1,0,1, 1,0,1, 1,0,1, 1,1,1]),
    ('1', [0,1,0, 1,1,0, 0,1,0, 0,1,0, 1,1,1]),
    // ... more digits and letters
];

fn draw_text(sprites: &mut Vec<RenderSprite>, text: &str, x: f32, y: f32, size: f32, color: [f32; 4]) {
    let mut cx = x;
    for ch in text.chars() {
        let upper = ch.to_ascii_uppercase();
        if let Some((_, pattern)) = PIXEL_FONT.iter().find(|(c, _)| *c == upper) {
            for row in 0..5 {
                for col in 0..3 {
                    if pattern[row * 3 + col] == 1 {
                        sprites.push(
                            RenderSprite::new(cx + col as f32 * size, y + row as f32 * size,
                                size - 0.5, size - 0.5)
                            .with_color(color[0], color[1], color[2], color[3])
                            .with_layer(100),
                        );
                    }
                }
            }
            cx += size * 4.0;
        } else {
            cx += size * 4.0;
        }
    }
}
```

Each character is 5 rows × 3 columns of on/off pixels, rendered as tiny colored quads. Layer 100+ keeps HUD above game world.

## Terrain Tile Colors

Map engine terrain types to render colors:

```rust
fn terrain_color(tile: TerrainTile) -> [f32; 4] {
    match tile {
        TerrainTile::Flat => [0.25, 0.45, 0.18, 1.0],   // grass green
        TerrainTile::Hill => [0.55, 0.50, 0.30, 1.0],   // dirt brown
        TerrainTile::Water => [0.20, 0.40, 0.65, 1.0],  // water blue
        TerrainTile::Wall => [0.35, 0.35, 0.35, 1.0],   // stone grey
        TerrainTile::Path => [0.70, 0.60, 0.40, 1.0],   // sand path
    }
}
```

## Unit Class Colors

Give each mercenary class a distinct color:

```rust
fn class_color(template: MercenaryTemplate) -> [f32; 4] {
    match template {
        MercenaryTemplate::Warrior => [0.85, 0.20, 0.20, 1.0],  // red
        MercenaryTemplate::Archer => [0.20, 0.75, 0.30, 1.0],   // green
        MercenaryTemplate::Mage => [0.30, 0.50, 0.95, 1.0],     // blue
        MercenaryTemplate::Scout => [0.90, 0.70, 0.15, 1.0],    // gold
    }
}
```

## Health Bars

Render above each unit with background + fill:

```rust
let hp_pct = hp.current as f32 / hp.max as f32;
let bar_w = 20.0;
let bar_h = 3.0;
// Background
sprites.push(RenderSprite::new(bar_x + bar_w/2.0, bar_y, bar_w, bar_h)
    .with_color(0.2, 0.2, 0.2, 1.0).with_layer(15));
// Fill — color shifts green→yellow→red
let fill_color = if hp_pct > 0.5 { [0.2, 0.9, 0.2, 1.0] }
    else if hp_pct > 0.25 { [0.9, 0.8, 0.2, 1.0] }
    else { [0.9, 0.2, 0.2, 1.0] };
sprites.push(RenderSprite::new(bar_x + (bar_w * hp_pct)/2.0, bar_y, bar_w * hp_pct, bar_h)
    .with_color(fill_color[0], fill_color[1], fill_color[2], fill_color[3])
    .with_layer(16));
```

## Encounter Pulsing Rings

Active encounters get a pulsing outer ring:

```rust
let pulse = (game.state.tick as f32 * 0.05).sin() * 3.0 + 3.0;
sprites.push(RenderSprite::new(px, py, 20.0 + pulse, 20.0 + pulse)
    .with_color(color[0], color[1], color[2], 0.4).with_layer(5));
sprites.push(RenderSprite::new(px, py, 12.0, 12.0)
    .with_color(color[0], color[1], color[2], 1.0).with_layer(6));
```

## Click-to-Move

Right-click anywhere on the map to order squad movement:

```rust
// In update()
if self.input.just_pressed("move_order") {
    let world_pos = self.screen_to_world(self.mouse_screen_pos[0], self.mouse_screen_pos[1]);
    if let Some(game) = &mut self.game {
        let game_x = (world_pos[0] - offset_x) / 20.0;
        let game_z = (world_pos[1] - offset_y) / 20.0;
        game.order_move([game_x, 0.0, game_z]);
    }
}
```

Bind right-click in input context:
```rust
gameplay = gameplay.bind("move_order",
    Binding::single(InputSource::Mouse(MouseButton::Right)));
```

## HUD Layout

Top bar: GOLD | DAY TIME | SQUAD COUNT | REGION | LEVEL
Bottom bar: control hints (WASD: PAN | SCROLL: ZOOM | RCLICK: MOVE)

Use semi-transparent dark backgrounds behind text for readability:
```rust
sprites.push(RenderSprite::new(0.0, hud_y + 25.0, window_w, 50.0)
    .with_color(0.05, 0.05, 0.08, 0.85).with_layer(50));
```
