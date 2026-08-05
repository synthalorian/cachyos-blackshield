# Plymouth Shutdown/Suspend Color Mismatch

## The Problem

Plymouth uses the same `synthwave84` script for boot, shutdown, suspend, and unlock. The script sets background via `SetBackgroundTopColor/SetBackgroundBottomColor` — but Plymouth's **shutdown and suspend phases** ignore these color commands and instead render `preview-unlock.png` as the background overlay. If that image was generated from a different source image (or the Plymouth theme was created with a different default background), you'll see a color mismatch between:

- Boot splash (uses `SetBackgroundTopColor` → your theme color)
- Shutdown/suspend screen (uses `preview-unlock.png` → wrong color)

## How to Detect

```python
# Quick check: sample corner pixels of preview-unlock.png
from PIL import Image
img = Image.open('/usr/share/plymouth/themes/<theme>/preview-unlock.png')
print(img.getpixel((0, 0)))  # corner should be your theme's background
```

If the corner color differs from your theme's `$color` or `ConsoleLogBackgroundColor`, the shutdown screen will look different.

## The Fix

Replace the background pixels in `preview-unlock.png` with your theme's correct color using a Python script:

```bash
# 1. Create fix script (needs sudo)
sudo tee /tmp/fix-plymouth-bg.py << 'PYEOF'
from PIL import Image
import os

old_bg = (26, 27, 38)   # WRONG color found in corners
new_bg = (36, 0, 55)    # Your theme's correct color (e.g., #240037)

files_to_fix = [
    '/usr/share/plymouth/themes/<theme>/preview-unlock.png',
    os.path.expanduser('~/.local/share/omarchy/default/plymouth/preview-unlock.png'),
]

for f in files_to_fix:
    if not os.path.exists(f):
        continue
    img = Image.open(f).convert('RGBA')
    pixels = img.load()
    w, h = img.size
    changed = 0
    for y in range(h):
        for x in range(w):
            r, g, b, a = pixels[x, y]
            if (r, g, b) == old_bg:
                pixels[x, y] = (new_bg[0], new_bg[1], new_bg[2], a)
                changed += 1
    img.save(f)
    print(f"Fixed: {f} ({changed} pixels changed)")
PYEOF

# 2. Run it (requires write access to /usr/share/plymouth/)
sudo python3 /tmp/fix-plymouth-bg.py

# 3. Rebuild initramfs so Plymouth picks it up
sudo mkinitcpio -P

# 4. Reboot to verify
```

## Key Files

- `/etc/plymouth/plymouthd.conf` — active theme (`Theme=synthwave84`)
- `/usr/share/plymouth/themes/<theme>/preview-unlock.png` — **shutdown/suspend background image** (the culprit)
- `/usr/share/plymouth/themes/<theme>/<theme>.script` — Plymouth script (sets `SetBackgroundTopColor` only for boot)
- `/usr/share/plymouth/themes/<theme>/<theme>.plymouth` — theme metadata

## Pitfalls

- `preview-unlock.png` is **not referenced** in the script — Plymouth loads it automatically during shutdown/suspend phases. This is the #1 reason for color mismatches.
- The boot splash uses `SetBackgroundTopColor/SetBackgroundBottomColor` (script-driven), while shutdown uses the **pre-rendered PNG overlay** (theme-driven). They are completely separate rendering paths.
- Always rebuild initramfs (`mkinitcpio -P`) after changing Plymouth files — Plymouth bundles its theme into the initramfs at build time.
