# Blind Image Analysis: Subject Location, Cutout, and Icon Compositing

For when vision tooling is unavailable (401s, no native vision) but a task needs
precise crops/composites from existing artwork (e.g. "make a taskbar icon from my
wallpaper's helmet"). All techniques use only PIL + numpy (system python3 has both;
the execute_code sandbox may NOT have numpy — run via `terminal` + heredoc instead).

## Step 0: Verify the subject BEFORE cropping (the sun/helmet pitfall)

The brightest region is often NOT the subject. In synthwave art, a large bright
dome with horizontal banding in an ASCII map is the slatted outrun SUN, not a helmet.

- `session_search` the image's origin session first — the generation session usually
  states the composition ("helmet sits off to the right", "clean upper-center space").
  This is ground truth and costs one tool call.
- Dark subjects (black armor, silhouettes) are invisible in brightness maps — use a
  stddev (structure) map to find them: flat sky has stddev ~0, detailed dark objects
  light up.

## Locating a subject: progressive ASCII mapping

```python
from PIL import Image
import numpy as np
img = Image.open(path).convert('RGB')
bright = np.asarray(img).astype(float).mean(axis=2)
chars = ' .:-=+*#%@'   # ~26 brightness units per level

# 1. coarse whole-image grid (~100x45) -> find candidate regions
# 2. zoom into the region (~10px per cell) -> trace the actual outline
# 3. stddev map alongside brightness for dark-on-dark subjects
```

Read the maps with row/col labels printed (e.g. `f'{y:4d} {row}'`) so you can convert
cell indices back to pixel coordinates: `px = origin + cell_index * cell_size`.

Helmet-in-profile signature (from synthwave84 lock screen): faint dome (':'-level),
a very bright vertical slit = T-visor in profile, a horizontal bright band under it,
and a tapering bright jaw line. A dome of '*'/'#' with alternating bright/mid
horizontal stripes = the sun.

## Cutout via background subtraction (no ML, no scipy)

Works when the subject sits against smooth sky/gradient:

```python
from PIL import Image, ImageFilter
import numpy as np
from collections import deque

crop = img.crop(box)                                  # tight-ish box around subject
arr  = np.asarray(crop).astype(float)
bg   = np.asarray(crop.filter(ImageFilter.GaussianBlur(60))).astype(float)
diff = np.abs(arr - bg).sum(axis=2)
mask = diff > 28                    # tune: pick between p50 and p90 of diff

# keep only the component containing a seed point inside the subject (visor etc.)
# -> BFS flood fill from seed on the mask
#
# NOTE: a plain threshold bbox is NOT enough. If the bbox of your thresholded mask
# touches ANY edge of the search window, the mask is contaminated (bright ground
# glow bands and edge objects bleed in). Either shrink the window to exclude glow
# bands, or go straight to seeded flood fill + hole filling as above.

# fill interior holes: BFS from all border pixels through ~mask;
# filled = mask | (not reached from border)
```

## Compositing for small icons

- Dark armor/detail disappears at 48px — gamma-lift the subject layer:
  `(arr/255) ** 0.72` before resizing.
- Feather the mask alpha (`GaussianBlur(2)`); add a separation halo: dilated mask
  blurred ~10 at ~55% opacity of near-black, composited BEFORE the subject.
- Resize final to 256x256 LANCZOS for Kickoff/avatar use.
- Verify each stage with a coarse ASCII print of the result — you can catch bad
  framing (subject off-center, ground-glow band included, black bars from
  out-of-bounds crops) without eyes.

## Applying as a Kickoff icon

Bump the FILENAME on every iteration (e.g. `taskbar-helmet-sunset-icon-256.png`)
and point the config at the new path — do not overwrite the same path, or Plasma
can keep serving the cached pixmap. Then `plasmashell --replace` (background
process; kill the previous one first) and verify with
`spectacle -b -n -o /tmp/panel.png` + pixel-sampling the panel corners.
