---
name: bevy-3d-visualization
description: Build 3D data visualizations in Bevy 0.15 — procedural generation, custom meshes, LOD, data pipeline architecture, and API quirks discovered on this machine.
trigger: Bevy 0.15, 3D visualization, city generation, procedural mesh, data-to-scene pipeline, RetroSpec
---

# Bevy 3D Visualization

Class-level umbrella for building 3D data visualizations in Bevy 0.15 on Linux (Arch/Hyprland, AMD Vulkan). Covers architectural patterns, API quirks, and procedural generation techniques used in RetroSpec (git history → 3D city).

## Architecture Pattern: Pipeline-to-Render

The reusable pattern from RetroSpec:

```
CLI args → Git DAG parsing → CityPlan (data model) → CityMeshes (mesh data) → Bevy entity spawning
            │                    │                        │
       src/cli.rs           src/city/planner.rs      src/city/builder.rs    src/render/*.rs
```

Key insight: the **plan → builder → render** separation keeps data logic, mesh conversion, and Bevy entity spawning independent. Planner works on plain structs (no Bevy deps). Builder converts to mesh-friendly structs. Render handles Bevy systems.

### Pipeline Layers

1. **Data layer** (`planner.rs`) — Pure functions, no Bevy. Takes parsed data, returns layout structs. Unit-testable.
2. **Mesh layer** (`builder.rs`) — Converts layout structs to mesh-friendly vecs. No Bevy deps beyond primitive types.
3. **Render layer** (`render/*.rs`) — Pure Bevy. Spawns entities from mesh data, runs per-frame systems (LOD, animation).

## Bevy 0.15 API Quirks on This Machine

### Custom Mesh Creation
To create a mesh from raw vertex data (e.g. for optimized grid lines):

```rust
use bevy::prelude::*;
use bevy::render::mesh::{Indices, PrimitiveTopology};

let mut mesh = Mesh::new(PrimitiveTopology::TriangleList, Default::default());
mesh.insert_attribute(Mesh::ATTRIBUTE_POSITION, positions);
mesh.insert_attribute(Mesh::ATTRIBUTE_NORMAL, normals);
mesh.insert_attribute(Mesh::ATTRIBUTE_UV_0, uvs);
mesh.insert_indices(Indices::U32(indices));
```

### Procedural Image/Texture Generation
`Image` is from `bevy_image` (re-exported through prelude). `TextureFormat`, `TextureDimension`, `Extent3d` are **not** in `bevy::render::texture` — they're in `bevy::render::render_resource`:

```rust
use bevy::render::render_asset::RenderAssetUsages;
use bevy::render::render_resource::{Extent3d, TextureDimension, TextureFormat};

Image::new(
    Extent3d { width: 64, height: 128, depth_or_array_layers: 1 },
    TextureDimension::D2,
    pixel_data,   // Vec<u8>, RGBA8
    TextureFormat::Rgba8UnormSrgb,
    RenderAssetUsages::MAIN_WORLD | RenderAssetUsages::RENDER_WORLD,
)
```

### Screenshot Capture
`ScreenshotPlugin` / `ScreenshotManager` does **not exist** in Bevy 0.15. Use OS-level tool fallback instead:

```rust
std::process::Command::new("sh")
    .arg("-c")
    .arg(format!("grim \"{}\" 2>/dev/null || scrot \"{}\" 2>/dev/null || import -window root \"{}\"", path, path, path))
    .output();
```

Requires `grim` (Wayland/Hyprland), `scrot` (X11), or ImageMagick `import` installed.

### LOD via Visibility
Simple distance-based LOD: query `(&GlobalTransform, &mut Visibility)` and set `Visibility::Hidden` beyond a threshold. Bevy's frustum culling handles mid-range. No need for full material-swapping LOD for most visualizations.

```rust
pub fn apply_lod(
    camera: Query<&GlobalTransform, With<Camera3d>>,
    mut buildings: Query<(&GlobalTransform, &mut Visibility), With<Building>>,
) {
    let cam_pos = camera.single().translation();
    for (transform, mut visibility) in &mut buildings {
        *visibility = if transform.translation().distance(cam_pos) > 200.0 {
            Visibility::Hidden
        } else {
            Visibility::Visible
        };
    }
}
```

