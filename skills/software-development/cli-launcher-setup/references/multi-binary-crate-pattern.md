# Multi-Binary Crate Pattern

When a single Rust crate produces multiple standalone binaries (editor, game, CLI tool) from the same codebase:

## Cargo.toml Setup

```toml
[features]
# Base features
game = ["render"]
render = ["wgpu", "winit", "bytemuck", "rand", "tokio", "image"]

# Binary-specific feature bundles
chronos-game = ["game", "render", "dep:pollster"]
editor = ["egui", "egui-wgpu", "egui-winit", "wgpu", "winit", "dep:pollster", "serde", "serde_json"]

[[bin]]
name = "chronos-editor"
path = "src/bin/chronos-editor.rs"
required-features = ["editor"]

[[bin]]
name = "chronos-game"
path = "src/bin/chronos-game.rs"
required-features = ["game", "render", "chronos-game"]

[[bin]]
name = "chronos"
path = "src/bin/chronos-cli.rs"
```

## Build Commands

```bash
# Editor
cargo build --bin chronos-editor --features editor --release
cp target/release/chronos-editor ~/.local/bin/

# Game
cargo build --bin chronos-game --features "chronos-game" --release
cp target/release/chronos-game ~/.local/bin/

# CLI (no features needed)
cargo build --bin chronos --release
cp target/release/chronos ~/.local/bin/
```

## Desktop Entries for All Binaries

Create separate `.desktop` files for each binary:

```bash
# Editor
cat > ~/.local/share/applications/chronos-editor.desktop << 'EOF'
[Desktop Entry]
Name=Chronos Editor
Comment=Chronos Engine Visual Editor
Exec=/home/synth/.local/bin/chronos-editor
Icon=/home/synth/projects/chronos-engine/icon.png
Type=Application
Categories=Development;Game;IDE;
Keywords=game;engine;editor;chronos;
EOF

# Game
cat > ~/.local/share/applications/chronos-game.desktop << 'EOF'
[Desktop Entry]
Name=Chronos Company
Comment=Chronos Company RPG
Exec=/home/synth/.local/bin/chronos-game
Icon=/home/synth/projects/chronos-engine/icon.png
Type=Application
Categories=Game;RolePlaying;
Keywords=game;rpg;chronos;company;
EOF
```

## Key Insight

Feature bundles (`chronos-game`, `editor`) are cleaner than listing individual features on the binary. They:
- Group related deps in one place
- Make build commands shorter
- Prevent "feature not found" errors from typos
- Allow the binary to declare `required-features = ["chronos-game"]` instead of `required-features = ["game", "render", "pollster"]`
