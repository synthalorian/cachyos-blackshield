#!/usr/bin/env bash
# verify-restore.sh — sandboxed verification for an identity restore script.
# Adapt the REPO, paths, and assertions to your repo layout, then run once and delete.
#
# Pattern: override HOME (+ harness-home env vars) to a mktemp dir, pre-seed
# existing files to exercise backup/no-clobber paths, pipe prompt answers,
# assert install + backup + no-clobber, then clean up everything.
set -uo pipefail

REPO="${1:?usage: verify-restore.sh <path-to-identity-repo>}"
FAKE=$(mktemp -d /tmp/verify-restore-home.XXXXXX)
export HOME="$FAKE"
export HERMES_HOME="$FAKE/.hermes"   # restore scripts commonly honor this
mkdir -p "$HERMES_HOME"

# --- Pre-seed existing installs (exercises backup + no-clobber paths) ---
mkdir -p "$FAKE/.config/opencode" "$FAKE/.openclaw/workspace"
echo "OLD-OPENCODE-AGENTS" > "$FAKE/.config/opencode/AGENTS.md"
echo "OLD-OPENCLAW-SOUL"  > "$FAKE/.openclaw/workspace/SOUL.md"
echo "OLD-OPENCLAW-MEMORY" > "$FAKE/.openclaw/workspace/MEMORY.md"

# --- Run restore (answer n to interactive prompts; adjust count as needed) ---
printf 'n\nn\n' | bash "$REPO/restore.sh" > "$FAKE/restore.log" 2>&1
RC=$?

fail=0
check() { # check <desc> <0=pass>
  if [ "$2" -eq 0 ]; then echo "PASS: $1"; else echo "FAIL: $1"; fail=1; fi
}

echo "--- restore.sh exit code: $RC ---"
tail -15 "$FAKE/restore.log"
echo "--- assertions ---"

check "restore.sh exited 0" "$([ $RC -eq 0 ]; echo $?)"

# Install assertions — adjust source paths to your repo layout
diff -q "$REPO/harness/opencode/AGENTS.md" "$FAKE/.config/opencode/AGENTS.md" >/dev/null 2>&1
check "OpenCode AGENTS.md installed from repo" "$?"

diff -q "$REPO/identity/soul/SOUL.md" "$FAKE/.openclaw/workspace/SOUL.md" >/dev/null 2>&1
check "OpenClaw SOUL.md installed from repo" "$?"

diff -q "$REPO/identity/soul/SOUL.md" "$HERMES_HOME/SOUL.md" >/dev/null 2>&1
check "Hermes SOUL.md installed" "$?"

# Backup assertions — old content must exist somewhere under the backup dir
grep -rq "OLD-OPENCODE-AGENTS" "$HERMES_HOME"/.synthclaw-backup-*/ 2>/dev/null
check "Existing OpenCode AGENTS.md backed up" "$?"

grep -rq "OLD-OPENCLAW-SOUL" "$HERMES_HOME"/.synthclaw-backup-*/ 2>/dev/null
check "Existing OpenClaw SOUL.md backed up" "$?"

# No-clobber assertion — harness-maintained knowledge bases must survive
grep -q "OLD-OPENCLAW-MEMORY" "$FAKE/.openclaw/workspace/MEMORY.md" 2>/dev/null
check "OpenClaw MEMORY.md NOT clobbered" "$?"

echo "---"
[ $fail -eq 0 ] && echo "ALL CHECKS PASSED" || echo "SOME CHECKS FAILED"
rm -rf "$FAKE"
exit $fail
