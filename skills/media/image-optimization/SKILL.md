---
title: Image Optimization
name: image-optimization
description: Compress and optimize images (PNG, JPEG, WebP) for deployment, icons, and web assets while preserving visual quality. Covers CLI tools, palette reduction, resize strategies, and quality verification.
triggers:
  - compress image
  - optimize png
  - reduce image size
  - make image smaller
  - shrink icon
  - image under X mb
  - compress screenshot
  - optimize for web
  - reduce file size
  - image compression
  - pngquant
  - oxipng
  - imagemagick compress
---

# Image Optimization

Compress images for deployment, app icons, README assets, and web use while holding quality.

## Quick Reference

| Goal | Command | Notes |
|------|---------|-------|
| Lossless PNG | `oxipng -o 4 --strip safe input.png` | Best first try; no quality loss |
| Palette PNG (photo) | `magick input.png -colors 96 -dither FloydSteinberg -define png:compression-level=9 output.png` | 96-color sweet spot for complex illustrations |
| Palette PNG (flat/icon) | `magick input.png -colors 32 -dither FloydSteinberg output.png` | Fewer colors for flat designs |
| Resize + compress | `magick input.png -resize 1024x1024 -colors 96 ... output.png` | Resize first, then palette |
| JPEG high quality | `magick input.png -quality 92 output.jpg` | For photos, not icons |
| WebP | `cwebp -q 85 input.png -o output.webp` | Best web format; ~30% smaller than PNG |

## Workflow

### 1. Assess the Image

```bash
ls -lh input.png
file input.png
# Note: dimensions, color depth, current size
```

### 2. Try Lossless First

```bash
# oxipng — best lossless PNG compressor
oxipng -o 4 --strip safe input.png

# If not available, ImageMagick lossless
magick input.png -define png:compression-level=9 output.png
```

### 3. If Still Too Big: Palette Reduction

For illustrations, icons, and graphics with limited color ranges:

```bash
# 256 colors — often visually identical for icons
magick input.png -colors 256 -dither FloydSteinberg -define png:compression-level=9 output.png

# 128 colors — slight reduction, usually unnoticeable
magick input.png -colors 128 -dither FloydSteinberg -define png:compression-level=9 output.png

# 96 colors — sweet spot for complex synthwave/gradient art (see references/quality-notes.md)
magick input.png -colors 96 -dither FloydSteinberg -define png:compression-level=9 output.png

# 64 colors — check for banding first; use only if quality holds
magick input.png -colors 64 -dither FloydSteinberg -define png:compression-level=9 output.png
```

### 4. If Still Too Big: Resize

Resize first, then palette. Resizing after palette causes artifacts.

```bash
magick input.png -resize 1024x1024 -colors 96 -dither FloydSteinberg -define png:compression-level=9 output.png
```

Common icon sizes: 1024×1024 (macOS/iOS), 512×512 (Linux), 192×192 (web).

### 5. Verify Quality

Always visually inspect the result, especially for:
- Gradient banding (sunsets, skies, skin tones)
- Neon glow artifacts
- Text edge crispness
- Color posterization

Use `vision_analyze` to compare original vs. compressed if unsure.

## Tool Availability

| Tool | Install | When to Use |
|------|---------|-------------|
| `oxipng` | `cargo install oxipng` | Lossless PNG; always try first |
| `pngquant` | `pacman -S pngquant` | Palette reduction; better quality than ImageMagick at same file size |
| `cwebp` | `pacman -S libwebp` | Web deployment; smallest files |
| `magick` / `convert` | `pacman -S imagemagick` | Universal fallback; resize, palette, format conversion |

## Pitfalls

- **Resize AFTER palette** — causes blocky artifacts. Always resize first.
- **JPEG → PNG** — PNG from JPEG is larger than necessary; use WebP or keep JPEG.
- **Ignoring dithering** — without `-dither FloydSteinberg`, palette reduction causes harsh banding.
- **Over-compressing text** — text edges degrade faster than photographic areas; use more colors if text is critical.
- **Forgetting `--strip safe`** — oxipng removes metadata; safe strips EXIF/comments without affecting rendering.

## References

- `references/quality-notes.md` — Session-tested color counts and quality thresholds for specific image types.
