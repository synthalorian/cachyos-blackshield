# FAL/Krea Synthwave Generation Notes

## Pitfall: literal hex codes become visible artifacts

A synthwave wallpaper prompt that included literal palette values (`#240037`, `#8F00FF`, etc.) produced an image with bottom color-code bars/swatches. Fix: remove hex codes from the image prompt and use color names instead, while adding explicit negative constraints.

Bad pattern:
- "deep purple sky #240037, electric purple #8F00FF ... no text"

Better pattern:
- "deep midnight purple sky, electric purple grid lines, hot pink and magenta sunset glow, neon yellow sun ... Absolutely no text, no logos, no color palette bars, no color swatches, no hex codes, no UI overlays, no bottom banner, no watermark."

## Session-proven wallpaper prompt shape

```text
80s outrun synthwave desktop wallpaper: <subject> driving toward a giant striped neon sunset over an endless reflective chrome grid horizon, deep midnight purple sky, electric purple grid lines, hot pink and magenta sunset glow, neon yellow sun, palm tree silhouettes, analog VHS grain, cinematic wide composition, clean wallpaper composition only. Absolutely no text, no logos, no color palette bars, no color swatches, no hex codes, no UI overlays, no bottom banner, no watermark.
```

Subjects used successfully: Ferrari Testarossa for the primary 2K monitor; DeLorean DMC-12 for the secondary monitor.

## Lock/login wallpaper prompt shape

Central subjects can make an otherwise clean wallpaper unusable for KDE/SDDM-style login screens because the clock, avatar, and password prompt usually render near the center. For lock/login art, explicitly reserve UI-safe negative space:

```text
80s outrun synthwave lock screen and login screen wallpaper designed for readability: <small subject in the lower right third>, giant striped neon sunset low on the left horizon, reflective electric purple grid across the bottom edge, distant chrome mountains and palm silhouettes only near the far edges, deep midnight purple sky occupying the upper two thirds, subtle magenta haze, faint stars, analog VHS grain and very light scanlines. Preserve a large clean dark empty area across the exact center and upper center for a clock, user avatar, and password prompt; no major subject in the center, no bright objects behind where login UI would appear. Absolutely no text, no letters, no numbers, no logos, no color palette bars, no color swatches, no hex codes, no UI overlays, no bottom banner, no watermark, no frame, no border.
```

Verification prompt should ask specifically whether the exact center and upper-center remain clean/readable. A centered helmet render failed this check; moving the helmet to the lower right and keeping the upper two-thirds dark fixed it.

## Direct FAL generation skeleton

Use when Hermes `image_generate` has stale credentials after `~/.hermes/.env` was updated in the same session:

```bash
/home/synth/.hermes/hermes-agent/venv/bin/python - <<'PY'
import os, pathlib, urllib.request
key = next(l.split('=',1)[1].strip() for l in (pathlib.Path.home()/'.hermes/.env').read_text().splitlines() if l.startswith('FAL_KEY='))
os.environ['FAL_KEY'] = key
import fal_client
handler = fal_client.submit('fal-ai/krea/v2/large/text-to-image', arguments={
    'prompt': PROMPT,
    'aspect_ratio': '16:9',   # or '1:1' for icon
    'creativity': 'medium',
    'seed': 840184,
})
url = handler.get()['images'][0]['url']
data = urllib.request.urlopen(urllib.request.Request(url, headers={'User-Agent':'synthclaw-image-fetch/1.0'}), timeout=120).read()
pathlib.Path('out.png').write_bytes(data)
PY
```

Then run `scripts/cover_resize.py` to produce the exact wallpaper resolution.