### Image Asset Access Pattern
To generate images at spawn time, pass `ResMut<Assets<Image>>` as a system parameter and use `images.add(your_image)`. Store handles in a `HashMap<u32, Handle<Image>>` for cache dedup.

```rust
fn setup_scene(
    mut commands: Commands,
    mut meshes: ResMut<Assets<Mesh>>,
    mut materials: ResMut<Assets<StandardMaterial>>,
    mut images: ResMut<Assets<Image>>,
) { ... }
```

## Procedural Generation Patterns

### Window Grid Textures
- 64×128 RGBA texture, 4 cols × 8 rows of 16×16 cells
- 2px walls, 14px window per cell
- Seeded by commit hash (DJB2) for reproducibility
- Window lit probability: ~45% normal, ~65% tagged commits
- Lit windows: warm yellow (200-255 R, 160-220 G, 60-120 B)
- Dark windows: deep blue (12, 18, 45)
- Wall color: building color × 0.31 (80/255)

### Merged Grid Mesh
For grid lines, generate a single `TriangleList` mesh instead of individual entities:
- Each line = 4 vertices (thin quad) + 6 indices (two triangles)
- Batch all X-lines and Z-lines into one vertex/index buffer
- Single draw call vs ~200 individual entities

### Rotating Beacons
- Spawn as separate entity with `TagBeacon { rotate_speed }` component
- Per-frame system: `transform.rotate_y(speed * dt)`
- Colored unlit material + emissive for glow
- Small `PointLight` at same position for actual light

## Theme System Pattern

The `Theme` struct holds all visual parameters (sky colors, grid/ground/base colors, emissive, accent, ambient light/brightness). Wired through `setup_scene` → `setup_lighting`.

To add a theme:
1. Create `src/theme/<name>.rs` returning a `Theme` struct
2. Add to `theme/mod.rs`: module declaration + `get_theme()` match arm + `list_themes()`
3. CLI `--theme <name>` selects it automatically

## Config File Pattern

`retro-spec.toml` loaded from CWD at startup. Merged with CLI args where CLI wins. Simple serde Deserialize approach:

```rust
#[derive(Deserialize, Default)]
pub struct RetroSpecConfig {
    pub theme: Option<String>,
    pub repo: Option<String>,
    // ...
}

pub fn load_config(path: &Path) -> RetroSpecConfig {
    if path.exists() {
        std::fs::read_to_string(path).ok()
            .and_then(|s| toml::from_str(&s).ok())
            .unwrap_or_default()
    } else {
        RetroSpecConfig::default()
    }
}
```

## Blame Heat Map Integration

Pattern: compute per-file change heat from commit data, pass through as a `Resource`, use in building material tinting.

1. In `src/git/blame.rs`, implement `analyze_blame(commits) -> BlameHeatmap`:
   - Per-author: commit count, lines added/deleted
   - Per-file (hotspot): change count → heat 0.0–1.0 (relative to max)
2. Insert `BlameHeatmap` as a Resource in the app
3. Pass `&BlameHeatmap` to `spawn_buildings()`
4. For each building, look up the commit's files, average their heat values
5. Blend red/orange into the building color proportional to heat

```rust
let avg_heat = commit_files.get(b.commit_id.as_str())
    .and_then(|files| {
        let (sum, count) = files.iter()
            .filter_map(|f| file_heat.get(f.as_str()))
            .fold((0.0f32, 0usize), |(s, c), &h| (s + h, c + 1));
        if count > 0 { Some(sum / count as f32) } else { None }
    })
    .unwrap_or(0.0);
let heat_color = Color::srgb(
    color.r() + avg_heat * 0.4,
    color.g() - avg_heat * 0.2,
    color.b() - avg_heat * 0.2,
);
```

## Diff Preview / Pulse Animation

Track the nearest building via a `FocusedBuilding` Resource, then animate its scale:

1. Resource: `FocusedBuilding { commit_id: Option<String> }`
2. HUD system sets `focused.commit_id = Some(commit.id)` when a building is within range
3. Per-frame animation system pulses X/Z scale:

