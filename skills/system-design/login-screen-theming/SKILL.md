---
name: login-screen-theming
description: Use when theming the boot login screen (plasmalogin/SDDM) **or Limine bootloader configuration**.
---

# Login Screen Theming (plasmalogin / SDDM)

## Step 0: Identify the actual display manager — ALWAYS FIRST

Never assume SDDM. Modern CachyOS/Plasma 6 systems use **Plasma Login Manager**, and SDDM config files can linger as dead config that silently does nothing.

```bash
systemctl status display-manager --no-pager   # plasmalogin.service vs sddm.service
pacman -Q sddm plasma-login-manager
```

**Pitfall (burned once):** user had `font=3270 Nerd Font` in `/usr/share/sddm/themes/breeze/theme.conf.user` and wondered why the login font never changed — SDDM wasn't installed; plasmalogin was running. Also note the breeze SDDM theme's QML ignores the `font=` key anyway (it hardcodes `Kirigami.Theme.defaultFont`), so that key is doubly useless.

## plasma-login-manager (plasmalogin) — modern path

**Architecture:** the login screen is a real mini Plasma/Wayland session (kwin_wayland + wallpaper plugin + `/usr/lib/plasma-login-greeter`) running as user `plasmalogin` with home `/var/lib/plasmalogin` (mode 750, needs sudo to inspect). Machine config: `/etc/plasmalogin.conf` (autologin, wallpaper via `[Greeter][Wallpaper]...` sections). There is no QML theme directory to edit.

**Key consequence:** greeter fonts/colors come from the GREETER USER's kdeglobals — `/var/lib/plasmalogin/.config/kdeglobals` — not the logged-in user's config and not any theme.conf.

### Set the login-screen font

Merge keys (never wholesale-overwrite; other keys may exist):

```bash
sudo bash -c '
install -d -m 700 -o plasmalogin -g plasmalogin /var/lib/plasmalogin/.config
K=/var/lib/plasmalogin/.config/kdeglobals
touch "$K"
kwriteconfig6 --file "$K" --group General --key font "FAMILY,10,-1,5,400,0,0,0,0,0,0,0,0,0,0,1"
# also set for consistency: fixed, menuFont, toolBarFont, activeFont, smallestReadableFont
chown plasmalogin:plasmalogin "$K"
sudo -u plasmalogin fc-match "FAMILY"   # verify the greeter user can resolve it
'
```

- kdeglobals font string format (Plasma 6): `Family,size,-1,5,400,0,0,0,0,0,0,0,0,0,0,1`. Easiest: copy values verbatim from the user's own `~/.config/kdeglobals` (`grep -i font ~/.config/kdeglobals`).
- Fonts must be in a world-readable system path (`/usr/share/fonts`, `/usr/local/share/fonts`) — the user's `~/.local/share/fonts` is invisible to the greeter. Check perms: `stat -c '%a %U' <dir>` should be 755 root, files 644.
- GUI alternative: System Settings → Colors & Themes → Login Screen (Plasma Login Manager) → "Apply Plasma Settings" (kcm_plasmalogin + kauth) syncs the user's fonts/colors/wallpaper to the greeter account.
- Changes appear at next greeter start (logout/reboot). Do NOT restart plasmalogin.service to test — it kills the active session.

## Legacy SDDM path (only if sddm.service is actually running)

- Themes: `/usr/share/sddm/themes/<name>/`, user overrides `~/.config/sddm/themes/<name>/`.
- Background color: root `Rectangle { color: "#HEX" }` in `Main.qml`.
- `theme.conf.user` merges over `theme.conf`, but ONLY keys the QML actually reads take effect — grep the theme's QML for `config.<key>` before trusting any conf key.
- To force a font in breeze, copy the theme to `/usr/share/sddm/themes/breeze-custom` and set `font.family` on the root item in Main.qml (QML font inheritance covers children that don't override family).
- Test without reboot: `sddm-greeter-qt6 --test-mode --theme /usr/share/sddm/themes/<name>` from a running session.

## Limine bootloader (EFI systems)

Limine is its own theming layer between firmware and Linux — separate from plasmalogin and SDDM.

### Config location

- Source of truth: `~/Projects/active/cachyos-setup/configs/limine/limine.conf`
- Deployed target: `/boot/limine.conf`
- Deploy command: `sudo cp -f <source> /boot/limine.conf && sudo limine-install`

### Key keys

| Key | Purpose |
|---|---|
| `term_background` | Terminal/text overlay RGBA hex; only used where there's no wallpaper coverage |
| `term_foreground` | Primary menu text color |
| `term_foreground_bright` | Selection/highlight text color |
| `interface_branding` | Bottom banner text |
| `interface_branding_colour` | Banner text color |
| `interface_help_colour` | Help text color |
| `wallpaper:` | `boot():/limine-splash.png` or `boot():/limine-splash-synthwave.png` |

### Palette rules

- Hex values are **8-digit ARGB without a leading `#`**.
- Valid: `240037`, `FF7EDB`, `03EDF9`.
- **Pitfall:** stray bytes prefix (`E6240037`) parse as an entirely different color. If the terminal overlay looks uniformly muddy or washed out, grep for stray characters before `/` in hex lines.
- `term_background` must use a **6-digit** value (`240037`), not 8-digit, when only opacity=FF is intended.

### Contrast over a busy splash image

- Hot pink (`FF7EDB`) and hot red (`FE4450`) over a detailed synthwave wallpaper = unreadable.
- `term_foreground: FFFFFF` reads everywhere but loses aesthetic.
- **Preferred:** an in-palette high-contrast cyan like `03EDF9` — already part of term_palette slot 7, matches synthwave cyan, and pops on dark purple.
- `interface_branding_colour` can stay white (`FFFFFF`) for the bottom banner because it sits below the splash image coverage.
- **Order of operations:** if legibility is broken, fix `term_background` first. A malformed overlay will swamp both the splash and the text. Valid 6-digit BG (`240037`) + cyan FG (`03EDF9`) on dark splash = readable without wrecking the neon.

### Splash image notes

- Limine draws the wallpaper first, then a terminal-text overlay on top.
- Setting only font color does nothing if `term_background` is malformed — fix background before foreground.
- If the image itself looks corrupted: regenerate or verify the PNG is valid (`file <png>`); Limine requires a real PNG, not a JPEG renamed.
- Handoff script copies two splash files: `limine-splash-synthwave.png` → `limine-splash.png` fallback. Keep both in sync if you update the image.
