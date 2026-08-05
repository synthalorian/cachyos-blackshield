---
name: omarchy
description: >
  Omarchy (Arch + Hyprland) system config: Hyprland settings, window rules,
  animations, keybindings, monitors, gaps, borders, blur, opacity, waybar,
  walker, terminal config (Alacritty, Kitty, Ghostty), themes, wallpaper,
  night light, idle, lock screen, screenshots, layer rules, workspace
  settings, display config, cursor themes, and XWayland integration.
  Triggers: hyprland, window rules, animations, keybindings, monitors,
  gaps, borders, blur, opacity, waybar, walker, alacritty, kitty, ghostty,
  terminal config, themes, wallpaper, night light, idle, lock screen,
  screenshots, layer rules, workspace settings, display config, cursor theme,
  webapp, default application, mailto, mime handler, thunderbird.
version: 1.0.0
tags: [linux, hyprland, wayland, arch, desktop, config, cursor, gaming, plymouth, sddm, waybar, themes]
---

# Omarchy

Omarchy is an Arch-based Linux distribution with Hyprland compositor, serving as both synth's primary desktop and the training environment for Linux desktop customization.

## Safe vs System Zones

- `~/.config/` — User config (SAFE to edit)
- `~/.local/share/omarchy/` — System source (READ ONLY — NEVER EDIT)

## Core Omarchy Commands

```bash
omarchy theme set <name>    # Apply theme
omarchy refresh <app>       # Reset config to defaults
omarchy restart <app>       # Restart service
omarchy toggle <feature>    # Toggle feature
omarchy commands            # List all commands
omarchy debug --no-sudo --print   # Get debug info
```

## Cursor Theme Configuration

### Setting Cursor Theme in Hyprland

Cursor theme is set in two places:
1. `~/.config/hypr/looknfeel.conf` — `env = XCURSOR_THEME,<theme>` + `exec-once = hyprctl setcursor <theme> <size>`
2. `~/.config/hypr/autostart.conf` — `exec-once = hyprctl setcursor <theme> <size>` (may be duplicate — harmless)

### Cursor Theme Overrides

XCursor searches `~/.local/share/icons/` before `/usr/share/icons/`. To override specific cursors in a theme, you MUST copy the ENTIRE theme and replace the cursor files — partial overrides do NOT work (XCursor does not merge).

See `references/cursor-theme-overrides.md` for the full debugging path, pitfall checklist, and working solution.

## Plymouth Boot/Splash Theme

Plymouth manages the boot splash, shutdown screen, and unlock password prompt. The theme lives at `/usr/share/plymouth/themes/<name>/` and contains:

- **8 PNG images** — see `references/plymouth-image-roles.md` for the full inventory of each image's role and size
- **`<name>.script`** — Plymouth script that sets background color and orchestrates the UI
- **`<name>.plymouth`** — theme metadata with `ConsoleLogBackgroundColor`

### Background Color

Set in the `.script` file using float values (0.0–1.0):
```
Window.SetBackgroundTopColor(0.141, 0.000, 0.216);   # #240037
Window.SetBackgroundBottomColor(0.141, 0.000, 0.216);
```
To convert hex to float: `hex_value / 255`. Also set in `.plymouth` metadata: `ConsoleLogBackgroundColor=0x240037`.

### Image Recoloring

Use the script-based PIL approach documented in `references/plymouth-image-roles.md`. Two patterns: recolor all non-transparent pixels to a solid target, or recolor by source color with tolerance.

### Initramfs

After ANY change to Plymouth theme files (images, script, config):
```bash
sudo mkinitcpio -P
```
Plymouth bundles its theme into the initramfs at build time. Without a rebuild, changes don't appear until the next initramfs regeneration.

### Shutdown Screen Color Mismatch

See `references/plymouth-shutdown-color.md` for the full debugging path and manual fix.

Quick fix: `sudo ~/.hermes/skills/omarchy/scripts/fix-plymouth-preview-bg.sh <old_hex> <new_hex> <theme>`
Then: `sudo mkinitcpio -P`

See also: `references/plymouth-image-roles.md` for the full image inventory, recolor scripts, and palette mapping.

## SDDM Login Theme

