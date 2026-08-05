#!/bin/bash
# Swap background color in Plymouth preview-unlock.png
# Usage: sudo fix-plymouth-preview-bg.sh <old_hex> <new_hex> <theme_name>
# Example: sudo fix-plymouth-preview-bg.sh 1a1b26 240037 synthwave84

set -euo pipefail

if (( $# != 3 )); then
    echo "Usage: $0 <old_hex> <new_hex> <theme_name>"
    echo "Example: $0 1a1b26 240037 synthwave84"
    exit 1
fi

OLD_HEX=$(echo "$1" | tr '[:upper:]' '[:lower:]')
NEW_HEX=$(echo "$2" | tr '[:upper:]' '[:lower:]')
THEME="$3"

# Convert hex to RGB
old_r=$((16#${OLD_HEX:0:2}))
old_g=$((16#${OLD_HEX:2:2}))
old_b=$((16#${OLD_HEX:4:2}))
new_r=$((16#${NEW_HEX:0:2}))
new_g=$((16#${NEW_HEX:2:2}))
new_b=$((16#${NEW_HEX:4:2}))

cat << PYEOF | sudo python3
from PIL import Image
import os

old_bg = ($old_r, $old_g, $old_b)
new_bg = ($new_r, $new_g, $new_b)

files_to_fix = [
    '/usr/share/plymouth/themes/$THEME/preview-unlock.png',
    os.path.expanduser(f'~/.local/share/omarchy/default/plymouth/preview-unlock.png'),
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
