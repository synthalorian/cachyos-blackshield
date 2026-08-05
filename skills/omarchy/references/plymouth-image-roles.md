# Plymouth Image Roles & Generation

## Image Inventory

All images live in `/usr/share/plymouth/themes/<name>/`. Each serves a specific role:

| Image | Size | Role |
|-------|------|------|
| `logo.png` | 800×188 | Centered logo/symbol above the entry |
| `entry.png` | 286×48 | Password entry field (border + fill) |
| `lock.png` | 84×96 | Lock icon left of entry field |
| `bullet.png` | 14×14 | Password character dot (scaled to 7×7) |
| `progress_bar.png` | 300×10 | Fill bar that grows during boot |
| `progress_box.png` | 300×10 | Track/container for the fill bar |
| `background.png` | 100×100 | Tiled background fallback |
| `preview-unlock.png` | 1920×1080 | Shutdown/suspend background overlay |

## Color Recoloring with PIL

Use `Image.open().convert('RGBA')`, then iterate pixels. Two patterns:

**Recolor all non-transparent pixels to a solid color:**
```python
from PIL import Image
img = Image.open('entry.png').convert('RGBA')
pixels = img.load()
target = (255, 255, 102)  # YELLOW
for y in range(img.height):
    for x in range(img.width):
        r, g, b, a = pixels[x, y]
        if a > 0:
            pixels[x, y] = (*target, a)
img.save('entry.png')
```

**Recolor a specific source color (preserving others):**
```python
# Replace white-ish border pixels with yellow
old = (192, 202, 245)  # original color
new = (255, 255, 102)  # YELLOW
tolerance = 10
for y in range(h):
    for x in range(w):
        r, g, b, a = pixels[x, y]
        if abs(r-old[0]) <= tolerance and abs(g-old[1]) <= tolerance and abs(b-old[2]) <= tolerance:
            pixels[x, y] = (*new, a)
```

## Key Files Beyond Images

- `<name>.plymouth` — theme metadata. Set `ConsoleLogBackgroundColor=0x<hex>` for fallback bg
- `<name>.script` — Plymouth script. Controls background color with:
  ```
  Window.SetBackgroundTopColor(0.141, 0.000, 0.216);   # #240037 in 0.0-1.0 float
  Window.SetBackgroundBottomColor(0.141, 0.000, 0.216);
  ```

## Initramfs

After ANY change to Plymouth theme files (images, script, or config):
```bash
sudo mkinitcpio -P
```
Plymouth bundles its theme into the initramfs at build time. Without a rebuild, changes don't appear on boot.

## Install Path

The install script for the complete-omarchy-synthwave-84 repo:
1. Copies `plymouth/` dir to `/usr/share/plymouth/themes/<name>/`
2. Sets `Theme=<name>` in `/etc/plymouth/plymouthd.conf`
3. User must run `sudo mkinitcpio -P` after install (or script does it)

## Synthwave84 Plymouth Palette

| Element | Original Color | Synthwave84 Color |
|---------|---------------|-------------------|
| Background | `#3E175F` | `#240037` (surface) |
| Logo | `#7A00AC` purple | `#0A011A` dark purple |
| Entry frame | `#C0CAF5` bluish white | `#FFFF66` yellow |
| Progress bar | `#7A00AC` purple | `#FFFF66` yellow |
| Progress box | `#292E42` dark | `#0A011A` dark purple |
| Lock icon | `#C0CAF5` blur white | `#FFFF66` yellow |
| Bullets | `#7A00AC` purple | `#FFFF66` yellow |
| Shutdown bg | `#242536` dark | `#240037` surface |
