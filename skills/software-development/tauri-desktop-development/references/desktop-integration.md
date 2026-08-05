# Linux Desktop Integration for Tauri apps

## What We Did

For the Kicks guitar workstation (app-id: `com.kicks.guitar-workstation`), we installed the app icon globally across:
1. **Build system** (`src-tauri/icons/`) — Tauri compile-time icons
2. **System hicolor theme** (`~/.local/share/icons/hicolor/`) — for Walker, rofi, GNOME, KDE
3. **Desktop entry** (`~/.local/share/applications/`) — for app launcher integration

## Icon Installation

```bash
APP_ID="com.kicks.guitar-workstation"
ICONS_SRC="src-tauri/icons"
ICONS_DST="$HOME/.local/share/icons/hicolor"

# Install standard sizes
for size in 32 128 256; do
    case $size in
        256) src_file="128x128@2x.png" ;;
        *)   src_file="${size}x${size}.png" ;;
    esac
    install -Dm644 "$ICONS_SRC/$src_file" "$ICONS_DST/${size}x${size}/apps/$APP_ID.png"
done

# HiDPI
install -Dm644 "$ICONS_SRC/icon.png" "$ICONS_DST/512x512/apps/$APP_ID.png"
```

## Desktop File

```bash
cat > "$HOME/.local/share/applications/$APP_ID.desktop" << 'EOF'
[Desktop Entry]
Type=Application
Name=Kicks
Comment=Guitar & Bass Workstation
Exec=/absolute/path/to/binary
Icon=com.kicks.guitar-workstation
Categories=Audio;AudioVideo;
Terminal=false
StartupNotify=true
EOF
```

**Critical:**
- `Icon=` value is the **basename without extension** of the icon files in hicolor (e.g. `com.kicks.guitar-workstation`, NOT a path)
- `Exec=` should be an absolute path or a command in PATH
- After installing, run: `update-desktop-database ~/.local/share/applications/`

## Cache Updates

```bash
update-desktop-database ~/.local/share/applications/
gtk-update-icon-cache ~/.local/share/icons/hicolor/
```

These may show benign warnings (`The generated cache was invalid`) — this is normal for non-standard theme directories and doesn't affect functionality. Walker, rofi, and most launchers find icons by filename regardless.

## How App Launchers (Walker) Resolve Icons

1. Look in `~/.local/share/icons/hicolor/{size}x{size}/apps/<icon-name>.png`
2. Fall back to `/usr/share/icons/hicolor/{size}x{size}/apps/<icon-name>.png`
3. Fall back to the `.desktop` file's directory
4. Display generic icon if nothing found

## Why ~/.local/share/ Instead of /usr/share/

- `/usr/share/` requires sudo and system-level install
- `~/.local/share/` is user-local — works for dev builds, doesn't pollute system
- Walker (and most Wayland launchers) search both locations automatically