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

### Related: Waybar

Waybar uses CSS — check `~/.config/waybar/style.css` for `.waybar` background properties.
