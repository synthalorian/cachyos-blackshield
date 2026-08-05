# Git Rebase Conflict Resolution — Safe Recovery

When `git push` is rejected with "fetch first", the remote has newer commits that conflict with local changes.

## Safe Resolution Protocol

1. **Pull with rebase:**
   ```bash
   git pull origin main --rebase
   ```

2. **If conflicts occur, inspect before resolving:**
   ```bash
   git diff --name-only --diff-filter=U
   ```

3. **NEVER blindly use `git checkout --theirs`** — this accepts remote versions and may revert user-requested changes. The remote may have been pushed by another session or a manual edit.

4. **Instead, inspect the diff:**
   ```bash
   git diff HEAD~1 HEAD -- <conflicted-file>
   ```
   Understand what changed in the remote commit before deciding which version to keep.

5. **Apply targeted fixes:** Use `patch` tool with `mode='replace'` to apply only the needed changes, preserving local fixes.

6. **After rebase --continue, verify before pushing:**
   ```bash
   git diff HEAD~1 HEAD -- <file>
   ```
   Check that user-requested changes are still present. Look for:
   - Scroll indicators re-appearing (if user asked them removed)
   - Copy changes being reverted
   - Animation changes being lost
   - Open-source references being added back or removed incorrectly

7. **If verification fails, abort and reassess:**
   ```bash
   git rebase --abort
   ```
   Then manually apply changes on top of the latest remote.

## Common Rebase Trap

The `--theirs` flag during conflict resolution accepts the REMOTE version. If the remote was pushed by a previous (possibly broken) session, you may be reverting fixes the user explicitly requested. Always verify the final state.

## Session Example (May 2026)

Remote commit `411ea32` had correct changes (Junior restored, skills updated, animations fixed). Local commit `b55b891` had additional fixes (open-source refs, Chronos description, Open Psalm fix). During rebase, `git checkout --theirs` accepted the remote version, which:
- Re-added the scroll indicator (user had asked it removed)
- Reverted specialized skills to old names
- Removed game engines from contact description

The fix was to manually re-apply the local changes after understanding what the remote had.
