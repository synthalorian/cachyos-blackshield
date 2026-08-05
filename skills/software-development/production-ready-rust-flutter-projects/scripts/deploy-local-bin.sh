#!/bin/bash
# ─── Deploy Flutter Desktop Build to ~/.local/bin/ ─────────────────────────
# Usage: ./scripts/deploy-local-bin.sh [--no-systemd]
#
# Copies the just-built Flutter binary + shared libs + runtime data + Rust
# backend into ~/.local/bin/ so launcher shortcuts (Walker, Rofi, dmenu)
# always pick up the latest build without manual copy steps.
#
# Also updates the desktop entry's Exec line to point directly at the binary
# (bypassing any wrapper script — the binary has $ORIGIN/lib RUNPATH baked in).
#
# Handles the "Text file busy" edge case when systemd is managing the backend
# service — stops the service, copies, restarts.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
NO_SYSTEMD="${1:-}"

BUNDLE_DIR="$PROJECT_DIR/build/linux/x64/release/bundle"
BACKEND_SRC="$PROJECT_DIR/backend/target/release/hermes-wingman-backend"

echo "▸ Deploying to ~/.local/bin/..."

mkdir -p "$HOME/.local/bin" "$HOME/.local/bin/lib" "$HOME/.local/bin/data"

# Deploy Flutter binary + shared libs
cp "$BUNDLE_DIR/hermes_wingman" "$HOME/.local/bin/"
cp -r "$BUNDLE_DIR/lib/"* "$HOME/.local/bin/lib/"

# Deploy runtime data (flutter_assets, icudtl.dat)
# IMPORTANT: Use trailing "/." on source to copy CONTENTS, not the directory
# itself — cp -r src/data dst/data creates dst/data/data/ (nested trap).
cp -r "$BUNDLE_DIR/data/." "$HOME/.local/bin/data/"

# Deploy backend — handle running process
if [ -f "$BACKEND_SRC" ]; then
  if [ "$NO_SYSTEMD" != "--no-systemd" ] && \
     systemctl --user is-active hermes-wingman.service &>/dev/null; then
    echo "  ▸ Stopping systemd backend service..."
    systemctl --user stop hermes-wingman.service
    sleep 1
    cp "$BACKEND_SRC" "$HOME/.local/bin/"
    chmod +x "$HOME/.local/bin/hermes-wingman-backend"
    systemctl --user start hermes-wingman.service
    echo "  ✓ Backend deployed + service restarted"
  else
    cp "$BACKEND_SRC" "$HOME/.local/bin/" 2>/dev/null || {
      echo "  ⚠ Backend binary in use — stop the process first:"
      echo "     systemctl --user stop hermes-wingman.service"
      echo "     # or: pkill hermes-wingman-backend"
      exit 1
    }
  fi
else
  echo "  ⚠ Backend binary not found at $BACKEND_SRC — skipping"
fi

chmod +x "$HOME/.local/bin/hermes_wingman" "$HOME/.local/bin/hermes-wingman-backend" 2>/dev/null || true

# ── Update desktop entry Exec line ─────────────────────────────────────
# Point directly at the binary (not a wrapper). The binary has $ORIGIN/lib
# RUNPATH baked in, so no LD_LIBRARY_PATH wrapper is needed.
DESKTOP_FILE="$HOME/.local/share/applications/hermes-wingman.desktop"
if [ -f "$DESKTOP_FILE" ]; then
  BINARY_PATH="$HOME/.local/bin/hermes_wingman"
  sed -i "s|Exec=.*|Exec=${BINARY_PATH}|" "$DESKTOP_FILE"
  echo "  ✓ Desktop entry Exec updated to: $BINARY_PATH"
fi

echo "✓ Deployed to ~/.local/bin/"
echo ""
echo "  hermes_wingman:         $(ls -lh $HOME/.local/bin/hermes_wingman | awk '{print $5}')"
echo "  hermes-wingman-backend: $(ls -lh $HOME/.local/bin/hermes-wingman-backend 2>/dev/null | awk '{print $5}')"
echo "  lib/:                   $(ls $HOME/.local/bin/lib/*.so 2>/dev/null | wc -l) shared libraries"
echo "  data/:                  flutter_assets + icudtl.dat"
echo ""
echo "NOTE: If launcher shortcuts still show the old version, restart the launcher:"
echo "  pkill walker        # Walker auto-restarts on Hyprland"
echo "  pkill rofi           # Restarts next invocation"
echo "  update-desktop-database ~/.local/share/applications/"
echo "  # Or log out/in to refresh all launcher caches"
