---
name: rift-asset-pipeline
description: "Rift — cross-engine game asset pipeline manager. Rust CLI + Rails dashboard for converting, validating, and deploying game assets to Unity, Godot, and Unreal."
version: 0.1.0
author: synthalorian
license: Apache-2.0
platforms: [linux]
tags: [game-dev, asset-pipeline, unity, godot, unreal, rust, rails]
---

# Rift — Asset Pipeline Manager

## Location
`~/projects/rift/`

## GitHub
`https://github.com/synthalorian/rift` — public repo, Apache-2.0 license, `main` branch.

## Architecture
- **Rust CLI** (`src/`): Pipeline engine, converters, file watcher, embedded API
- **Rails Hub** (`hub/`): Web dashboard reading `.rift/state.db` directly

## Core Commands
```bash
rift init                    # Scaffold rift.yml for current project
rift run                     # Process all assets (parallel via rayon)
rift watch                   # Watch source dir for changes
rift watch --dashboard       # + API server for Rails Hub on :8910
rift status --assets         # Show DB stats + colorized asset listing
rift completions bash        # Generate shell completions (bash/zsh/fish)

# Install from source
cargo install --path .
```

## Pipeline Config (rift.yml)
```yaml
pipeline:
  name: "game-assets"
  version: 1
source:
  root: "raw-assets"
  watch: true
targets:
  - engine: unity
    project: "Assets/Rift"
    textures: { format: png, max_width: 2048, max_height: 2048 }
    audio: { format: ogg, bitrate: "128k" }
rules:
  - pattern: "**/*.{png,jpg,jpeg,tga,bmp,webp,tiff}"
    convert: textures
  - pattern: "**/*.{wav,mp3,aiff,flac}"
    convert: audio
  - pattern: "**/*.{fbx,gltf,glb,obj,blend}"
    convert: models
    validate: true
```

## Starting Rails Hub
```bash
cd ~/projects/rift/hub
cp ../.rift/state.db .rift/state.db   # sync latest
bin/rails server -p 3001
```

## Key Files
| File | Purpose |
|------|---------|
| `src/main.rs` | CLI dispatch, colored output |
| `src/pipeline/mod.rs` | Runner + Watcher (notify-based, 500ms debounce) |
| `src/converters/texture.rs` | Image resize + format conversion (image crate, Lanczos3) |
| `src/converters/model.rs` | FBX/glTF/OBJ validation (header checks, size limits, required fields) |
| `src/converters/audio.rs` | WAV validation + real OGG Vorbis encoding via ffmpeg subprocess |
| `src/engines/unity.rs` | Unity .meta with SHA256-based stable GUIDs |
| `src/engines/godot.rs` | Godot .import files (texture/audio/scene per-type templates) |
| `src/engines/unreal.rs` | Unreal JSON import settings (per-type configs) |
| `src/db.rs` | SQLite state with Mutex (thread-safe for Axum API sharing) |
| `src/api.rs` | Axum embedded API on :8910 (status, assets, runs, errors endpoints) |
| `hub/app/services/rift_db.rb` | Rails SQLite3 reader (v2.x API — arrays not hashes) |

## Key Design Decisions
- **Parallel processing**: Asset conversion uses `rayon::par_iter()` — fast for large asset sets
- **Progress bars**: Pipeline shows live progress via `indicatif` + `AtomicUsize` counter shared across rayon threads:
  ```rust
  let pb = ProgressBar::new(jobs.len() as u64);
  pb.set_style(ProgressStyle::default_bar()
      .template("{spinner:.cyan} [{elapsed_precise}] [{bar:40.cyan/blue}] {pos}/{len}  {msg}")
      .unwrap()
      .progress_chars("=> "));
  let completed = Arc::new(AtomicUsize::new(0));
  let pb_arc = Arc::new(pb);
  jobs.par_iter().map(|job| {
      pb_arc.set_message(format!("{} — {}", job.relative, convert_type));
      let result = process_asset(&job.path, &job.relative, rule, config);
      let done = completed.fetch_add(1, Ordering::SeqCst) + 1;
      pb_arc.set_position(done as u64);
      result
  }).collect();
  pb_arc.finish_and_clear();
  ```