SDDM manages the login screen (the greeter you see at boot). Themes live in two locations:
- System-wide: `/usr/share/sddm/themes/<name>/`
- User config: `~/.config/sddm/themes/<name>/`

SDDM config is set in `/etc/sddm.conf` or `/etc/sddm.conf.d/theme.conf`:

**PITFALL — Empty theme directory = white default fallback:** If the configured theme directory (`Current=synthwave84`) exists but is EMPTY (no Main.qml), SDDM silently falls back to the Qt default theme. This produces a **white input field** and **white borders** instead of the expected theme colors — the user sees exactly the opposite of what synthwave84 should look like. Fix: populate the directory with Main.qml, metadata.desktop, theme.conf, and logo.svg (or copy from a working theme like `omarchy` and reassign colors). See `references/sddm-synthwave84-theme.md` for the complete file contents and color mapping.
```ini
[Theme]
Current=synthwave84
```

### Theme Structure

A minimal SDDM theme needs:
- `Main.qml` — QtQuick UI definition (Rectangle, Image for logo, TextInput for password)
- `logo.svg` — SVG logo/text rendered above the login form
- `metadata.desktop` — theme metadata (`[SddmGreeterTheme]` section)
- `theme.conf` — theme config (optional)

### Main.qml Key Patterns

```qml
Rectangle {
    id: root
    color: "#240037"                          // Background = surface purple

    Column {
        anchors.centerIn: parent
        Image { source: "logo.svg" }          // Centered logo
        Row {
            Text { text: "\uf023" }           // Lock icon (Nerd Font unicode)
            Rectangle {                       // Password entry box
                border.color: "#FFFF66"       // Yellow border
                TextInput { echoMode: TextInput.Password }
            }
        }
        Text { id: errorMessage }             // Login failure message
    }
}
```

### Color Mapping for synthwave84

| Element | Color | Role |
|---------|-------|------|
| Background | `#240037` | Surface purple |
| Logo fill | `#7B00B4` | Plymouth-matching purple (`#7B00B4` in `/usr/share/plymouth/themes/synthwave84/logo.png`) |
| Entry border | `#FFFF66` | Yellow frame |
| Lock icon | `#FFFF66` | Yellow |
| Input text | `#FFFF66` | Yellow — typed password dots |
| Error text | `#FF0040` | Red |

### Installation

The install script in the complete-omarchy-synthwave-84 repo:
1. Copies `sddm/<name>/` to `/usr/share/sddm/themes/<name>/`
2. Sets `Current=<name>` in `/etc/sddm.conf`
3. SDDM picks it up on next login (no service restart needed)

## Windows VM

Omarchy ships a Docker-based Windows 11 VM using the `dockurr/windows` image with KVM acceleration.

**Commands:**
- `omarchy windows vm install` — Install VM (requires /dev/kvm)
- `omarchy windows vm launch` — Start VM and open RDP connection
- `omarchy windows vm stop` — Stop VM (2m grace period)
- `omarchy windows vm status` — Check if VM is running
- `omarchy windows vm remove` — Remove VM and data

**Config:** `~/.config/windows/docker-compose.yml`

**Defaults:** 8 CPU cores, 16GB RAM, 256GB disk, Windows 11, custom username/password.

**Access:**
- VNC web interface: http://127.0.0.1:8006
- RDP: port 3389

**GPU passthrough:** NOT configured by default. VM uses QEMU's virtio-gpu (virtual display), not the host GPU. For GPU passthrough (IOMMU/VFIO) to give the VM bare-metal GPU access, manual hardware configuration is required — this is a non-trivial setup involving IOMMU groups, VFIO driver binding, and Docker device passthrough.

**Shared storage:** `~/Windows` is mounted as `/shared` inside the VM.

## Configuration Files

