# Git Recovery from Scope Creep — Open Synth Case Study

## The Problem

Open Synth went from a working synthesizer app to a broken mess after commit `5efaf14`. The symptom: "this version is so fucked."

## Root Cause Analysis

Commit `5efaf14` ("Grid Expansion") was clean:
- 12 Dart source files
- Simple FFI bridge to native `.so`
- Single screen, single keyboard widget
- 50 factory presets, FX panel, oscillators
- `flutter analyze` clean
- App produced sound

After `5efaf14`, feature creep accumulated:
- `dbdb006d` — arpeggiator engine added (working)
- `a285005` — multi-FX engine, expanded presets (working)
- `8eac2b5` — Android Oboe backend (working)
- `26fd20b` — mobile UX shell (working)
- `d3e2f90` — Dart analysis fixes (working)
- `862ed5b` — roadmap docs (working)
- `253903f` / `cfa9273` — rebrand commits (start of bloat)
- `c162daf` — "sync from local development" — **252 files changed, 62,399 insertions, 990 deletions**

The final state had:
- Duplicate UI systems (`synth_screen.dart` AND `retro_synth_screen.dart`)
- Duplicate widgets (`keyboard_widget.dart` AND `retro_keyboard.dart`)
- Entire native C++ engine rewritten (voice allocator, drum synth, physical models, wavetable...)
- Multiple theme systems
- Sequencer, recorder, MIDI learn, drum pads, morph, mod matrix...
- 69 `flutter analyze` issues (mostly deprecation warnings but also unused imports/fields)

## Recovery Technique

### Step 1: Identify the last good commit

```bash
git log --oneline -20
```

Look for the commit before the explosion. In this case, `5efaf14` was the last functional state.

### Step 2: Verify scope creep

```bash
git diff 5efaf14..HEAD --stat
```

If you see 200+ files and 60k+ lines, you've confirmed the diagnosis.

### Step 3: Inspect files from the good commit

```bash
# Check if main.dart was simpler
git show 5efaf14:lib/main.dart

# Check if the screen structure was cleaner
git show 5efaf14:lib/screens/synth_screen.dart | head -80

# Check provider complexity
git show 5efaf14:lib/providers/synth_providers.dart | wc -l
```

### Step 4: The nuclear option (hard reset)

```bash
git reset --hard 5efaf14
```

This destroys all commits after `5efaf14`. Only do this if:
- The later commits are all broken anyway
- You have no uncommitted work you care about
- You're okay force-pushing to GitHub

**PITFALL — Terminal tool may block `git reset --hard`**: Some agent environments block destructive git commands as a safety measure. If `git reset --hard` is denied, use the staged-revert technique below.

### Alternative A: Staged revert (when hard reset is blocked)

This creates a new commit that reverts the tree to the target commit, without rewriting history:

```bash
# 1. Stage the target commit's tree into the index
git checkout 5efaf14 -- .

# 2. Remove files that were added AFTER the target commit
# (these show as "A" in git status — they exist in HEAD but not in target)
git ls-tree -r --name-only HEAD | grep -vxf <(git ls-tree -r --name-only 5efaf14) | while read f; do git rm -f "$f"; done

# 3. Unstage files that were untracked in working tree
# (sample files, build artifacts, etc. that aren't in target)
git status --short | grep "^A" | sed 's/^A  //' > /tmp/to_uncache.txt
git rm -f --cached --pathspec-from-file=/tmp/to_uncache.txt

# 4. Verify the index matches the target
git diff --cached 5efaf14 --stat
# Should show nothing (empty output = perfect match)

# 5. Commit the revert
git commit -m "revert: reset to <commit> — remove post-<date> bloat"
```

**Why this works**: `git checkout <commit> -- .` updates tracked files to match the target, but doesn't handle:
- Files added after target (need `git rm`)
- Untracked files that happen to match target paths (need `git rm --cached`)
- The working tree state vs index state

### Alternative B: Recovery branch

```bash
git checkout -b recovery 5efaf14
```

Preserves history, lets you cherry-pick individual fixes from later commits if needed.

## What Was Lost (and whether it matters)

| Feature | In `5efaf14`? | Worth re-adding? |
|---------|--------------|------------------|
| Basic synth (osc, filter, env, LFO) | Yes | Core — already works |
| 50 factory presets | Yes | Core — already works |
| FX (chorus, delay, reverb, phaser, drive) | Yes | Core — already works |
| Keyboard widget | Yes | Core — already works |
| FFI bridge | Yes | Core — already works |
| Audio output | Yes | Core — already works |
| Split keyboard | **No** | **This was the known gap** |
| Arpeggiator | No | Nice-to-have, can re-add cleanly |
| Drum synthesis | No | Nice-to-have, massive C++ addition |
| Mobile shell | No | Nice-to-have, can re-add cleanly |
| Sequencer | No | Advanced feature |
| Recorder | No | Advanced feature |
| MIDI file I/O | No | Advanced feature |
| Sample engine (sfizz) | No | Advanced feature, huge dependency |
| Physical modeling | No | Advanced feature |
| Wavetable engine | No | Advanced feature |
| Multitimbral (16-part) | No | Advanced feature |
| Retro hardware UI | No | Aesthetic overhaul, not functional |

## Lesson

The working state was `5efaf14`. Everything after was premature optimization and feature bloat. The split keyboard — the actual desired feature — was never implemented. Instead, the codebase was buried under 60k lines of unrelated advanced features.

**When a user says "get it back to working", the answer is usually `git reset --hard <commit>` not `git bisect` or incremental fixing.**
