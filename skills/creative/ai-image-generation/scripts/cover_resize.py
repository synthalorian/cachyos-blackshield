#!/usr/bin/env python3
"""Cover-resize an image to an exact target size without distorting aspect ratio.

Usage:
  python cover_resize.py INPUT OUTPUT [WIDTH HEIGHT]

Defaults: 2560x1440. Saves PNG when OUTPUT ends in .png, otherwise PIL infers format.
"""
from pathlib import Path
import sys
from PIL import Image, ImageFilter

def cover_resize(src: Path, dst: Path, size=(2560, 1440)) -> None:
    im = Image.open(src).convert("RGB")
    tw, th = size
    w, h = im.size
    scale = max(tw / w, th / h)
    nw, nh = round(w * scale), round(h * scale)
    im = im.resize((nw, nh), Image.Resampling.LANCZOS)
    left = (nw - tw) // 2
    top = (nh - th) // 2
    im = im.crop((left, top, left + tw, top + th))
    im = im.filter(ImageFilter.UnsharpMask(radius=1.2, percent=80, threshold=2))
    dst.parent.mkdir(parents=True, exist_ok=True)
    im.save(dst, optimize=True)

if __name__ == "__main__":
    if len(sys.argv) < 3:
        raise SystemExit(__doc__)
    src = Path(sys.argv[1]).expanduser()
    dst = Path(sys.argv[2]).expanduser()
    width = int(sys.argv[3]) if len(sys.argv) > 3 else 2560
    height = int(sys.argv[4]) if len(sys.argv) > 4 else 1440
    cover_resize(src, dst, (width, height))
    print(f"{dst} {width}x{height}")
