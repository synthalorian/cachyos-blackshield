# CURRENT STATE — v2.0.0 (2026-07-25), READ FIRST

The project pivoted from Flutter/FFI to a native **JUCE 8 + C++20** app. v2.0.0 is tagged and released (Standalone + VST3 + CLAP, Linux x86_64, with CC0 sample bundles). The legacy Flutter `lib/`, `native/`, PortAudio/Oboe FFI sources, and `native/oboe` stale gitlink are DELETED. Older sections of SKILL.md describing the Flutter architecture are historical — trust the repo, not those sections.

Key facts (v2.0.0):
- Repo: ~/Projects/active/open-synth, branch master. Tags: v0.1.0-alpha, v0.2.1-audio-fix, v1.1.0 (Flutter era), v2.0.0 (C++ rewrite).
- JUCE resolution in CMakeLists: `-DJUCE_DIR` > `$JUCE_DIR` env > `libs/JUCE` submodule > `~/.juce`.
- Sample submodules (7) under samples/ — MUST `git submodule update --init --recursive` after clone or sample presets are silent.
- Sample manifests support BOTH multi-layer and flat formats; paths resolve by walking up 4 dirs from the manifest. Plugin manifest lookup: exe dir → exe parent → `~/.config/OpenSynth/samples/manifests` → CWD.
- MIDI: CC 123 releases synth + sample voices; CC 120 `allSoundOff()` instant-kills (SamplePlayer/SynthEngine/wrapper all have it).
- Tests (build/): `sample_load_test ../samples` (83 decode), `sample_player_block_test ../samples` (ADSR/pitch bend — uses allSoundOff for isolation), `sample_static_test ../samples/manifests/<name>.json` (8 manifests, 1,419 zones), `fx_tests` (1,021 assertions). All test targets need JUCE_USE_FLAC=1.
- Warnings: generated include/preset_library_full.h (5,600 presets, scripts/generate_preset_library.py) carries GCC diagnostic pragmas — keep them when regenerating. Zero non-conversion warnings tolerated pre-release.
- Versioning: CMake project version = 2.0.0 (v1.x = Flutter era; never tag 1.x again).
- Release artifacts: tarballs of Standalone/VST3/CLAP artefact dirs (~405M each, samples included via CMake POST_BUILD copy).

## The "static behind the piano" saga (2026-07-25, commit 6a148d0, post-v2.0.0)

User heard serious static under the (otherwise perfect) sampled piano. Root-caused with a purpose-built headless harness (`tests/engine_render_test`, wired in CMake): renders the full engine (preset + samples + FX) to /tmp/engine_render_piano.wav, prints 100ms RMS/peak buckets, layer-isolation modes (`synth`/`sample`/`synthdry`/`sine`/`both`). Diagnosis flow: layer isolation → RMS==peak means hard-clipped square → gdb conditional break on `leftOut > 100` → filter state inspection.

THREE compounding bugs:
1. **Chamberlin SVF instability** (dsp/filter.cpp): unstable above sr/6 (8kHz @ 48k). Piano cutoff 12kHz → f=1.414 → filter state railed to ±thousands (input was 0.22!) → square-wave noise. FIXED with TPT/Zavalishin SVF (stable to Nyquist). The old "clamp f to 1.95 for stability" comment was dangerously wrong — Chamberlin dies well below 1.95.
2. **Envelope params never reached voices** (dsp/synth_engine.cpp): `noteOn` didn't copy part envelope into `voice->ampEnv` → every voice used default sustain 0.8 → eternal drone under decaying samples. FIXED by syncing all 3 envelopes (amp/filter/pitch + curves) from `parts_[voice->partIndex]` every block (covers direct/arp/queue paths + live edits).
3. **Zero mix headroom**: 8 voices × ±1 raw into tanh. FIXED with 1/sqrt(N) poly scaling + 0.85 sample-layer trim.

Plus generator fix (scripts/generate_preset_library.py): acoustic decaying instruments (piano/upright/guitars/basses) had pad envelopes (sustain 0.6-0.7) that droned under samples; now sustain 0-0.15, natural decays (piano 2400ms). Regenerate with `python3 scripts/generate_preset_library.py` after editing.

Debug techniques that worked: RMS/peak ratio ≈1.0 = hard clip; `tanh(1.0)=0.7616` as a clipping signature; JUCE `createWriterFor` takes stream ownership (double-free trap); gdb `-x` scripts with conditional breakpoints beat printf archaeology; RelWithDebInfo still optimizes out locals — use Debug (-O0) for gdb inspection.

## Post-2.0.1 additions (2026-07-25)

- **Performance mode** (commit 81f47c7): Split (lower zone → part 1 auto-Karplus-bass; samples stay on part 0), Layer (part 1 mirrors part 0 per block ±8 cents detune — Juno Dual), Transpose ±12. RoutedNote[128] table so noteOff releases exact routed notes/parts (no stuck notes on mid-hold changes). APVTS: perfSplitEnabled/perfSplitPoint/perfLayerEnabled/perfTranspose; Split toggle in PerformancePanel.
- **scripts/install_local.sh**: freedesktop install (binary+samples+icon+desktop entry, KDE cache refresh).
- **CI** (.github/workflows/build.yml): Linux/Windows/macOS builds + fx_tests on every push; tag builds also fetch sample submodules and attach artifacts to the GitHub release. Gotchas solved: JUCE is NOT a submodule (CI clones pinned 8.0.12, passes -DJUCE_DIR); clap-juce-extensions needs --recursive (nested clap-libs); MSVC needs _USE_MATH_DEFINES+NOMINMAX (in CMakeLists); std::tanhf isn't standard (use std::tanh); DrumKitPreset fwd-decl must live INSIDE namespace opensynth or MSVC link fails; Windows CI has no zip (use Compress-Archive/pwsh); multi-config generators put test exes in build/Release/.