- **Real OGG encoding**: WAV→OGG conversion uses `ffmpeg -codec:a libvorbis -q:a N` subprocess. No extra Rust deps needed. Bitrate config strings ("128k") map to Vorbis quality levels (0.0–10.0) via `bitrate_to_vorbis_quality()`:
  | Config bitrate | Vorbis quality |
  |---|---|
  | ≤48k | 1.0 |
  | 64k | 2.0 |
  | 96k | 3.0 |
  | 128k | 4.0 |
  | 192k | 6.0 |
  | 256k | 7.0 |
  | 320k | 8.0 |
- **SQLite3 v2.x** returns arrays, not hashes — map to hash in service layer
- **Thread safety**: `Mutex<Connection>` in AssetDb for Rust API server
- **Graceful fallback**: Unsupported image formats (PSD) copy as-is instead of crashing
- **Content-addressed**: SHA256 hash of source → only reconvert when content changes
- **Error resilience**: Per-asset error handling, pipeline continues on failure
- **Shell completions**: `rift completions bash|zsh|fish` generates tab-completion scripts
- **CLI polish**: Colored terminal output via `colored` crate throughout

## Pitfalls

1. **Nested `.git` in `hub/`**: The Rails hub subdirectory may have its own `.git` directory (from a template or initial generation). This breaks `git add -A` in the parent repo with `"hub/ does not have a commit checked out"`. Fix: `rm -rf hub/.git` before initializing or adding to the parent repo. The hub is part of the monorepo, not a submodule.
2. **GitHub repo creation**: If the repo doesn't exist on GitHub yet, use `gh repo create synthalorian/rift --public --source=. --push` from the project directory after initial commit. No need to manually create via web UI.
3. **PLAN.md scrubbing**: The PLAN.md may contain agent-specific instructions (e.g. "For Hermes: Use subagent-driven-development skill"). Remove these before pushing — the public repo should be clean of internal tooling references.

## Test Coverage Patterns

Current 21 tests across converters. Key patterns:

### Audio Tests (8 tests)
- **WAV validation**: valid/empty/bad_channels — create real WAV files via `hound::WavWriter`, verify `validate_wav()` errors
- **OGG encoding**: Write a 1-second WAV, call `encode_wav_to_ogg()` via ffmpeg, assert output has `OggS` magic header
- **Conversion integration**: Test `convert()` with `TargetConfig` pointing to temp dirs
- **Bitrate mapping**: Verify `bitrate_to_vorbis_quality()` returns correct float values

### Model Tests (8 tests)
- **FBX**: ASCII header (`"; FBX..."`) binary header (`"Kaydara FBX..."`), bad header detection, large file warning
- **GLTF**: Valid JSON with `"asset"` field, missing asset field, empty file
- **OBJ**: Valid with vertex data, missing vertices, empty file
- **Blend**: Skip validation (no false positives for complex formats)
- **Test pattern**: Create files with `tempfile::tempdir()`, write content, call validator functions directly

### Texture Tests (3 tests)
- `fit_within()`: no resize, downscale, square — all test the aspect-ratio math

## Rails Dashboard Details

### Routes & Pages
| Route | Controller | Purpose |
|-------|-----------|---------|
| `/` | `DashboardController#index` | Stats cards + recent runs |
| `/assets` | `AssetsController#index` | Asset browser with status filters |
| `/runs` | `PipelineRunsController#index` | Pipeline run history |
| `/errors` | `AssetErrorsController#index` | Error log with type/message/timestamp |

### Auto-refresh
Dashboard auto-refreshes every 15s via `<meta http-equiv="refresh" content="15">` in `content_for :head`. The layout includes `<%= yield :head %>` to inject page-specific meta tags.

### Synthwave84 Theme
Inline CSS in `application.html.erb` with:
- `--neon-pink`, `--neon-cyan`, `--neon-purple`, `--neon-yellow` palette
- Scanline overlay with scroll animation (`scanline-scroll 8s linear infinite`)
- `synth-grid` with repeating diagonal grid lines
- Glass-morphism `.stat-card` and `.card` components
- `JetBrains Mono` for data, `Inter` for body text
- `.badge.ok` / `.badge.pending` / `.badge.error` / `.badge.running` status tags
- `.live-indicator` with pulsing green dot

### Error Page
The `/errors` view displays `asset_errors` table data via `RiftDb.asset_errors(limit: 100)` with columns: type (as badge), asset path, error message, run ID, timestamp.
