# Bevy 0.15 API Reference

API quirks and patterns discovered during RetroSpec development on Arch Linux (Hyprland, AMD Vulkan).

## Mesh Primitives Available

| Primitive | Constructor | Use Case |
|-----------|-------------|----------|
| `Cuboid` | `Cuboid::from_size(Vec3)` | Buildings, boxes |
| `Cylinder` | `Cylinder::new(radius, height)` | Discs, columns, beacons |
| `Torus` | `Torus::new(major_radius, minor_radius)` | Glow rings, merge plazas |
| `Sphere` | `Sphere::new(radius).mesh().ico(n)` | Particles, glowing orbs |
| `Plane3d` | `Plane3d::default().mesh().size(w, h)` | Ground, district tints |
| `Circle` | 2D only — use Cylinder for 3D discs | N/A in 3D |

## Material Patterns

| Effect | Configuration |
|--------|---------------|
| Unlit glow | `unlit: true` + `emissive` set |
| Transparent | `alpha_mode: AlphaMode::Blend` |
| Textured | `base_color_texture: Some(handle)` + `base_color: white` |
| Emissive texture | `emissive` as LinearRgba (not per-texture — use base_color_texture + emissive tint) |

## Accessing Assets in Systems

To create assets at runtime (not in Startup):

```rust
fn my_system(
    mut meshes: ResMut<Assets<Mesh>>,
    mut materials: ResMut<Assets<StandardMaterial>>,
    mut images: ResMut<Assets<Image>>,
) {
    // images.add(...) works
    // meshes.add(...) works
}
```

The `Assets<T>` resource lives in the main world during app building and in the render world during rendering. Add during `Startup` or `Update` systems with `ResMut`.

## Common Type Locations

| Type | Path |
|------|------|
| `Image` | `bevy::prelude::*` or `bevy::image::Image` |
| `Extent3d` | `bevy::render::render_resource::Extent3d` |
| `TextureDimension` | `bevy::render::render_resource::TextureDimension` |
| `TextureFormat` | `bevy::render::render_resource::TextureFormat` |
| `RenderAssetUsages` | `bevy::render::render_asset::RenderAssetUsages` |
| `Indices` | `bevy::render::mesh::Indices` |
| `PrimitiveTopology` | `bevy::render::mesh::PrimitiveTopology` |
| `ScreenshotPlugin` | **Does not exist** in Bevy 0.15 — use OS fallback |

## Window Setup

```rust
app.add_plugins(DefaultPlugins.set(WindowPlugin {
    primary_window: Some(Window {
        title: "App Title".to_string(),
        resolution: WindowResolution::new(1920.0, 1080.0),
        ..Default::default()
    }),
    ..Default::default()
}));
```
