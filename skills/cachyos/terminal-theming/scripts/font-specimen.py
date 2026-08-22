#!/usr/bin/env python3
"""Render a font specimen PNG from the ACTUAL installed font files.

Deterministic visual proof that a family (and its nerd-symbol fallback) renders
correctly — useful after font installs/swaps when desktop screenshots aren't
reachable (Wayland accessibility gaps, headless sessions).

Usage:
    python3 font-specimen.py                          # Orbitron + Symbols Nerd Font
    python3 font-specimen.py --family "JetBrains Mono" --out /tmp/spec.png
    python3 font-specimen.py --symbols-family "Symbols Nerd Font Mono"

Requires: pillow (pip install --user pillow). Resolves font files via fc-match,
so it tests what fontconfig would actually hand an application.
"""
import argparse
import subprocess
import sys


def fc_file(query: str) -> str:
    out = subprocess.run(
        ["fc-match", "-f", "%{file}", query],
        capture_output=True, text=True, check=True,
    ).stdout.strip()
    if not out:
        sys.exit(f"fc-match resolved nothing for: {query}")
    return out


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--family", default="Orbitron")
    ap.add_argument("--symbols-family", default="Symbols Nerd Font")
    ap.add_argument("--out", default="/tmp/font-specimen.png")
    ap.add_argument("--bg", default="#240037")
    ap.add_argument("--fg", default="#FF7EDB")
    args = ap.parse_args()

    from PIL import Image, ImageDraw, ImageFont

    # Title face: heaviest available, falling back down the weight ladder.
    title_file = None
    for style in ("Black", "ExtraBold", "Bold", "Regular"):
        try:
            title_file = fc_file(f"{args.family}:style={style}")
            break
        except SystemExit:
            continue
    reg_file = fc_file(f"{args.family}:style=Regular")
    bold_file = fc_file(f"{args.family}:style=Bold")
    sym_file = fc_file(args.symbols_family)

    def hex2rgb(h: str):
        h = h.lstrip("#")
        return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))

    img = Image.new("RGB", (1100, 560), hex2rgb(args.bg))
    d = ImageDraw.Draw(img)
    fg = hex2rgb(args.fg)

    d.text((40, 30), args.family.upper(), font=ImageFont.truetype(title_file, 64), fill=fg)
    d.text((40, 130), "The quick brown fox 0123456789",
           font=ImageFont.truetype(reg_file, 30), fill=(255, 255, 255))
    d.text((40, 185), f"Bold: {args.family} // SPECIMEN",
           font=ImageFont.truetype(bold_file, 30), fill=(143, 0, 255))
    d.text((40, 250), f"Nerd glyphs ({args.symbols_family}):",
           font=ImageFont.truetype(reg_file, 30), fill=(255, 255, 255))
    # PUA codepoints spanning powerline, octicons, devicons, weather, FA, mdicons.
    glyphs = "\ue0b0 \uf015 \uf07c \uf120 \uf126 \uf489 \uf7d9 \ue795 \ue62b \ufa85 \U000f06a9 \U000f0764"
    d.text((40, 300), glyphs,
           font=ImageFont.truetype(sym_file, 30), fill=(243, 231, 15))
    d.text((40, 380), f"regular: {reg_file}", font=ImageFont.truetype(reg_file, 18), fill=(150, 90, 190))
    d.text((40, 415), f"bold:    {bold_file}", font=ImageFont.truetype(reg_file, 18), fill=(150, 90, 190))
    d.text((40, 450), f"symbols: {sym_file}", font=ImageFont.truetype(reg_file, 18), fill=(150, 90, 190))
    d.text((40, 500), "font-specimen.py // synthclaw",
           font=ImageFont.truetype(reg_file, 20), fill=(120, 70, 160))

    img.save(args.out)
    print(args.out)


if __name__ == "__main__":
    main()
