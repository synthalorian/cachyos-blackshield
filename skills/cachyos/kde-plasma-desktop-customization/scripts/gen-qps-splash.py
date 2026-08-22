#!/usr/bin/env python3
"""Generate a Plasma QPS splash plasmoid directory from a PNG image.

Usage:
    python3 gen-qps-splash.py <splash-image.png> [output-dir]

Output layout (user-local, no sudo):
    <output-dir>/<plasmoid-name>/
    ├── metadata.desktop
    └── contents/
        ├── plasmoid.desktop
        ├── config.xml
        └── ui/
            └── splash.png

The plasmoid-name is derived from the image filename (stem). Deploy to:
    ~/.local/share/plasma/look-and-feel/<active-L&F>/contents/splash/
then restart plasma: plasmashell --replace

The L&F name is whatever kreadconfig6 --group KDE --key LookAndFeelPackage returns.
"""

import os
import sys
import shutil
from pathlib import Path

KDE_PLASMA_LOOK_AND_FEEL = os.environ.get(
    "KDE_PLASMA_L&F_DIR",
    os.path.expanduser("~/.local/share/plasma/look-and-feel"),
)


def slugify(name: str) -> str:
    return "".join(c if c.isalnum() or c == "-" else "-" for c in name).strip("-")


def make_qpsplash(
    image_path: str,
    base_dir: str | None = None,
    plasmoid_name: str | None = None,
) -> Path:
    """Create a QPS splash plasmoid directory and return its path."""
    img = Path(image_path).expanduser().resolve()
    if not img.is_file():
        raise FileNotFoundError(f"Image not found: {img}")

    base = Path(base_dir or KDE_PLASMA_LOOK_AND_FEEL).expanduser().resolve()
    name = plasmoid_name or slugify(img.stem)
    out = base / name

    contents = out / "contents"
    ui = contents / "ui"
    for d in (out, contents, ui):
        d.mkdir(parents=True, exist_ok=True)

    shutil.copy(img, ui / "splash.png")

    metadata = f"""[Desktop Entry]
Type=Service
ServiceTypes=Plasma/Splash
Name=Blackshield Mercenary
Comment=Blacksteel + blood-red cross potent — Caerleon after dark.
X-KDE-PluginInfo-Author=synth
X-KDE-PluginInfo-Email=
X-KDE-PluginInfo-Name={name}
X-KDE-PluginInfo-Version=1.0
X-KDE-PluginInfo-Category=
X-KDE-PluginInfo-Depends=
X-KDE-PluginInfo-License=
X-KDE-PluginInfo-EnabledByDefault=true
"""
    (out / "metadata.desktop").write_text(metadata)

    desktop = f"""[Desktop Entry]
Type=Service
ServiceTypes=Plasma/Splash
Icon={name}
X-Plasma-Splash=contents/ui/splash.png
X-KDE-ServiceTypes=Plasma/Splash
"""
    (contents / "plasmoid.desktop").write_text(desktop)

    config = """<?xml version="1.0" encoding="UTF-8"?>
<kcfg xmlns="http://www.kde.org/standards/kcfg/1.0"
      xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
      xsi:schemaLocation="http://www.kde.org/standards/kcfg/1.0
                          http://www.kde.org/standards/kcfg/1.0/kcfg.xsd">
  <kcfgfile name=""/>
</kcfg>
"""
    (contents / "config.xml").write_text(config)

    print(f"Created QPS splash plasmoid: {out}")
    print(f"  Image: {ui / 'splash.png'}")
    print(f"  Deploy to: {base / 'contents' / 'splash'}")
    print(f"  Restart plasma: plasmashell --replace")
    return out


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print(f"Usage: {sys.argv[0]} <splash-image.png> [output-dir]", file=sys.stderr)
        sys.exit(1)
    make_qpsplash(sys.argv[1], sys.argv[2] if len(sys.argv) > 2 else None)
