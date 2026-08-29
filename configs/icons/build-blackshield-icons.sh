#!/usr/bin/env bash
# build-blackshield-icons.sh — Forge the Blackshield icon theme.
#
# Builds ~/.local/share/icons/Blackshield-Icons from two installed parents:
#   - Papirus-Dark  (blood-red folders + blood system accent icons)
#   - Nordzy-dark   (full app/mimetype set, reforged steel+blood palette)
#
# Idempotent: wipes and rebuilds the theme dir every run.
# Deps: papirus-icon-theme (pacman), nordzy-icon-theme (AUR), python3.
# After Papirus or Nordzy updates, re-run to pick up new icons.

set -euo pipefail

PAPIRUS=/usr/share/icons/Papirus-Dark
NORDZY=/usr/share/icons/Nordzy-dark
DST="$HOME/.local/share/icons/Blackshield-Icons"

for t in "$PAPIRUS" "$NORDZY"; do
  if [[ ! -d "$t" ]]; then
    echo "MISSING: $t — install papirus-icon-theme and nordzy-icon-theme first" >&2
    exit 1
  fi
done

echo "Forging Blackshield-Icons -> $DST"
rm -rf "$DST"
mkdir -p "$DST"

python3 - "$PAPIRUS" "$NORDZY" "$DST" <<'PYEOF'
import os, re, sys

PAPIRUS, NORDZY, DST = sys.argv[1], sys.argv[2], sys.argv[3]

# ---------------------------------------------------------------- palette map
HEXMAP = {
    # Papirus folder reds -> canon blood family
    "#e25252": "#C1121F", "#bf4b4b": "#8A0E18", "#4f1d1d": "#4A0B10",
    # nord frost blues/cyans -> steel greys
    "#8fbcbb": "#A8ADB3", "#88c0d0": "#8F959C", "#81a1c1": "#767C84", "#5e81ac": "#5C6167",
    # nord aurora reds -> canon blood family
    "#bf616a": "#C1121F", "#b54a55": "#8A0E18",
    # warm aurora -> rusted blood / bone / ash / gunmetal
    "#d08770": "#A52A1E", "#ebcb8b": "#D9D2C5", "#a3be8c": "#82887B", "#b48ead": "#736F78",
    # Papirus system accent blues/teals/greens -> blood
    "#127bdc": "#C1121F", "#1f6394": "#7A1220", "#008374": "#C1121F",
    "#34abf3": "#C1121F", "#00e441": "#C1121F", "#5294e2": "#C1121F", "#3daee9": "#C1121F",
    # nord variant tints
    "#97b67c": "#82887B", "#ad85a5": "#736F78", "#eac57b": "#D9D2C5",
    # nord pastel highlight family -> bone/steel tints
    "#eac7ae": "#D9CFC0", "#e7ddaf": "#D9D2C5", "#caefb9": "#C4C9BC",
    "#b1e3da": "#BFC6C2", "#a5c5ee": "#B9BEC6",
}
def remap(content):
    return re.sub(r"#[0-9a-fA-F]{6}\b",
                  lambda m: HEXMAP.get(m.group(0).lower(), m.group(0)), content)

# --------------------------------------- layer 1: Papirus blood folders
folders = 0
for d in sorted(os.listdir(PAPIRUS)):
    if not re.fullmatch(r"\d+x\d+(@2x)?", d):
        continue
    places = os.path.join(PAPIRUS, d, "places")
    if not os.path.isdir(places):
        continue
    outdir = os.path.join(DST, d, "places")
    for f in sorted(os.listdir(places)):
        full = os.path.join(places, f)
        if os.path.islink(full) or not f.endswith(".svg"):
            continue
        if not (f.startswith("folder-red") or f.startswith("user-red")):
            continue
        canonical = f.replace("-red", "", 1)
        os.makedirs(outdir, exist_ok=True)
        with open(full) as fh:
            content = fh.read()
        with open(os.path.join(outdir, canonical), "w") as fh:
            fh.write(remap(content))
        folders += 1

# --------------------------- layer 1b: places aliases (inode-directory etc.)
aliases = 0
for d in sorted(os.listdir(PAPIRUS)):
    if not re.fullmatch(r"\d+x\d+(@2x)?", d):
        continue
    places = os.path.join(PAPIRUS, d, "places")
    if not os.path.isdir(places):
        continue
    outdir = os.path.join(DST, d, "places")
    for f in sorted(os.listdir(places)):
        full = os.path.join(places, f)
        if not os.path.islink(full) or not f.endswith(".svg"):
            continue
        real = os.path.basename(os.path.realpath(full))
        if not (real.startswith("folder-red") or real.startswith("user-red")):
            continue
        canonical = real.replace("-red", "", 1)
        if f == canonical or not os.path.exists(os.path.join(outdir, canonical)):
            continue
        link = os.path.join(outdir, f)
        if os.path.lexists(link):
            os.remove(link)
        os.symlink(canonical, link)
        aliases += 1

# ----------------------------- layer 2: Papirus blood system accent icons
TARGETS = {"org.kde.dolphin.svg", "system-file-manager.svg", "utilities-tweak-tool.svg",
           "plasmadiscover.svg", "utilities-system-monitor.svg"}
