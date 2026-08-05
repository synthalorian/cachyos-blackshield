# Wrapper script symlink-resolution pattern

When a bash wrapper script is installed as a symlink (e.g., `~/.local/bin/claw → /real/path/claw`), using `dirname "${BASH_SOURCE[0]}"` returns the symlink's directory, NOT the real script directory. This breaks relative `source` statements.

## Broken pattern

```bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/synthclaw-resolve.sh"  # FAILS: file not found in symlink dir
```

## Fixed pattern — resolve real path through symlinks

```bash
SOURCE="${BASH_SOURCE[0]}"
while [ -L "$SOURCE" ]; do
  DIR="$(cd "$(dirname "$SOURCE")" && pwd)"
  SOURCE="$(readlink "$SOURCE")"
  [[ "$SOURCE" != /* ]] && SOURCE="$DIR/$SOURCE"
done
SCRIPT_DIR="$(cd "$(dirname "$SOURCE")" && pwd)"
source "$SCRIPT_DIR/synthclaw-resolve.sh"
```

## How it works

1. `SOURCE` starts as the invoked path (might be symlink)
2. `while [ -L "$SOURCE" ]`: loop while `SOURCE` is a symlink
3. `DIR` = directory containing the current symlink
4. `SOURCE` = target of `readlink` (might be relative)
5. If target is relative (`[[ "$SOURCE" != /* ]]`), prepend the symlink's directory to make it absolute
6. Loop again — the new `SOURCE` might itself be another symlink (chained symlinks)
7. When `SOURCE` is no longer a symlink, `SCRIPT_DIR` is its directory — the real script location

## Verification

Add debug output before the `source` line:
```bash
echo "SCRIPT_DIR=$SCRIPT_DIR" >&2
echo "Looking for: $SCRIPT_DIR/synthclaw-resolve.sh" >&2
```

Test with `bash -x /path/to/wrapper 35b` and verify the resolved path is the actual wrapper directory, not the symlink's parent.

## Applied to this session

File: `/home/synth/synthclaw-ai-setup/configs/wrappers/claw`
Symlink: `~/.local/bin/claw → /home/synth/synthclaw-ai-setup/configs/wrappers/claw`

Before fix: `SCRIPT_DIR=/home/synth/.local/bin` → `source` failed → `resolve_model` undefined → model ID fell back to default short name (`synthclaw-35b`).
After fix: `SCRIPT_DIR=/home/synth/synthclaw-ai-setup/configs/wrappers` → `source` succeeds → full model ID resolved (`synthclaw-35b-128k`).
