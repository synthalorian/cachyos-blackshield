#!/usr/bin/env python3
"""gen-synthwave84-ntp.py — stdlib-only synthwave '84 NTP background generator.

Writes a 1920x1080 PNG: deep-purple gradient sky, STRIPED retro sun (slat gaps
widen toward the horizon), soft neon horizon bloom, symmetric perspective grid
floor (exact central vanishing point), dithered against gradient banding.
No PIL/ImageMagick needed. Verified via pixel-column check + vision_analyze.

Usage: python3 gen-synthwave84-ntp.py [out.png]
"""
import struct, zlib, math, os, random, sys

W, H = 1920, 1080
DEEP   = (13, 2, 33)     # 0D0221
BG     = (36, 0, 55)     # 240037
PURP   = (45, 27, 78)    # horizon floor base
MAG    = (255, 0, 255)   # FF00FF
PINK   = (255, 126, 219) # FF7EDB
YELLOW = (243, 231, 15)  # F3E70F

horizon = int(H * 0.70)
sun_cx, sun_cy, sun_r = W / 2.0, float(horizon), 240.0
SPACING = 170.0   # vertical grid line spacing at bottom edge
N_HLINES = 14.0   # horizontal rows in sqrt-perspective space

def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))

def main(out):
    img = bytearray(W * H * 3)
    random.seed(1984)
    for y in range(H):
        fy = (y - horizon) / (H - horizon) if y > horizon else 0.0
        if y <= horizon:
            tt = y / horizon
            row = lerp(DEEP, BG, tt * tt * (3 - 2 * tt))   # smoothstep
        else:
            row = lerp(BG, PURP, fy * fy * (3 - 2 * fy))
        for x in range(W):
            r, g, b = row

            # striped sun — s parameterizes the VISIBLE half (0=top, 1=horizon).
            # PITFALL: dy/sun_r is <= 0 over the whole visible disc (clipped at
            # horizon), so stripes keyed on raw u never fire. Use s = 1 + dy/r.
            dx, dy = x - sun_cx, y - sun_cy
            d = math.sqrt(dx * dx + dy * dy)
            if d < sun_r and y < horizon:
                s = 1.0 + dy / sun_r
                cut = False
                if s > 0.5:
                    p = ((s * s) * 5.0) % 1.0
                    gap = 0.08 + (s - 0.5) * 1.1   # gaps widen toward horizon
                    cut = p < gap
                if not cut:
                    tcol = lerp(YELLOW, MAG, min(1.0, max(0.0, s)))
                    edge = min(1.0, (sun_r - d) / 14.0)
                    r = int(r + (tcol[0] - r) * 0.92 * edge)
                    g = int(g + (tcol[1] - g) * 0.92 * edge)
                    b = int(b + (tcol[2] - b) * 0.92 * edge)

            # soft glow above horizon
            if d < sun_r * 2.2 and y < horizon:
                glow = max(0.0, 1.0 - d / (sun_r * 2.2)) ** 2.4
                r = min(255, int(r + (MAG[0] - r) * glow * 0.28))
                g = min(255, int(g + (MAG[1] - g) * glow * 0.28))
                b = min(255, int(b + (MAG[2] - b) * glow * 0.28))

            # horizon bloom (soft — a hard stripe reads as a sticker edge)
            hd = abs(y - horizon)
            if hd < 40:
                hb = (1.0 - hd / 40.0) ** 2 * 0.5
                r = min(255, int(r + (MAG[0] - r) * hb))
                g = min(255, int(g + (MAG[1] - g) * hb))
                b = min(255, int(b + (MAG[2] - b) * hb))

            # perspective grid below horizon
            if y > horizon and fy > 0.015:
                fade = min(1.0, fy * 4.0)
                off = (x - sun_cx) / fy          # exact vanishing point
                m = off % SPACING
                if m < 1.8 or m > SPACING - 1.8:
                    r, g, b = lerp((r, g, b), PINK, 0.55 * fade)
                hp = (math.sqrt(fy) * N_HLINES) % 1.0  # uniform in sqrt space
                if hp < 0.045:
                    r, g, b = lerp((r, g, b), MAG, 0.6 * fade)

            n = random.randint(-2, 2)  # dither against banding
            i = (y * W + x) * 3
            img[i]   = max(0, min(255, r + n))
            img[i+1] = max(0, min(255, g + n))
            img[i+2] = max(0, min(255, b + n))

    def chunk(tag, data):
        c = struct.pack(">I", len(data)) + tag + data
        return c + struct.pack(">I", zlib.crc32(tag + data) & 0xffffffff)
    raw = b"".join(b"\x00" + bytes(img[y*W*3:(y+1)*W*3]) for y in range(H))
    png = (b"\x89PNG\r\n\x1a\n"
           + chunk(b"IHDR", struct.pack(">IIBBBBB", W, H, 8, 2, 0, 0, 0))
           + chunk(b"IDAT", zlib.compress(raw, 6))
           + chunk(b"IEND", b""))
    with open(out, "wb") as f:
        f.write(png)
    print(out, os.path.getsize(out), "bytes")

if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "ntp_background.png")
