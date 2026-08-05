# Walker + Flatpak: Newly Installed Apps Not Appearing

## The Problem

You install a flatpak app (system-wide). It works when launched from the terminal via `flatpak run <app-id>`, but Walker doesn't show it. Even after `pkill walker && walker --gapplication-service &` — still missing.

## Root Cause

Three-part failure chain:

1. **Flatpak doesn't always create the export symlink on install.** The `.desktop` file exists inside the flatpak's app directory (`/var/lib/flatpak/app/<id>/.../files/share/applications/`), but the symlink in `/var/lib/flatpak/exports/share/applications/` may be missing.

2. **`flatpak update --appstream` creates the missing symlink.** Run this first.

3. **Even with the symlink in the system flatpak exports, Walker may not pick it up.** Walker's `desktopapplications` provider scans via `GDesktopAppInfo`, which should follow `XDG_DATA_DIRS` — but on Hyprland, system flatpak exports can be missed or the db isn't refreshed.

## The Fix

```bash
# Step 1: Refresh appstream data (creates the export symlink)
flatpak update --appstream

# Step 2: Symlink directly into user's local applications directory
ln -sf /var/lib/flatpak/exports/share/applications/<app-id>.desktop \
       ~/.local/share/applications/<app-id>.desktop

# Step 3: Restart Walker
pkill walker && walker --gapplication-service &
```

The user `~/.local/share/applications/` directory is the same place all other desktop entries live (Steam, Wine, AppImages, etc.). Walker consistently finds apps there.

## Verification

Check that the symlink resolves:
```bash
ls -la ~/.local/share/applications/<app-id>.desktop
readlink -f ~/.local/share/applications/<app-id>.desktop  # should resolve
```

Then hit Walker keybind and search for the app name.

## Prevention

New flatpak installs should automatically get a symlink in `~/.local/share/applications/`. If they don't, the fix above applies. To batch-fix all system flatpak apps:

```bash
for f in /var/lib/flatpak/exports/share/applications/*.desktop; do
    ln -sf "$f" ~/.local/share/applications/ 2>/dev/null || true
done
```

## Session Context

Discovered May 2026: installed `com.belmoussaoui.Authenticator` (flatpak, system). App ran fine via `flatpak run` but was invisible to Walker despite correct `XDG_DATA_DIRS`. The `flatpak update --appstream` step was needed first (the export symlink hadn't been created), then the user-directory symlink was the actual fix.
