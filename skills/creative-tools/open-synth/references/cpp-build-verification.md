# C++ DSP Build Verification Checklist

After ANY code change (Dart OR C++), verify the deployment chain is complete.

## The Three-Step Deployment

```bash
# Step 1: Rebuild native .so
cd /home/synth/projects/open-synth/native/build && cmake .. && make -j$(nproc)

# Step 2: Rebuild Flutter app
cd /home/synth/projects/open-synth && flutter build linux --release

# Step 3: Deploy to bundle + system
bash scripts/deploy-desktop.sh release
pkill -f "open_synth"  # MUST kill first — "Text file busy" on Linux
cp -r build/linux/x64/release/bundle/* ~/.local/share/open_synth/
```

## Verification Commands

### Check binary timestamps
```bash
ls -la ~/.local/share/open_synth/open_synth ~/.local/share/open_synth/lib/libopenamp_dart_ffi.so
```
Both should show timestamps matching the build time.

### Check NaN tracing is in the binary
```bash
strings ~/.local/share/open_synth/lib/libopenamp_dart_ffi.so | grep "OpenSynth NaN"
```
Should output: `[OpenSynth NaN] First NaN at: %s`

### Check unified stream symbols
```bash
nm -D ~/.local/share/open_synth/lib/libopenamp_dart_ffi.so | grep "synth_pair_set_sample"
```
Should show: `synth_pair_set_sample_engine`, `synth_pair_set_sample_volume`

### Check old sample stream is gone
```bash
nm -D ~/.local/share/open_synth/lib/libopenamp_dart_ffi.so | grep "audio_stream_create_for_sample"
```
Should show NOTHING. If `audio_stream_create_for_sample_engine` appears, the old code is still present.

## Common Failures

| Symptom | Cause | Fix |
|---------|-------|-----|
| Binary timestamp is old | `flutter build` didn't rebuild executable | Run `flutter clean` then rebuild |
| `.so` timestamp is old | Forgot `cp native/libopenamp_dart_ffi.so` | Run deploy script |
| No NaN trace in strings | C++ changes didn't compile | Check `make` output for errors |
| Old symbols still present | Stale `.o` files | `cd native/build && rm -rf * && cmake .. && make` |
| "Text file busy" on copy | App is running | `pkill -f open_synth` before copy |
| Walker launches old version | Forgot system install step | `cp -r bundle/* ~/.local/share/open_synth/` |

## Full Clean Rebuild

When in doubt, nuke everything:
```bash
cd /home/synth/projects/open-synth
flutter clean
rm -rf native/build/*
cd native/build && cmake .. -DCMAKE_BUILD_TYPE=Release && make -j$(nproc)
cd /home/synth/projects/open-synth
flutter build linux --release
bash scripts/deploy-desktop.sh release
pkill -f "open_synth"
cp -r build/linux/x64/release/bundle/* ~/.local/share/open_synth/
```