| File | Purpose | Edit Policy |
|------|---------|-------------|
| `~/.config/hypr/hyprland.conf` | Main Hyprland config — sources defaults, user config, then toggles | **DON'T APPEND DIRECTLY** — see pitfall below |
| `~/.config/hypr/autostart.conf` | Startup commands | SAFE to edit |
| `~/.config/hypr/input.conf` | Input device config | SAFE to edit |
| `~/.config/hypr/looknfeel.conf` | Decorations, cursor, animations | SAFE to edit |
| `~/.config/waybar/config.jsonc` | Waybar layout (JSON with modules) | SAFE to edit |
| `~/.config/waybar/style.css` | Waybar styling | SAFE to edit |
| `~/.config/walker/config.toml` | Walker launcher config | SAFE to edit |
| `~/.config/alacritty/alacritty.toml` | Alacritty terminal | SAFE to edit |
| `~/.config/kitty/kitty.conf` | Kitty terminal | SAFE to edit |
| `~/.config/ghostty/config` | Ghostty terminal | SAFE to edit |
| `~/.config/foot/foot.ini` | Foot terminal | SAFE to edit |

## Waybar Theme Integration

Waybar's `style.css` hooks into the Omarchy theme system via `@import`:

```css
@import "../omarchy/current/theme/waybar.css";
```

The theme's `waybar.css` provides `@define-color` variables that `style.css` references. By default it only defines `foreground` and `background`. You can extend it with additional color variables for a richer theme:

```css
@define-color foreground #FFFF66;   /* yellow text */
@define-color background #0D0221;   /* deep purple bg */
@define-color surface #240037;      /* module background */
@define-color primary #8F00FF;      /* electric purple accents */
```

**Persistence pattern:** Theme files live in TWO places and both must be updated:

1. `~/.config/omarchy/current/theme/waybar.css` — the live config (symlink or copy)
2. `~/.config/omarchy/themes/<name>/waybar.css` — the theme source (survives `omarchy theme set <name>`)

If you only edit `current`, the changes are lost when the theme is re-applied. Always edit both.

**Typical Waybar color map for synthwave84:**
| CSS Variable | Usage | synthwave84 value |
|---|---|---|
| `@background` | Bar background (often transparent) | `#0D0221` |
| `@surface` | Module pill backgrounds | `#240037` |
| `@primary` / `@accent` | Active states, hovers, icons | `#8F00FF` |
| `@foreground` | Text | `#FFFF66` (yellow) or `#FFFFFF` (white) |

**Pitfall — Waybar restart:** After editing CSS, reload with `pkill -USR2 waybar`. Do NOT use `kill -9` or a full `pkill waybar` + restart unless the reload fails — SIGUSR2 is the proper graceful reload signal. If waybar has crashed and needs a fresh start: `waybar &` (background the process).

**Pitfall — Module opacity defeats container background changes:** If Waybar module pills look translucent, the culprit is usually `opacity` set on the individual modules, not the container. The big CSS selector for module IDs (lines ~85–115 in `style.css`) often has `opacity: 0.9`. Changing the `.modules-left/center/right` container background to `@surface` has NO visible effect if modules still have opacity — they'll render at 0.9 alpha on top of the container. Fix: remove `opacity: 0.9` from the module selector and keep containers at `background-color: @surface` for a unified solid purple bar.

**Pitfall — Empty workspace buttons look different from occupied:** `#workspaces button.empty` gets `color: #663388` (muted purple text) by default. Workspaces with windows use `@fg` (yellow text). If the user asks why workspaces 5-8 look different from 1-4, this is why — they're empty. To make all workspace text the same color, change `button.empty` to use `@fg` or remove the rule entirely.

## Walker Launcher

Walker is the primary app launcher on Omarchy, configured at `~/.config/walker/config.toml`. It runs as a background daemon via `--gapplication-service`.

**Pitfall — Walker caches desktop files at startup.** Newly installed apps (flatpak, pacman, AUR) won't appear until Walker is restarted. Flatpak installs `.desktop` files to `/var/lib/flatpak/exports/share/applications/` — Walker's `desktopapplications` provider scans these via `XDG_DATA_DIRS`, but only on launch.

**Pitfall — System flatpak apps invisible even after restart.** Flatpak system-installed apps don't always create their export symlink in `/var/lib/flatpak/exports/share/applications/` on install. Even after `flatpak update --appstream` creates the symlink, Walker may still miss it. The reliable fix is to symlink directly into the user's local applications directory:

