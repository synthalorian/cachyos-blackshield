# Sprite Batch Capacity Overflow

**Date:** 2026-05-31
**Project:** chronos-engine (Rust wgpu-based game engine)
**Symptom:** `thread 'main' panicked at src/render.rs:273:9: Too many sprites for batch capacity`
**Fix:** Increase `SpriteBatch::new()` capacity from 1024 to 8192

## Root Cause

The `SpriteBatch` allocates a fixed-size GPU vertex buffer at initialization time. Every `RenderSprite` submitted to the renderer consumes one slot. With a 40×40 terrain grid (1600 tiles) plus units, encounters, HUD elements, minimap, selection box, and tooltips, the frame easily exceeds 1024 sprites.

## The Panic Site

```rust
// src/render.rs:273
pub fn upload(&self, queue: &Queue, sprites: &mut [RenderSprite]) {
    assert!(
        sprites.len() <= self.capacity,
        "Too many sprites for batch capacity"
    );
    // ...
}
```

The assertion fires during `Renderer::render()` when `gather_sprites()` produces more sprites than the batch was configured to hold.

## Fix

In `Renderer::new()` where the batch is created:

```rust
// BEFORE (too small for any real scene)
let sprite_batch = SpriteBatch::new(&device, 1024);

// AFTER (handles 40×40 terrain + entities + HUD + minimap comfortably)
let sprite_batch = SpriteBatch::new(&device, 8192);
```

## How to Estimate Required Capacity

For a tile-based game:
- Terrain tiles: `map_width × map_height`
- Units: `squad_size + enemies + NPCs` (~10-50)
- Encounters: ~10-20 each with 2 sprites (ring + core)
- HUD: background bars (~2) + text characters (~5 chars × 20 strings = 100 sprites)
- Minimap: terrain subsample (~400) + dots (~10) + camera rect (4)
- Selection box: fill (1) + borders (4)
- Tooltips: background (2) + text (~30 chars)

**Rule of thumb:** `terrain_tiles × 1.5` as minimum. For 40×40 = 1600 tiles, use at least 4096. Use 8192 or 16384 for safety with larger maps or more effects.

## Prevention

1. **Make capacity configurable** — pass it as a parameter to `Renderer::new()` rather than hardcoding:
   ```rust
   pub async fn new(window: Arc<Window>, width: u32, height: u32, max_sprites: usize) -> Result<Self, String>
   ```

2. **Add a debug warning** — log when sprite count exceeds 80% of capacity:
   ```rust
   if sprites.len() > self.capacity * 8 / 10 {
       eprintln!("[Renderer] Warning: sprite count {}/{} approaching batch limit", sprites.len(), self.capacity);
   }
   ```

3. **Consider dynamic resizing** — recreate the buffer when capacity is exceeded (more complex, requires device queue access).

## Related

- `references/chronos-game-features-2026-05-30.md` — Features that increased sprite count (minimap, selection box, tooltips)
- `references/chronos-game-visuals-2026-05-30.md` — How sprites are generated per feature
