# PCM Sample Engine Research for OpenSynth

## Research Date: 2026-05-30

## The Problem

OpenSynth uses pure synthesis (wavetables, physical modeling, subtractive) for all sounds. The Roland Juno-Di uses PCM samples (1000+ recorded waveforms). For acoustic instruments (piano, strings, brass, drums), synthesis can only approximate — never truly match — sampled instruments.

## Candidate Engines Evaluated

| Engine | License | Stars | Size | Lang | Verdict |
|--------|---------|-------|------|------|---------|
| **sfizz** | BSD-2 | 517 | ~22MB src | C++17 | **Recommended** — full SFZ support, disk streaming, embeddable |
| **FluidSynth** | LGPL-2.1 | 2,386 | ~12MB src | C | Rejected — GLib dependency too heavy for mobile, LGPL complicates static linking |
| **dr_libs** | Public Domain | 1,746 | ~6MB src | C | Building block only — just decoders, no playback engine |
| **Custom** | Any | N/A | ~100KB | C++ | Viable but months of dev for worse result than sfizz |

## Detailed Analysis

### sfizz (Recommended)

- **Repository**: https://github.com/sfztools/sfizz
- **License**: BSD 2-Clause — fully permissive, static link OK, commercial use OK
- **Features**: Full SFZ v1/v2/opcodes (200+), disk streaming, high-quality resampling, envelope/LFO/filter system
- **Dependencies**: abseil-cpp, pugixml (both statically linkable)
- **Binary size**: ~15-30MB with all features (acceptable for serious music app)
- **Integration**: Designed for embedding — core `libsfizz` built as static library
- **Mobile**: Cross-platform including iOS/Android

### FluidSynth (Rejected)

- **Repository**: https://github.com/FluidSynth/fluidsynth
- **License**: LGPL 2.1+ — requires dynamic linking or source disclosure
- **Critical flaw**: Requires GLib (GNOME utility library) — very heavy for mobile
- **Format**: SoundFont2 only (declining format, less flexible than SFZ)

### dr_libs (Building Block)

- **Repository**: https://github.com/mackron/dr_libs
- **License**: Public Domain / Unlicense — zero restrictions
- **Scope**: Single-header decoders (WAV, FLAC, MP3, Ogg)
- **Use case**: Would need custom resampler, voice manager, envelope system built on top

## Free Sample Libraries Available

| Library | Format | Size | License | Quality | Recommendation |
|---------|--------|------|---------|---------|----------------|
| **VSCO 2 Community Edition** | SFZ | ~1.5GB | CC0 (public domain) | Good orchestra | **Ship this** |
| **Virtual Playing Orchestra** | SFZ | ~3GB | CC BY-SA 4.0 | Better orchestra | Attribution required |
| **Freepats General MIDI** | SFZ/SoundFont | ~200MB | GPL/LGPL | Decent GM set | License concerns |
| **Versilian Upright Piano** | SFZ | ~500MB | CC0 | Good upright | **Ship this** |
| **FluidR3** | SoundFont | ~140MB | MIT | Popular GM set | Good fallback |
| **GeneralUser GS** | SoundFont | ~30MB | Freeware | Roland GS compat | Not open source |

## Recommended Architecture

```
SynthEngine (existing)
├── Subtractive osc ──┐
├── Wavetable osc ────┼──> VoiceAllocator ──> Effects ──> Output
├── Physical model ───┤
└── SampleEngine (NEW)┘
      └── sfizz::Synth instance
            └── SFZ file + WAV samples
```

## Integration Strategy

1. **Vendored submodule**: `native/sfizz/` — same pattern as Oboe
2. **CMake**: `add_subdirectory(native/sfizz)` to build static lib
3. **Wrapper**: `SampleEngine` C++ class owning `sfizz::Synth`
4. **ParamQueue**: Sample params through existing lock-free queue
5. **FFI**: New exports for SFZ loading, note control
6. **Dart**: SFZ preset browser, instrument loader UI

## Memory Strategy for Mobile

- sfizz supports **disk streaming** with configurable buffer size
- Only ~50-100MB RAM needed even with multi-GB sample libraries
- iOS/Android typical audio app budget: 100-200MB
- Custom preload for small instruments, streaming for large ones

## Implementation Phases

| Phase | Duration | Work |
|-------|----------|------|
| 1 | Week 1-2 | Add sfizz submodule, CMake integration, `SampleEngine` wrapper |
| 2 | Week 2-3 | FFI exports, Dart bindings, sample preset model |
| 3 | Week 3-4 | Download/package VSCO 2 CE, SFZ mappings, testing |
| 4 | Week 4-5 | Memory optimization, loading UI, error handling |

## Key Technical Decisions

- **SFZ over SoundFont**: SFZ is the modern standard. SoundFont2 is declining.
- **sfizz over custom**: BSD license, 3 months of dev time saved, better quality.
- **Disk streaming over full preload**: Essential for mobile with multi-GB libraries.
- **CC0 samples preferred**: No attribution requirements for shipped product.

## License Summary

| Engine | Commercial | Static Link | Notes |
|--------|------------|-------------|-------|
| sfizz | Yes | Yes | BSD-2, zero legal concerns |
| FluidSynth | Yes | No* | LGPL — must dynamic link or open source |
| dr_libs | Yes | Yes | Public domain |

*LGPL requires source disclosure if statically linked

## Files Referenced

- `INSTRUMENT_REALISM_ROADMAP.md` (project root) — Full instrument realism roadmap
- `references/instrument-realism-vs-juno-di.md` — Synthesis-only improvement path
- `references/split-keyboard-bug-fix.md` — Related audio architecture fix
