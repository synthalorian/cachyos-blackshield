# Desktop Launch Environment: Wayland vs X11

**Context:** Hermes Wingman (Flutter Linux desktop app) exhibited different window layout behavior depending on how it was launched — terminal vs desktop launcher (Walker).

## The Difference

### Terminal launch (worked correctly)
```
DISPLAY=:0
# No WAYLAND_DISPLAY, GDK_BACKEND, or HYPRLAND vars
```
The Flutter GTK app falls back to X11 (XWayland). GTK has full control over window sizing and positioning.

### Desktop launcher launch (broken layout)
```
WAYLAND_DISPLAY=wayland-1
GDK_BACKEND=wayland,x11,*
XDG_SESSION_TYPE=wayland
HYPRLAND_INSTANCE_SIGNATURE=...
```
The Flutter GTK app uses the Wayland backend. Window constraints come from the compositor, which may size the window differently than on X11.

## Source of the Environment Difference

- **Desktop entries** (.desktop files) inherit the compositor's full Wayland environment because the launcher (Walker, Rofi) is itself a Wayland-native process
- **Terminal** launches with DISPLAY=:0 if GTK hasn't detected the Wayland display, falling back to XWayland
- The Flutter GTK binary (`hermes_wingman`) uses `GDK_BACKEND=wayland,x11,*` which auto-detects the available backend

## Diagnostic Wrapper

To capture what environment a desktop launcher passes to the app:

```bash
#!/bin/bash
exec 2>/tmp/app-debug.log
set -x
echo "PWD: $(pwd)" >&2
echo "ARGS: $@" >&2
echo "DATE: $(date)" >&2
env | sort >&2
exec /path/to/actual/binary "$@"
```

Point the `.desktop` `Exec=` to this wrapper, launch from the launcher, then read `/tmp/app-debug.log`.

## The Fix: `double.infinity` on Root Container + GTK vexpand/hexpand

The root cause is not the display backend per se — it's that `Container` with only `color` doesn't demand full space. On Wayland, the window constraints differ enough that this manifests as a different window size.

### Dart fix: force root layout to fill

```dart
Container(
  color: scheme.scaffoldBackground,
  width: double.infinity,
  height: double.infinity,
  child: Row(children: [...]),
)
```

This forces Flutter to grab all available space from the parent constraints regardless of the display backend.

### GTK fix: force Flutter view to expand in the window

Even with the Dart fix, on Wayland the GTK window may still not expand the Flutter view to fill the frame. The GTK layer needs explicit expand flags:

```c
// In my_application.cc, after creating the view:
FlView* view = fl_view_new(project);

// CRITICAL on Wayland: force the Flutter view to fill the window
gtk_widget_set_vexpand(GTK_WIDGET(view), TRUE);
gtk_widget_set_hexpand(GTK_WIDGET(view), TRUE);

gtk_widget_show(GTK_WIDGET(view));
gtk_container_add(GTK_CONTAINER(window), GTK_WIDGET(view));
```

Without `gtk_widget_set_vexpand/hexpand(TRUE)`, GTK on Wayland may give the Flutter view a shrink-wrapped size instead of expanding it to fill the parent container. The binary has `$ORIGIN/lib` in its RUNPATH, so LD_LIBRARY_PATH wrappers are unnecessary.

### Both fixes are required together

- The **Dart fix** (`double.infinity`) tells Flutter's layout engine to claim all available space
- The **GTK fix** (`vexpand/hexpand`) tells GTK to give Flutter's view all available space in the window frame
- On X11, the Dart fix alone is sufficient. On Wayland, both are required.

## Desktop Entry: Direct Binary, No Wrapper

Flutter Linux desktop binaries have `$ORIGIN/lib` RUNPATH baked into the ELF. The dynamic linker automatically finds shared libraries in `lib/` relative to the binary — no `LD_LIBRARY_PATH` wrapper needed.

**PREFERRED: Point desktop entries directly at the binary:**

```ini
[Desktop Entry]
Exec=/home/user/.local/bin/hermes_wingman
Icon=hermes-wingman
```

**Do NOT use a wrapper script.** The wrapper:
- Introduces failure points (unset `$HOME` breaks `LD_LIBRARY_PATH`)
- Prevents the launcher from tracking the binary (causes stale/wrong version issues)
- Is redundant — the binary's RUNPATH handles library resolution

**After updating the desktop entry, always refresh launcher caches:**

```bash
update-desktop-database ~/.local/share/applications/ 2>/dev/null
pkill walker    # Auto-restarts on Hyprland — fresh cache
sleep 2
```

**Deploy the full Flutter bundle — not just the binary.** The data directory (`data/flutter_assets/`, `data/icudtl.dat`) is required at runtime. Use the trailing-dot pattern to avoid nested directories:

```bash
cp -r build/linux/x64/release/bundle/data/. ~/.local/bin/data/
```

Without `data/`, Flutter can't find its assets and may render incorrectly or fail to display content.

## Launcher Cache Issues

Even with the correct binary deployed, desktop launchers may show stale results if:

1. Walker caches `.desktop` file reads until process restart
2. XDG desktop database needs refresh
3. Icon theme cache is stale

**Refresh sequence:**
```bash
update-desktop-database ~/.local/share/applications/ 2>/dev/null
pkill walker         # Auto-restarts on Hyprland via .config/autostart
sleep 2
pgrep walker || walker --gapplication-service &  # Manual restart if needed
```

## Test Before Shipping

Always test Flutter desktop apps under BOTH conditions:
1. `DISPLAY=:0 /path/to/binary` (terminal, X11)
2. Via desktop entry through the system launcher (Wayland)

If the window sizes differently, apply the `double.infinity` fix at the root layout level.
