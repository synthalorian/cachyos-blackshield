#!/usr/bin/env bash
# Generic freedesktop install for a locally-built app on KDE Plasma / CachyOS.
# Installs binary + data dir, application entry, and hicolor icon; refreshes
# KDE caches. Idempotent — safe to re-run after each build.
#
# Customize the five variables below, then run: ./install-local-app.sh
set -euo pipefail

APP_NAME="My App"                 # Display name (spaces OK) — becomes WM_CLASS for JUCE/X11 apps
APP_ID="my-app"                   # Desktop file + icon basename (lowercase-hyphen)
BINARY="/path/to/build/$APP_NAME" # Built binary to install
DATA_SRC=""                       # Optional dir copied beside the binary (e.g. samples/) — leave empty to skip
ICON_SRC="/path/to/icon_512.png"  # PNG icon (512x512 recommended)

PREFIX="$HOME/.local/share/$APP_ID"

[[ -x "$BINARY" ]] || { echo "error: $BINARY not found — build first" >&2; exit 1; }

echo "Installing to $PREFIX ..."
mkdir -p "$PREFIX"
cp -f "$BINARY" "$PREFIX/$APP_NAME"
if [[ -n "$DATA_SRC" && -d "$DATA_SRC" ]]; then
    rm -rf "$PREFIX/$(basename "$DATA_SRC")"
    cp -r "$DATA_SRC" "$PREFIX/"
fi

install -Dm644 "$ICON_SRC" \
    "$HOME/.local/share/icons/hicolor/512x512/apps/$APP_ID.png"

mkdir -p "$HOME/.local/share/applications"
cat > "$HOME/.local/share/applications/$APP_ID.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=$APP_NAME
Exec="$PREFIX/$APP_NAME"
Icon=$APP_ID
Terminal=false
Categories=AudioVideo;Audio;Utility;
StartupWMClass=$APP_NAME
EOF

desktop-file-validate "$HOME/.local/share/applications/$APP_ID.desktop" || true
update-desktop-database "$HOME/.local/share/applications" 2>/dev/null || true
gtk-update-icon-cache -q "$HOME/.local/share/icons/hicolor" 2>/dev/null || true
command -v kbuildsycoca6 >/dev/null && kbuildsycoca6 --noincremental 2>/dev/null || true

echo "Done. '$APP_NAME' should appear in the launcher."
echo "If the taskbar icon is blank: restart plasmashell (background), or unpin/re-pin the launcher."
