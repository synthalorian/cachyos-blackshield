# Flutter: Recovering from Uncommitted Working Tree Files

## Problem

After multi-session Flutter development, the working tree accumulates untracked files from previous sessions that may be inconsistent with the committed base. Returning to the project and running `flutter analyze` reveals dozens of errors that don't match the user's mental model of "it was working yesterday."

## Diagnosis Pattern

```bash
cd /path/to/project
git status --short | head -30
flutter analyze 2>&1 | grep "error" | wc -l
flutter analyze 2>&1 | grep "error" | head -20
```

**If you see:**
- Many `??` untracked files (25+)
- Many analysis errors (20+)
- Errors in files that reference symbols not present in committed code

**Then:** The working tree is a Frankenstein state — uncommitted files from Session N reference symbols from Session N-1 that were never committed.

## Decision Tree

### Option A: Restore Committed State (Fastest)
When the user says "get it back to working" and the committed base is known-good:

```bash
git stash push -m "WIP: session-$(date +%Y%m%d)"
# Or if no stash wanted:
git clean -fd  # DANGER: deletes untracked files permanently
```

Then verify:
```bash
flutter analyze  # Should show 0 errors
flutter build <platform> --release
```

### Option B: Commit and Fix Forward
When the user wants to preserve the new work:

```bash
git add -A
git commit -m "WIP: checkpoint before fix"
flutter analyze 2>&1 | tee /tmp/analysis.txt
# Now fix errors systematically
```

### Option C: Selective Stash
When some untracked files are good and some are broken:

```bash
# Stash only the broken files
git stash push -m "broken-wip" -- <broken-files>
# Keep the good untracked files
flutter analyze
```

## Session Example: OpenSynth

**Context:** Project had committed base at `bce64a8` (Grid Expansion — working synth). Working tree had 25 untracked files from May 30-31 sessions adding sfizz sample engine integration, retro UI, path resolvers, etc.

**Errors:** 48 analysis errors — `sampleEngineCreate` undefined in `OpenAmpSynthBindings`, missing `keyboard_split_provider.dart`, inconsistent imports.

**Root cause:** `lib/ffi/openamp_synth.dart` (committed) never got the sample engine method patches from the May 30 session. The `lib/ffi/sample_engine.dart` file (untracked) referenced methods that didn't exist in the bindings file.

**Resolution:** Presented user with Option A vs Option B. User chose to restore committed state and rebuild from there.

## Prevention

At the end of every multi-file Flutter session:
```bash
flutter analyze  # Verify 0 errors
git add -A
git commit -m "feat: <what was built>"
```

If context window is exhausted before committing, at minimum:
```bash
git add -A
git stash push -m "session-$(date +%Y%m%d)-wip"
```

This preserves the working state for the next session without leaving a broken working tree.
