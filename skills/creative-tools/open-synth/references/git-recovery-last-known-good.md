# Git Recovery: Finding the Last Known Working State

## Problem

The project has been over-engineered into a broken state. `flutter analyze` shows 48+ errors. The working tree has untracked files from abandoned experiments. The user says "get it back to where it was working."

## Recovery Technique

### Step 1: Identify candidate commits

```bash
cd /path/to/project
git log --oneline -20
```

Look for:
- Commits with descriptive messages about working features
- The last commit BEFORE a massive refactor or "sync" commit
- Commits where the user previously confirmed things worked

### Step 2: Verify preset count (for OpenSynth specifically)

OpenSynth's factory_presets.dart is a good health indicator:

```bash
git show <commit>:lib/data/factory_presets.dart | wc -l
git show <commit>:lib/data/factory_presets.dart | grep -c "SynthPreset("
```

| Commit | Presets | Lines | State |
|--------|---------|-------|-------|
| `5efaf14` | 50 | ~680 | Grid Expansion — stable |
| `dbdb006d` | ~36 | ~500 | Basic synth + arp |
| `a285005` | ~50+ | ~800 | Arp overhaul + FX |
| `c162daf` | 1,453 | 22,817 | "Sync" — FUBAR, 252 files changed |

### Step 3: Inspect key files without checking out

```bash
# Check if main.dart launches the expected screen
git show <commit>:lib/main.dart | head -20

# Check if synth_screen.dart has the keyboard
git show <commit>:lib/screens/synth_screen.dart | grep -c "KeyboardWidget"

# Check if keyboard routes through NoteRouter
git show <commit>:lib/widgets/keyboard_widget.dart | grep "noteRouter"

# Check if PlaybackStateNotifier starts audio
git show <commit>:lib/providers/synth_providers.dart | grep -A5 "_ensureAudioRunning"
```

### Step 4: Check the native binary size

```bash
git show <commit>:native/libopenamp_dart_ffi.so | wc -c
```

- ~295KB = synth engine only (clean, working)
- ~2.9MB = synth + sfizz sample engine (may work if properly integrated)
- ~457KB = partial/incomplete build

### Step 5: Checkout and verify

```bash
git stash  # save current mess
git checkout <commit>
flutter analyze  # should be clean or minimal warnings
git checkout -  # go back to HEAD
git stash pop   # restore mess
```

### Step 6: Hard reset (DESTRUCTIVE)

```bash
# Nuclear option — loses all commits after <commit>
git reset --hard <commit>

# Safer option — create recovery branch
git checkout -b recovery-<date> <commit>
```

## The "c162daf" Trap

Commit `c162daf` ("Sync: update from local development session") has 1,453 presets and appears feature-rich. However:
- It was created by syncing 252 files with 62k lines of changes
- It contains duplicate UI systems (`synth_screen.dart` AND `retro_synth_screen.dart`)
- The native .so is 295KB (no sfizz) but Dart code references sample engine methods
- It was followed by `bce64a8` ("revert: reset to Grid Expansion") — the author themselves reverted it

**Lesson**: A high preset count doesn't mean the build works. Check `git log` for revert commits — they're red flags.

## The "Working Tree Pollution" Problem

When `git status` shows many `??` untracked files:
- They may be from abandoned experiments
- They may conflict with committed files
- They may reference methods that don't exist in the committed code

**Check**: `flutter analyze` — if untracked files cause errors, they're harmful.

**Fix**: Move them out of the project or delete them:
```bash
mkdir ~/open-synth-backup-$(date +%Y%m%d)
git ls-files --others --exclude-standard | xargs -I {} cp --parents {} ~/open-synth-backup-$(date +%Y%m%d)/
git clean -fd  # DANGEROUS — removes all untracked files
```

## Verification Checklist

Before telling the user "it's working", verify:
- [ ] `flutter analyze` shows 0 errors
- [ ] `git show HEAD:lib/main.dart` launches the expected screen
- [ ] Keyboard widget routes through NoteRouter
- [ ] PlaybackStateNotifier starts audio stream
- [ ] Native .so exists and has expected size
- [ ] No untracked files causing analysis errors
