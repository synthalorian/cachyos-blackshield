# Image Optimization Quality Notes

Session-tested compression results for a 1254×1254 synthwave illustration (complex gradients, neon glows, text, mascot character).

## Test Matrix

| Colors | Resize | Dither | Result | Quality |
|--------|--------|--------|--------|---------|
| Original | 1254×1254 | — | 2.3MB | Baseline |
| Lossless (IM) | 1254×1254 | — | 2.2MB | Identical |
| 256 | 1254×1254 | FloydSteinberg | 1.6MB | Excellent |
| 192 | 1024×1024 | FloydSteinberg | 1.1MB | Excellent |
| 128 | 1254×1254 | FloydSteinberg | 1.4MB | Excellent |
| **96** | **1024×1024** | **FloydSteinberg** | **935K** | **Excellent — sweet spot** |
| 64 | 1024×1024 | FloydSteinberg | 295K | Banding in gradients, posterization on skin, glow artifacts |

## Key Findings

- **96 colors at 1024×1024** is the sweet spot for complex illustrations with gradients (synthwave, neon, sunsets). File size drops ~60% with no visible quality loss.
- **64 colors** introduces noticeable banding in smooth gradients and "dirty" neon glows. Only acceptable for flat icons without gradients.
- **Floyd-Steinberg dithering is essential** — without it, palette reduction causes harsh color stepping.
- **Resize first, then palette** — reversing the order causes blocky artifacts.
- For **flat UI icons** (no gradients), 32-64 colors is usually fine.
- For **photographs**, skip palette reduction entirely — use JPEG or WebP.

## ImageMagick Flags Reference

```bash
magick input.png \
  -resize 1024x1024 \              # Step 1: resize
  -colors 96 \                      # Step 2: palette reduction
  -dither FloydSteinberg \          # Essential: smooth color transitions
  -define png:compression-level=9 \ # Max PNG compression
  output.png
```

## When to Use What

| Image Type | Approach | Expected Reduction |
|------------|----------|-------------------|
| Flat icon / logo | 32-64 colors + dither | 70-90% |
| Gradient illustration | 96-128 colors + dither + resize | 50-70% |
| Screenshot | Lossless (oxipng) or WebP | 20-40% |
| Photo | JPEG 92% or WebP 85% | 60-80% |
| App store icon | 1024×1024, 96 colors, dither | ~60% |
