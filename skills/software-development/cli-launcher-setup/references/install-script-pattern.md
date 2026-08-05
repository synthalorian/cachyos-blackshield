# Install Script Pattern

For TUI/CLI apps that need to work from anywhere. The install script:
1. Checks dependencies (cmake, g++, sqlite3, etc.)
2. Builds the project (cmake --build)
3. Creates a wrapper script at ~/.local/bin/<command>
4. The wrapper sets CWD to project root so data/ directories are found
5. Checks that ~/.local/bin is in PATH, warns if not

Full example from Open Psalm v1.0.0:

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BIN_DIR="${HOME}/.local/bin"
BINARY="${SCRIPT_DIR}/build/open-psalm"
WRAPPER="${BIN_DIR}/open-psalm"

# Check deps
echo "→ Checking dependencies..."
for cmd in cmake g++ sqlite3; do
    command -v "$cmd" &>/dev/null && echo "  ✓ $cmd" || MISSING+=" $cmd"
done
[ -n "$MISSING" ] && echo "Missing:$MISSING" && exit 1

# Build
echo "→ Building..."
cd "$SCRIPT_DIR" && mkdir -p build && cd build
cmake .. -DCMAKE_BUILD_TYPE=Release
make -j"$(nproc)"

# Install wrapper to PATH
echo "→ Installing 'open-psalm' command..."
mkdir -p "$BIN_DIR"
cat > "$WRAPPER" << 'WRAPPER_EOF'
#!/usr/bin/env bash
PROJECT_DIR="PLACEHOLDER"
BINARY="$PROJECT_DIR/build/open-psalm"
[ -f "$BINARY" ] && cd "$PROJECT_DIR" && exec "$BINARY" "$@"
echo "Binary not found. Re-run install.sh from the project directory."
exit 1
WRAPPER_EOF
sed -i "s|PLACEHOLDER|$SCRIPT_DIR|" "$WRAPPER"
chmod +x "$WRAPPER"
echo "  ✓ Installed. Type 'open-psalm' to begin."
```

Key: use `sed` to replace a PLACEHOLDER with the actual install path, since
the wrapper can't use `$SCRIPT_DIR` dynamically (it resolves at write time).
