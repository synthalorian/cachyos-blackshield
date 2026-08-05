# Tauri Icon Generation Recipe

## The Problem

Tauri 2's `tauri::generate_context!()` macro validates icon files at compile time and **requires RGBA PNG format**. ImageMagick's `convert`/`magick convert` strips the alpha channel by default, so resizing with it produces RGB PNGs that fail with:

```
error: proc macro panicked
  --> src-tauri/src/lib.rs:182:14
   |
182 |         .run(tauri::generate_context!())
   |              ^^^^^^^^^^^^^^^^^^^^^^^^^^
   |
   = help: message: icon .../32x32.png is not RGBA
```

## The Fix: Python Pillow

```python
from PIL import Image

src = Image.open('source.png').convert('RGBA')

# All standard Tauri icon sizes
sizes = {
    '32x32.png': 32,
    '128x128.png': 128,
    '128x128@2x.png': 256,
    'icon.png': 512,
    # Windows Store variants
    'Square30x30Logo.png': 30,
    'Square44x44Logo.png': 44,
    'Square71x71Logo.png': 71,
    'Square89x89Logo.png': 89,
    'Square107x107Logo.png': 107,
    'Square142x142Logo.png': 142,
    'Square150x150Logo.png': 150,
    'Square284x284Logo.png': 284,
    'Square310x310Logo.png': 310,
    'StoreLogo.png': 300,
}

for fname, size in sizes.items():
    img = src.resize((size, size), Image.LANCZOS)
    img.save(fname, 'PNG')

# icon.ico (multi-resolution Windows icon)
ico_sizes = [16, 32, 48, 256]
ico_images = [src.resize((s, s), Image.LANCZOS) for s in ico_sizes]
ico_images[0].save('icon.ico', 'ICO', sizes=[(i.width, i.height) for i in ico_images])
```

## Why This Happens

- **ImageMagick** defaults to RGB output when resizing — it discards the alpha channel silently.
- **Pillow** preserves alpha when you explicitly call `.convert('RGBA')` and `.save('PNG')` (PNG supports RGBA natively).
- **Tauri** runs a pixel-format validation that rejects any PNG without a valid alpha channel.

## Icon Sizes Reference

| File | Size | Platform |
|------|------|----------|
| `32x32.png` | 32×32 | Linux, Windows |
| `128x128.png` | 128×128 | Linux, macOS, Windows |
| `128x128@2x.png` | 256×256 | Retina/HiDPI |
| `icon.png` | 512×512 | General purpose, HiDPI |
| `icon.ico` | Multi-res 16-256 | Windows |
| `icon.icns` | Variable | macOS (generate on macOS) |
| `Square*.png` | 30-310 | Windows Store |
| `StoreLogo.png` | 300×300 | Windows Store |

## Quick One-Liner (all PNG sizes from source)

```bash
python3 -c "
from PIL import Image; import os
src = Image.open('$SOURCE').convert('RGBA')
d = '$DEST'
for f, s in {'32x32.png':32,'128x128.png':128,'128x128@2x.png':256,'icon.png':512}.items():
    src.resize((s,s), Image.LANCZOS).save(os.path.join(d, f), 'PNG')
    print(f'{f} ({s}x{s})')
"
```