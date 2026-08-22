---
name: system-design
description: >
  System design skills: Plymouth splash screens, SDDM login themes,
  hyprlock backgrounds, initramfs rebuild, boot chain color unification.
  Triggers: Plymouth, SDDM, splash screen, login screen, lock screen,
  boot animation, shutdown screen, Plymouth theme, boot colors,
  shutdown color mismatch, Plymouth preview-unlock, initramfs.
category: system-design
---

# System Design Skills

## Plymouth + SDDM + Hyprlock Color Unification

### Trigger
User wants splash/shutdown/login/lock screens to share the same background color or theme.

### Root Cause Analysis

Plymouth uses `preview-unlock.png` during **shutdown**, **suspend**, and **unlock** phases. This is NOT the same screen as boot — Plymouth auto-loads this image as the background overlay. During boot, Plymouth uses `SetBackgroundTopColor/SetBackgroundBottomColor` from the script.

The `preview-unlock.png` background color is often wrong because:
- It was generated from a different source image during theme creation
- Plymouth themes are often copied/converted without regenerating the preview
- The preview PNG has a baked-in background that doesn't match the script's `SetBackground*Color` values

### Verification Steps

1. Find the Plymouth theme being used:
   ```bash
   cat /etc/plymouth/plymouthd.conf
   ```

2. Check the script background colors:
   ```bash
   grep "SetBackground" /usr/share/plymouth/themes/<theme>/<theme>.script
   ```

3. Check the preview-unlock.png background:
   ```python
   python3 -c "
   from PIL import Image
   from collections import Counter
   img = Image.open('/usr/share/plymouth/themes/<theme>/preview-unlock.png')
   # Corners should be pure background
   corners = [(0,0), (img.size[0]-1, 0), (0, img.size[1]-1), (img.size[0]-1, img.size[1]-1)]
   for x, y in corners:
       print(img.getpixel((x, y)))
   "
   ```

4. Compare with SDDM/hyprlock colors in the theme's `.conf` or `.toml` files.

### Fix Procedure

1. Write a Python script to swap the background color:
   ```python
   from PIL import Image
   old_bg = (r_old, g_old, b_old)   # hex extracted from preview-unlock.png
   new_bg = (r_new, g_new, b_new)   # hex from theme's SetBackground*Color
   img = Image.open(path).convert('RGBA')
   pixels = img.load()
   w, h = img.size
   for y in range(h):
       for x in range(w):
           r, g, b, a = pixels[x, y]
           if (r, g, b) == old_bg:
               pixels[x, y] = (new_bg[0], new_bg[1], new_bg[2], a)
   img.save(path)
   ```

2. Run with `sudo` (system plymouth dir requires root).

3. Rebuild initramfs:
   ```bash
   sudo mkinitcpio -P
   ```

### Key Files

- `/etc/plymouth/plymouthd.conf` — active theme
- `/usr/share/plymouth/themes/<theme>/<theme>.script` — Plymouth script with SetBackground colors
- `/usr/share/plymouth/themes/<theme>/preview-unlock.png` — shutdown/suspend background overlay
- `~/.local/share/omarchy/default/plymouth/preview-unlock.png` — omarchy source (copy to system dir if needed)

### Important Notes

- Plymouth script does NOT reference `preview-unlock.png` directly — it's loaded by Plymouth itself during non-boot phases
- Only swap the **exact** background color — don't touch UI elements
- Verify corners after fix to confirm the swap worked
- If the preview-unlock.png doesn't exist in the omarchy source, you may need to generate it from the theme's wallpaper

### Related: SDDM Themes

SDDM themes are QML-based. Background color is set in `Main.qml`:
```qml
Rectangle {
    color: "#HEXVALUE"  // root background
    ...
}
```

User themes go in `~/.config/sddm/themes/<name>/`. System themes are in `/usr/share/sddm/themes/<name>/`.

### Related: Hyprlock Themes

Hyprlock uses `colors.conf` or inline variables:
```ini
$color = rgba(R,G,B,1.0)
```

### Related: Limine Bootloader Theming

Config: repo `~/Projects/active/cachyos-blackshield/configs/limine/limine.conf` → live `/boot/limine.conf` (needs sudo; `/boot` not user-readable). Full option docs: `/usr/share/doc/limine/CONFIG.md`.

- `term_background` accepts **TTRRGGBB** (TT = alpha) — translucent terminal over wallpaper, e.g. `C0240037`. The headline theming trick.
- `term_font_scale: 2x2` for readable text on 1440p+ panels; `term_margin` + `term_margin_gradient` fade the terminal into the wallpaper.
- Selection highlight = `term_background_bright`/`term_foreground_bright` (hot pink bg + dark text works great).
- Countdown digit color = `interface_help_colour_bright`; branding = `interface_branding`/`_colour`.
- **Deploy pattern:** the auto-generated entry section (everything from `comment: machine-id=` / `/+` down) is owned by limine-entry-tool/limine-snapper-sync and the LIVE file is often newer than the repo copy. Splice only the header/theme block into both files — never blanket-copy repo → /boot. Back up first: `cp /boot/limine.conf /boot/limine.conf.bak-<tag>`.
- No `mkinitcpio` or `limine-install` needed for theme changes — limine.conf is read from the ESP at boot.
- Wallpaper: PNG, `wallpaper: boot():/file.png`, `wallpaper_style: stretched`. Design with a dark center (menu text lands there); measure center pixel brightness with PIL before shipping.

### Related: Waybar

Waybar uses CSS — check `~/.config/waybar/style.css` for `.waybar` background properties.
