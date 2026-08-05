# Session Learnings: Recovery to 1,453-Preset Version (May 31, 2026)

## Context

User said "let's try to get opensynth to the point where it was working properly earlier yesterday." The project was at HEAD `1fff4ca` (50-preset rebrand on Grid Expansion base) with a polluted working tree containing broken May 30-31 sample engine files. `flutter analyze` showed 48 errors.

## What We Did

### 1. Git Archaeology

```bash
cd /home/synth/projects/open-synth
git log --oneline -20
git show c162daf:lib/data/factory_presets.dart | grep -c "SynthPreset("
# → 1453 presets
```

Found commit `c162daf` ("Sync: update from local development session") with 1,453 presets. The skill previously misidentified this commit as "FUBAR" — it was actually the working feature-rich version.

### 2. Stash and Checkout

```bash
git stash -u          # save ALL untracked files
git checkout c162daf  # detached HEAD at 1,453-preset version
```

Key: `git stash -u` is essential when working tree has untracked files that conflict with the target commit.

### 3. Fix Analysis Errors

`flutter analyze` showed 3 `non_exhaustive_switch_statement` errors in widgets that switch on `Waveform` enum. The `Waveform` enum had gained new values (`wtBrass`, `wtStrings`, `wtWoodwind`, `wtOrgan`, `wtBell`, `wtSynthBass`, `wtSynthLead`, `wtPad`, `wtEPiano`, `pmKarplus`, `pmKarplusBright`, `pmKarplusBass`, `pmModalMallet`, `pmModalVibraphone`, `pmModalSteel`) but three switch statements weren't updated:

- `lib/widgets/oscilloscope.dart` line 312
- `lib/widgets/spectrum_analyzer.dart` line 167
- `lib/widgets/preset_waveform_preview.dart` line 70

Fix: Add all missing cases to the existing fall-through group before `case Waveform.random:`.

### 4. Build and Deploy

```bash
flutter build linux --release
cp native/libopenamp_dart_ffi.so build/linux/x64/release/bundle/lib/
cp -r build/linux/x64/release/bundle/* ~/.local/share/open_synth/
```

### 5. Launch

Used `bash -c` wrapper to launch in background (terminal tool blocks `&` directly):

```bash
bash -c '~/.local/share/open_synth/open_synth 2> /tmp/synth_run.log &
echo "PID: $!"
sleep 3
ps aux | grep open_synth | grep -v grep'
```

App launched successfully. PID 3889668.

## Key Corrections to Previous Skill Content

1. **Commit `c162daf` is NOT broken** — it works after fixing 3 minor enum exhaustiveness errors. The skill previously labeled it "FUBAR" incorrectly.

2. **Commit `bce64a8` was the actual problem** — "revert: reset to Grid Expansion" threw away 1,453 presets and returned to 50.

3. **Recovery technique**: `git stash -u && git checkout c162daf` is the correct path, NOT `git reset --hard 5efaf14`.

## User Preference Captured

When synth says "get it back to where it was working", he means the 1,453-preset version (`c162daf`), not the minimal 50-preset base. Always ask which version if unclear, or check `git log` for high-preset-count commits.