```rust
pub fn animate_focused_building(
    time: Res<Time<Virtual>>,
    focused: Res<FocusedBuilding>,
    mut query: Query<(&Building, &mut Transform)>,
) {
    let elapsed = time.elapsed_secs();
    let Some(ref focused_id) = focused.commit_id else { return; };
    for (building, mut transform) in query.iter_mut() {
        if &building.commit_id == focused_id {
            let pulse = 1.0 + (elapsed * 3.0).sin() * 0.03;
            transform.scale = Vec3::new(pulse, 1.0, pulse);
        }
    }
}
```

## CI/CD Output Pattern

Add a `--ci` flag that outputs JSON stats to stdout before any 3D rendering:

```rust
#[arg(long = "ci")]
pub ci: bool,
```

In main(), before Bevy launch:
```rust
if args.ci {
    let json = serde_json::json!({
        "repo": repo_path,
        "commits": dag.commits.len(),
        "authors": author_set.len(),
        "branches": dag.branches.len(),
        "tags": dag.tags.len(),
        "merges": merges,
        "lines_added": total_added,
        "lines_deleted": total_deleted,
    });
    println!("{}", serde_json::to_string_pretty(&json)?);
    if args.screenshot.is_none() { return Ok(()); }
}
```

Pairs with `--screenshot` to render a banner image + stats in one run.

## Procedural Audio Generation

Bevy 0.15's `AudioSource` holds raw file bytes (`bytes: Arc<[u8]>`). To play procedurally-generated audio:

1. **Enable WAV feature** in Cargo.toml: `bevy = { version = "0.15", features = ["wav"] }`
2. **Generate WAV bytes** — write a proper RIFF/WAVE header + 16-bit PCM samples
3. **Create AudioSource** from the bytes and add to Assets
4. **Spawn AudioPlayer** with PlaybackSettings { mode: PlaybackMode::Loop }

```rust
use bevy::audio::{AudioPlayer, AudioSource, PlaybackMode, PlaybackSettings};
use std::sync::Arc;

fn generate_wav(sample_rate: u32, duration_secs: f32) -> Vec<u8> {
    let num_samples = (sample_rate as f32 * duration_secs) as usize;
    let mut samples = vec![0u8; 44 + num_samples * 2];
    // RIFF header, fmt chunk, data chunk, 16-bit PCM samples
    // See audio.rs in retro-spec for full implementation
    samples
}

fn setup_audio(mut commands: Commands, mut audio_assets: ResMut<Assets<AudioSource>>) {
    let wav_bytes = generate_wav(44100, 300.0);
    let source = AudioSource { bytes: wav_bytes.into() };
    let handle = audio_assets.add(source);
    commands.spawn((
        AudioPlayer::new(handle),
        PlaybackSettings { mode: PlaybackMode::Loop, ..default() },
    ));
}
```

WAV format details: RIFF header (12 bytes) + fmt chunk (24 bytes) + data chunk (8 bytes + samples). 16-bit PCM, mono, 44100 Hz.

## Theme Color Palette Convention

The default `synthwave84` theme on this machine uses synth's personal palette:
- BG: #240037 (deep purple)
- Grid: #f3e70f (yellow)
- Accent/Purple: #8f00ff
- Buildings/Streets: #ff7edb (pink)
- Ambient: #ff00ff (magenta)

There is **no separate omarchy theme** — it was merged into synthwave84. Always use `--theme synthwave84` in examples.

## Common Pitfalls

- **Cylinder vs Cone**: Bevy 0.15 has `Cylinder { radius, height }` — use `Cylinder::new(radius, height)` for flat discs or cylinders but NOT for cones (no top-radius parameter). For cones use a custom mesh or approximation.
- **`Torus::new(radius, tube_radius)`** works in Bevy 0.15 — use for ring/glow effects.
- **`Sphere::new(radius).mesh().ico(subdivisions)`** for icosphere meshes.
- **`Plane3d::default().mesh().size(w, h)`** for flat ground planes.
- **Shadows**: On AMD Vulkan, `DirectionalLight` with `shadows_enabled: true` can cause rendering artifacts. Set to `false` if visual glitches appear.
- **AlphaMode::Blend** required for transparent materials (window textures, glass skybridges, particles).
- **Module ordering**: `mod` declarations in `lib.rs`/`main.rs` don't need to match filesystem order, but `pub mod` in `mod.rs` must match the directory contents.