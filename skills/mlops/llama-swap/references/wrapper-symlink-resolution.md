# Wrapper Symlink Resolution Pattern (Bash)

When a wrapper script is installed as a symlink (e.g., `~/.local/bin/claw → /repo/wrappers/claw`), using `dirname "${BASH_SOURCE[0]}"` returns the symlink's directory, not the real script directory. This breaks any subsequent `source` of helper files that live alongside the real script.

## Broken pattern (fails when symlinked)

```bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/synthclaw-resolve.sh"   # File not found — wrong dir
```

## Fixed pattern (symlink-aware)

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

This loop resolves the real path even through chains of symlinks. After this, `SCRIPT_DIR` points to the actual script directory, and `source` works correctly.

## Debug tip

Add explicit checks to any wrapper:

```bash
echo "SCRIPT_DIR=$SCRIPT_DIR" >&2
echo "RESOLVED=$(resolve_model 35b)" >&2
```

Run with `bash -x wrapper-name args` to see full trace.

## Real-world example from this session

Both `claw` and `hermes` wrappers in `/home/synth/synthclaw-ai-setup/configs/wrappers/` had this bug. Without the fix, they could not find `synthclaw-resolve.sh`, leaving `resolve_model` undefined and causing model shorthands (`35b`, `27bmax`, etc.) to fall through to incorrect default model IDs (e.g., `synthclaw-35b` instead of `synthclaw-35b-128k`).

Secondary issue: wrapper file had `OPENAI_API_KEY` corrupted to `***`, which claw treats as invalid. Restored to `"llama-swap-local"` sentinel.