```bash
flatpak update --appstream
ln -sf /var/lib/flatpak/exports/share/applications/<app-id>.desktop \
       ~/.local/share/applications/<app-id>.desktop
pkill walker && walker --gapplication-service &
```

See `references/walker-flatpak-app-visibility.md` for full debugging path, root cause, and batch-fix script.

**Restart Walker:**
```bash
pkill walker && walker --gapplication-service &
```

The config already has an emergency handler wired: `Restart Walker` → `omarchy-restart-walker` (available in Walker's emergency menu). This is the preferred method since it doesn't race against the daemon lifecycle.

**Config layout** (`config.toml`):
- `default` providers: `desktopapplications`, `websearch`
- Custom prefixes: `/` (provider list), `.` (files), `:` (symbols), `=` (calc), `@` (websearch), `$` (clipboard)
- Theme: `omarchy-default` with override at `~/.local/share/omarchy/default/walker/themes/`
- `max_results = 256`

## CRITICAL PITFALL: Never Append Rules to hyprland.conf Directly

`~/.config/hypr/hyprland.conf` has a **specific sourcing chain** that matters. Adding rules or config after the toggle wildcard source creates an inconsistent state where toggles may conflict with your additions. Invalid rules can crash Hyprland entirely — killing the compositor, which also kills Waybar and all other Wayland processes.

**What to do instead:**

1. **Put rules in the correct sourced file** — use `~/.config/hypr/autostart.conf` (startup commands) or `~/.config/hypr/looknfeel.conf` (decorations/style).
2. **Use `omarchy toggle`** — check available toggles with `omarchy toggle list`.
3. **Create a dedicated rule file** — create `~/.config/hypr/app-rules.conf` and add `source = ~/.config/hypr/app-rules.conf` to hyprland.conf BEFORE the toggles block, not after.
4. **Use Omarchy's built-in handling** — Omarchy's `windows.conf` already has a `default-opacity` tag system. Most apps work without custom rules.

**If you must edit hyprland.conf:**
- Place new rules between the user config `source =` blocks and the toggle source
- NEVER after the toggle source
- Test one rule at a time
- If Waybar disappears after reloading, the rules broke Hyprland — remove immediately and reload

**This is the most dangerous file to touch on the system.** A syntax error here kills the entire desktop session.

## Monitor Mode Persistence

**Issue:** After lock/unlock or suspend/resume, the primary monitor may wake in a fallback resolution (e.g. 1920×1080 instead of 2560×1440@180Hz). XWayland games then fail to detect the native 2K mode.

**Root cause:** `hyprctl dispatch dpms on` powers the display but does not re-apply the configured mode from `monitors.conf`. The monitor's EDID fallback persists.

**Fix:** Ensure `omarchy-system-wake` (called after lock/unlock and resume) reloads Hyprland config:

```bash
# At the end of ~/.local/share/omarchy/bin/omarchy-system-wake
sleep 0.5
hyprctl reload >/dev/null 2>&1 || true
```

This forces re-application of `monitors.conf` and restores the correct resolution/refresh rate.

**See:** `references/monitor-mode-dpms-wake.md` for full diagnosis, verification steps, and session-specific notes.

## Dual Monitor Game Window Straddle

**Issue:** After DPMS wake, even with correct resolution restored, game windows may launch straddling both monitors (e.g. left half on secondary, right half on primary). This happens because the game's saved window position was applied to a momentarily corrupted coordinate space during the DPMS cycle.

**Fix:** Use Hyprland window rules to anchor the game to the primary workspace:
```hyprlang
windowrule = workspace 1, match:class StarCitizen
windowrule = move 1920 0, match:class StarCitizen
```

**PITFALL — Window rule syntax changed in Hyprland 0.55+.** Both `windowrulev2` AND the old `windowrule` syntax with `class:^(regex)$` are deprecated/removed. The new syntax is:

```hyprlang
# OLD (broken on 0.55+):
windowrulev2 = fullscreen, class:^(steam_app_1286830)$
windowrule = fullscreen, class:^(steam_app_1286830)$

# NEW (correct for 0.55+):
windowrule = fullscreen on, match:class steam_app_1286830
windowrule = idle_inhibit fullscreen, match:class steam_app_1286830
```

Key differences:
- No regex wrapping (`^...$`) — use plain class names
- `match:` prefix instead of bare `class:`
- Boolean rules need explicit value: `fullscreen on` not just `fullscreen`
- `immediate` was replaced by `idle_inhibit fullscreen`

**See:** `references/game-window-straddle-dual-monitor.md` for full diagnosis, game-specific config fixes, and root-cause analysis.

## Gaming Idle Inhibit

**Issue:** Proton/Wine Vulkan games (Star Citizen, etc.) crash when the Omarchy screensaver or hyprlock triggers. The Vulkan device context gets yanked when the display powers off, and most game engines don't handle device loss gracefully.

**Root cause:** `hypridle` timeouts → screensaver → hyprlock → DPMS off → Vulkan device lost → game crash. The game has no way to opt out — the compositor doesn't know it's running.

**Fix:** Wrap the game launcher with an idle-inhibit script that tells Hyprland "don't sleep while this is running":

```bash
#!/usr/bin/env bash
# ~/Games/star-citizen/sc-launch-inhibit.sh
cleanup() { hyprctl dispatch hypridle uninhibit 2>/dev/null || true; }
trap cleanup EXIT INT TERM
hyprctl dispatch hypridle inhibit 2>/dev/null || true
exec gamemoderun "/path/to/game/launcher.sh" "$@"
```

This uses `hyprctl dispatch hypridle inhibit` to block the screensaver/lock cycle entirely while the game runs. Combined with `gamemoderun` for CPU governor and I/O priority optimizations.

**Pitfall — Persistent launcher processes (like RSI Launcher):** The idle-inhibit wrapper above uses `exec` + `trap cleanup EXIT`. This only works if the launched process **exits** when the game closes. If the launcher stays in the system tray (RSI Launcher, EA App, etc.), `exec` never returns, the trap never fires, and idle stays inhibited forever until manual uninhibit. For persistent launchers, use a different lifecycle approach: background the launcher, poll for the game PID, wait for game exit, then uninhibit.

**Pitfall — Gamescope with launcher-wrapper games:** Gamescope is often the go-to recommendation, but it FAILS with games that use a launcher process (RSI Launcher, EA App, etc.). The launcher runs fine inside gamescope, but when it spawns the actual game as a child process, the game doesn't properly connect to the gamescope compositor session — resulting in a black screen or crash. Use the idle-inhibit approach instead for launcher-wrapper games. Gamescope works well for games launched directly (Steam native, standalone binaries).

## Desktop Application Integration

When installing custom apps (compiled Rust binaries, Flutter apps, game engines, etc.) that need to appear in app launchers (Walker, wofi, rofi):

### Icon Installation

```bash
# Resize icon to standard sizes using ImageMagick
convert icon.png -resize 512x512 icon-512.png
convert icon.png -resize 256x256 icon-256.png

# Install to hicolor icon theme (XDG standard)
mkdir -p ~/.local/share/icons/hicolor/512x512/apps/
mkdir -p ~/.local/share/icons/hicolor/256x256/apps/
cp icon-512.png ~/.local/share/icons/hicolor/512x512/apps/<app-name>.png
cp icon-256.png ~/.local/share/icons/hicolor/256x256/apps/<app-name>.png

# Update icon cache
gtk-update-icon-cache -f ~/.local/share/icons/hicolor/
```

### .desktop File

Create `~/.local/share/applications/<app-name>.desktop`:

```ini
[Desktop Entry]
Type=Application
Name=App Name
Comment=Short description
Exec=/absolute/path/to/binary
Icon=app-name
Terminal=false
Categories=Development;Game;
```

**Key points:**
- `Icon=` uses the icon name (without extension or path) — the hicolor theme resolves it
- `Exec=` must be an absolute path
- `Terminal=true` for CLI apps that need a terminal window
- Common categories: `Development`, `Game`, `GameEngine`, `Utility`, `Education`

```bash
# Make executable and update desktop database
chmod +x ~/.local/share/applications/<app-name>.desktop
update-desktop-database ~/.local/share/applications/
```

### Walker Integration

Walker caches desktop files at startup. After installing a new .desktop file:
```bash
pkill walker && walker --gapplication-service &
```

Or use Walker's emergency menu → `Restart Walker`.

### Removing a Webapp Handler

Omarchy webapp handlers (created by `omarchy webapp-*` commands) leave artifacts in three places:

| Component | Path |
|---|---|
| Handler script | `~/.local/share/omarchy/bin/omarchy-webapp-handler-<name>` |
| Desktop file | `~/.local/share/applications/<NAME>.desktop` |
| Icon | `~/.local/share/applications/icons/<NAME>.png` |

**PITFALL — Removing just the desktop file isn't enough.** The handler script in `~/.local/share/omarchy/bin/` is what actually launches the webapp. The desktop file references it via `Exec=`. If you only delete the desktop file but keep the handler, the MIME association may still resolve through stale caches.

Full removal:
```bash
rm -v ~/.local/share/applications/<NAME>.desktop \
      ~/.local/share/applications/icons/<NAME>.png \
      ~/.local/share/omarchy/bin/omarchy-webapp-handler-<name>
```

### Setting Default MIME Handlers

After removing a webapp (or installing a replacement), update the default handler:

```bash
# Update the MIME association
xdg-mime default <replacement.desktop> <mime-type>

# Verify it took
xdg-mime query default <mime-type>
```

The canonical config file is `~/.config/mimeapps.list` under `[Default Applications]`. `xdg-mime default` writes here — but it's worth verifying the entry was actually replaced rather than duplicated.

**PITFALL — Mozilla desktop file naming.** Firefox and Thunderbird use `org.mozilla.` prefixed desktop filenames:
- Thunderbird: `org.mozilla.Thunderbird.desktop` (NOT `thunderbird.desktop`)
- Firefox: `org.mozilla.firefox.desktop` (NOT `firefox.desktop`)

Find the exact name with: `pacman -Ql <pkg> | grep '.desktop'`

**Example — replacing HEY webapp with Thunderbird:**
```bash
# Purge HEY
rm -v ~/.local/share/applications/HEY.desktop \
      ~/.local/share/applications/icons/HEY.png \
      ~/.local/share/omarchy/bin/omarchy-webapp-handler-hey

# Install Thunderbird
sudo pacman -S thunderbird

# Set as default mail handler
xdg-mime default org.mozilla.Thunderbird.desktop x-scheme-handler/mailto
```

## Theme Color Palette

The Omarchy synthwave84 theme has a canonical color palette extracted from the system theme files. When building or porting apps that need to match Omarchy's retro-purple aesthetic, use these exact colors:

| Role | Hex | Description |
|------|-----|-------------|
| Background | `#0D0221` | Deepest background / scaffold |
| Surface | `#240037` | Card backgrounds, base surface |
| Primary | `#8F00FF` | Electric purple — main accent |
| Secondary | `#FF00FF` | Hot pink — complementary accent |
| Accent/cyan | `#00FFFF` | Data streams, tertiary |
| Text | `#FFFFFF` | White text |
| Success | `#00FF41` | Lime green |
| Warning | `#FFFF66` | Yellow |
| Error | `#FF0040` | Red |

**Pitfall — Missing foot.ini theme file:** Omarchy themes generate terminal configs from `~/.local/share/omarchy/default/themed/foot.ini.tpl`, but not all themes include `foot.ini` in their theme directory. If `~/.config/foot/foot.ini` includes `~/.config/omarchy/current/theme/foot.ini` and that file doesn't exist, foot falls back to defaults (no colors applied). The fix is to create the missing `foot.ini` in the theme directory (`~/.config/omarchy/themes/<name>/foot.ini`) using the same ANSI palette as the other terminals, then re-run `omarchy theme set <name>`.

**Pitfall — Terminal font inconsistency:** Each terminal's user config (`~/.config/<term>/...`) sets its own font independently. When adding a new terminal or switching fonts, check ALL terminal configs — they can drift (e.g., foot using JetBrainsMono while alacritty/kitty/ghostty use 3270 Nerd Font).

**See:** `references/synthwave84-color-palette.md` for the full 20-color palette, Flutter AppColorScheme definition, complete Material 3 `ThemeData` with all component themes (dialog, bottomSheet, input, switch, chip, tabBar, etc.), and source file extraction.

**See:** `references/gaming-idle-inhibit.md` for full wrapper script, game-specific configurations, testing steps, and session notes.

**See:** `references/swtor-linux-proton.md` for SWTOR-specific Proton setup, Bink video crash fix, and Hyprland window rules on Omarchy.

## Waybar Tooltip Troubleshooting

If waybar tooltips (hover info) stop appearing:

1. **Restart waybar first** — most tooltip issues resolve with a fresh process:
   ```bash
   pkill waybar; sleep 1; waybar &
   ```
2. **Check Waybar version compatibility** — Waybar 0.15.0 + Hyprland 0.55 had tooltip regressions. Check Omarchy defaults for any recent config changes.
3. **SIGUSR2 reload** — try `pkill -USR2 waybar` for a graceful CSS/config reload without killing the process. Only full restart if reload fails.

## SWTOR on Linux (Steam/Proton)

Star Wars: The Old Republic runs Platinum on ProtonDB with Proton 10.0-3/10.0-4. Three fixes required:

1. **Rename Bink intro videos** — crash Proton's media playback at loading screen
2. **Windowed Fullscreen only** — exclusive fullscreen crashes after ~15 min
3. **Hyprland auto-fullscreen rule** — game launches in tiny window, needs `fullscreen on`

See `references/swtor-linux-proton.md` for the full setup guide, Steam launch options, and AMD GPU notes.

## Flutter Apps on Hyprland

**Issue:** Flutter Linux desktop apps render a GTK header bar on Wayland by default, causing double-decorations and vertical clipping on Hyprland (which provides its own window decorations).

**Fix:** The app's `my_application.cc` must detect non-GNOME Wayland compositors and disable the header bar:

```c
const gchar* xdg_desktop = g_getenv("XDG_CURRENT_DESKTOP");
if (xdg_desktop == NULL || !g_str_has_prefix(xdg_desktop, "GNOME")) {
    use_header_bar = FALSE;
}
```

**Window size:** Flutter's default 1280x720 fits 1920x1080 displays. If content appears right-shifted or clipped, the issue is in the Flutter layout (overflow in a Row/Column, nested Scaffolds) — NOT in Hyprland config. Debug with `LayoutBuilder` and `ClipRect` wraps in the Flutter code before touching any WM rules.

**PITFALL: Do NOT remove GTK window decorations.** Calling `gtk_window_set_decorated(window, FALSE)` in the Flutter runner's `my_application.cc` causes Hyprland to render window shadows and borders around the undecorated surface — a visible "thin purple glow" that makes the app look shifted/broken. Keep standard decorations and handle positioning in the Flutter code or the `first_frame_cb` callback instead of the GTK position hint.

**DO NOT add window rules for Flutter apps in hyprland.conf.** See the CRITICAL PITFALL above — Hyprland window rules belong in a dedicated file sourced before the toggle block, not appended to hyprland.conf. A broken rule kills the entire desktop session (Waybar, everything).

```hyprlang
# SWTOR - auto fullscreen + idle inhibit for VSync off (Hyprland 0.55+ syntax)
windowrule = fullscreen on, match:class steam_app_1286830
windowrule = idle_inhibit fullscreen, match:class steam_app_1286830
```

**PITFALL — Window rule syntax changed in Hyprland 0.55+.** Both `windowrulev2` AND the old `windowrule` syntax with `class:^(regex)$` are deprecated/removed. See the "Dual Monitor Game Window Straddle" section above for the full syntax guide.

If window rules are genuinely needed (e.g. a full-screen game misbehaving), use a dedicated rule file:
```bash
# Create: ~/.config/hypr/app-rules.conf
windowrule = float on, match:class app_name
windowrule = size 1280 720, match:class app_name
windowrule = center, match:class app_name

# Then source it in hyprland.conf BEFORE the toggle block:
echo 'source = ~/.config/hypr/app-rules.conf' >> ~/.config/hypr/hyprland.conf
# ^^ Place this ABOVE the toggle source, never below
```

**See** the `production-ready-rust-flutter-projects` skill reference `flutter-linux-runner-wayland.md` for full header-bar fix implementation.