sysicons = 0
for d in sorted(os.listdir(PAPIRUS)):
    if not re.fullmatch(r"\d+x\d+(@2x)?", d):
        continue
    apps = os.path.join(PAPIRUS, d, "apps")
    if not os.path.isdir(apps):
        continue
    outdir = os.path.join(DST, d, "apps")
    entries = os.listdir(apps)
    real = {f for f in entries if f in TARGETS and not os.path.islink(os.path.join(apps, f))}
    linked = {f: os.readlink(os.path.join(apps, f)) for f in entries
              if os.path.islink(os.path.join(apps, f)) and os.readlink(os.path.join(apps, f)) in real}
    if not real and not linked:
        continue
    os.makedirs(outdir, exist_ok=True)
    for f in sorted(real):
        with open(os.path.join(apps, f)) as fh:
            content = fh.read()
        with open(os.path.join(outdir, f), "w") as fh:
            fh.write(remap(content))
        sysicons += 1
    for f, tgt in sorted(linked.items()):
        link = os.path.join(outdir, f)
        if os.path.lexists(link):
            os.remove(link)
        os.symlink(tgt, link)
        aliases += 1

# --------------------------------- layer 3: Nordzy full reforge (no places)
reforged = links = 0
for root, dirs, files in os.walk(NORDZY, followlinks=False):
    rel = os.path.relpath(root, NORDZY)
    if rel.split(os.sep)[0] == "places" or (os.sep + "places") in (os.sep + rel):
        continue
    outdir = os.path.join(DST, rel) if rel != "." else DST
    for f in files:
        src = os.path.join(root, f)
        dst = os.path.join(outdir, f)
        if os.path.islink(src):
            tgt = os.readlink(src)
            if "/places/" in tgt or tgt.startswith("places/"):
                continue
            os.makedirs(outdir, exist_ok=True)
            if os.path.lexists(dst):
                os.remove(dst)
            os.symlink(tgt, dst)
            links += 1
        elif f.endswith(".svg"):
            os.makedirs(outdir, exist_ok=True)
            with open(src, errors="ignore") as fh:
                content = fh.read()
            with open(dst, "w") as fh:
                fh.write(remap(content))
            reforged += 1
        elif f == "index.theme" or f.endswith(".cache"):
            continue
        else:
            os.makedirs(outdir, exist_ok=True)
            with open(src, "rb") as fh:
                data = fh.read()
            with open(dst, "wb") as fh:
                fh.write(data)

# ------------------------------- index.theme: merged Papirus+Nordzy layouts
def parse_index(path):
    text = open(path).read()
    m = re.search(r"^Directories=(.+)$", text, re.M)
    dirs = m.group(1).split(",") if m else []
    m2 = re.search(r"^ScaledDirectories=(.+)$", text, re.M)
    sdirs = m2.group(1).split(",") if m2 else []
    sections = re.findall(r"(\n\[[^\]]+\]\n(?:(?!\n\[).*\n?)*)", text)
    return dirs, sdirs, sections

p_dirs, p_sdirs, p_sec = parse_index(os.path.join(PAPIRUS, "index.theme"))
n_text = open(os.path.join(NORDZY, "index.theme")).read()
n_dirs, n_sdirs, n_sec = parse_index(os.path.join(NORDZY, "index.theme"))

dirs, seen = [], set()
for d in p_dirs + n_dirs:
    if d and d not in seen:
        seen.add(d); dirs.append(d)
sdirs, seen2 = [], set()
for d in p_sdirs + n_sdirs:
    if d and d not in seen2:
        seen2.add(d); sdirs.append(d)

sec_map = {}
for s in p_sec + n_sec:
    hdr = s.strip().splitlines()[0]
    sec_map.setdefault(hdr, s)

header = re.split(r"\n\[[^\]]+\]", n_text)[0]
header = header.replace("Name=Nordzy-dark", "Name=Blackshield")
header = re.sub(r"^Comment=.*$",
                "Comment=Blackshield Mercenary - steel and blood. Nordzy-dark reforged, Papirus blood folders.",
                header, flags=re.M)
header = re.sub(r"^Inherits=.*$", "Inherits=Nordzy-dark,Papirus-Dark,breeze-dark,hicolor",
                header, flags=re.M)
header = re.sub(r"^Directories=.*$", "Directories=" + ",".join(dirs), header, flags=re.M)
if "ScaledDirectories=" in header:
    header = re.sub(r"^ScaledDirectories=.*$", "ScaledDirectories=" + ",".join(sdirs),
                    header, flags=re.M)
elif sdirs:
    header += "\nScaledDirectories=" + ",".join(sdirs) + "\n"

with open(os.path.join(DST, "index.theme"), "w") as fh:
    fh.write(header.rstrip() + "\n" + "".join(sec_map.values()))

# drop any symlinks that broke during the merge
broken = 0
for root, dirs, files in os.walk(DST):
    for f in files:
        p = os.path.join(root, f)
        if os.path.islink(p) and not os.path.exists(p):
            os.remove(p)
            broken += 1

# --------------------------------- layer 4: blood Kickoff category glyphs
# Kickoff's sidebar renders categories/symbolic/*.svg with their own fill
# (nord light gray #d8dee9). Recolor to canon blood.
catsym = 0
csdir = os.path.join(DST, "categories", "symbolic")
if os.path.isdir(csdir):
    for f in os.listdir(csdir):
        if not f.endswith(".svg"):
            continue
        p = os.path.join(csdir, f)
        with open(p) as fh:
            content = fh.read()
        new = re.sub(r"#d8dee9", "#C1121F", content, flags=re.I)
        if new != content:
            with open(p, "w") as fh:
                fh.write(new)
            catsym += 1

print(f"folders={folders} sysicons={sysicons} aliases={aliases} "
      f"nordzy-reforged={reforged} nordzy-links={links} broken-pruned={broken} "
      f"category-glyphs-bled={catsym}")
PYEOF

echo "Done. Activate with:"
echo "  kwriteconfig6 --file ~/.config/kdeglobals --group Icons --key Theme Blackshield-Icons"
echo "  kbuildsycoca6 --noincremental && systemctl --user restart plasma-plasmashell.service"
