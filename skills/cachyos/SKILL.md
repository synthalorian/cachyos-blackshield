---
name: cachyos
description: >
  CachyOS (Arch-based + KDE Plasma) system config: KDE Plasma settings,
  KWin window rules, panels, widgets, shortcuts, effects, themes, Alacritty
  terminal, Wayland display config, pacman/paru package management, systemd
  services, and CachyOS-specific optimizations.
  Triggers: cachyos, kde, plasma, kwin, panels, widgets, shortcuts, effects,
  themes, wallpaper, display config, monitor, wayland, alacritty, fish,
  terminal config, pacman, paru, yay, system update, desktop config.
version: 1.0.0
tags: [linux, cachyos, arch, kde, plasma, wayland, desktop, config, gaming, terminal, themes]
---

# CachyOS

CachyOS is an Arch-based Linux distribution optimized for performance, running KDE Plasma on Wayland. It serves as synth's primary desktop and training environment for Linux desktop customization.

## System Info

- **Distro:** CachyOS (Arch-based, rolling release)
- **Desktop:** KDE Plasma 6.x on Wayland
- **Shell:** Fish
- **Terminal:** Alacritty
- **Package manager:** pacman + paru/yay (AUR)

## Safe vs System Zones

- `~/.config/` — User config (SAFE to edit)
- `/usr/`, `/etc/` — System source (READ ONLY — NEVER EDIT without understanding consequences)

## Core Commands

```bash
# KDE Plasma
plasmashell --replace              # Restart Plasma shell
kwriteconfig6 <group> <key> <val>  # Modify KDE config (Plasma 6)
systemctl --user restart plasma-*  # Restart Plasma components

# Package management
pacman -Syu                        # System update
pacman -S <pkg>                    # Install package
paru <pkg>                         # Install from AUR (or yay)
cachyos-rate-mirrors               # Optimize mirror selection

# System
systemctl status <service>         # Check service status
journalctl -u <service> -f         # Follow service logs
```

## KDE Plasma Configuration

### Config Files

| File | Purpose |
|------|---------|
| `~/.config/plasmarc` | General Plasma settings |
| `~/.config/kwinrc` | KWin compositor, window rules, effects |
| `~/.config/kdeglobals` | Global KDE colors, fonts, toolbar |
| `~/.config/kscreenlockerrc` | Lock screen config |
| `~/.config/powermanagementprofilesrc` | Power management profiles |
| `~/.config/alacritty/alacritty.toml` | Alacritty terminal |
| `~/.config/fish/config.fish` | Fish shell config |

### Modifying KDE Config

Use `kwriteconfig6` for Plasma 6:
```bash
kwriteconfig6 --file kwinrc --group Compositing --key OpenGLIsUnsafe false
kwriteconfig6 --file plasmarc --group Theme --key name Breeze
```

Use `kreadconfig6` to read:
```bash
kreadconfig6 --file kwinrc --group Compositing --key OpenGLIsUnsafe
```

After changing config, restart the relevant component:
```bash
systemctl --user restart plasmashell
# or for KWin:
qdbus org.kde.KWin /KWin reconfigure
```

### Panel Configuration

Panels are configured through KDE System Settings or by editing:
- `~/.config/plasma-org.kde.plasma.desktop-appletsrc`

### Widget/Plasmoid Installation

Widgets live in `~/.local/share/plasma/plasmoids/` (user) or `/usr/share/plasma/plasmoids/` (system).

## Alacritty Terminal

Config at `~/.config/alacritty/alacritty.toml`.

Key settings:
```toml
[window]
padding = { x = 8, y = 8 }
opacity = 0.95

[font]
size = 12.0

[font.normal]
family = "JetBrainsMono Nerd Font"
style = "Regular"
```

## Fish Shell

Config at `~/.config/fish/config.fish`.

Fish uses `fish_add_path` for PATH modifications and `set -gx` for environment variables:
```fish
fish_add_path ~/.local/bin
set -gx EDITOR nvim
```

## Wayland / Display

KDE Plasma on Wayland uses KWin as the compositor. Display configuration:
- KDE System Settings → Display and Monitor
- `kscreen` backend manages display profiles
- Config stored in `~/.local/share/kscreen/`

## Package Management

### Pacman

```bash
pacman -Syu                  # Full system update
pacman -Ss <keyword>         # Search repos
pacman -Ql <pkg>             # List files from package
pacman -Qo <file>            # Find which package owns a file
pacman -Sc                   # Clean old cache
pacman -Scc                  # Clean all cache (use sparingly)
```

### AUR (paru/yay)

```bash
paru <pkg>                   # Install from AUR
paru -Ss <keyword>           # Search AUR
paru -Qm                     # List AUR packages
paru -Sc                     # Clean AUR cache
```

## Gaming

CachyOS is gaming-optimized with:
- CachyOS kernel (optimized for desktop/gaming)
- Mesa drivers pre-configured
- Steam/Proton support out of the box
- Gamemode available (`gamemoderun`)

## Theming

KDE themes consist of:
- **Color scheme:** `~/.local/share/color-schemes/`
- **Plasma style:** `~/.local/share/plasma/desktoptheme/`
- **Window decoration:** `~/.local/share/kwin/decorations/`
- **Icons:** `~/.local/share/icons/`
- **Cursors:** `~/.local/share/icons/`

Apply via KDE System Settings → Appearance.

## Pitfalls

- **AUR helpers + agent terminals:** paru/yay can't elevate via sudo from a Hermes agent terminal (no TTY for the password prompt — "sudo: a terminal is required"). Workaround: preinstall repo deps with `sudo pacman -S`, then `makepkg -f` in `~/.cache/paru/clone/<pkg>`, then `sudo pacman -U <built-pkg>`. Confirmed 2026-07-23 installing unityhub 3.19.5.
- **KWin rule syntax:** KDE 6 uses a different window rule syntax than KDE 5. Use the System Settings GUI for rules rather than hand-editing config files when possible.
- **Wayland vs X11:** Some apps may need `QT_QPA_PLATFORM=wayland` or `GDK_BACKEND=wayland` environment variables.
- **Plasma restart:** `plasmashell --replace` keeps the session alive. Killing plasmashell directly can crash the desktop.
