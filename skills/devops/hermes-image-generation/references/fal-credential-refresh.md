# FAL credential refresh + direct generation fallback

From a real session: `image_generate` returned `invalid key credentials` (`FalClientHTTPError`). Config showed `image_gen.provider: fal` with model `fal-ai/krea/v2/large/text-to-image`. `~/.hermes/.env` had a stale `FAL_KEY`. After the user supplied a new key, the running Hermes session still had the old env cached, so the built-in tool kept failing. Direct generation through the Hermes venv worked immediately.

## 1. Store/update FAL_KEY (no echo, no protected-file tools)

```bash
python3 - <<'PY'
from pathlib import Path
key = '<paste key here>'
p = Path.home() / '.hermes' / '.env'
lines = p.read_text().splitlines() if p.exists() else []
out, done = [], False
for line in lines:
    if line.startswith('FAL_KEY='):
        out.append(f'FAL_KEY={key}')
        done = True
    else:
        out.append(line)
if not done:
    out.append(f'FAL_KEY={key}')
p.write_text('\n'.join(out) + '\n')
p.chmod(0o600)
print('stored FAL_KEY in ~/.hermes/.env')
PY
```

Sanity checks without leaking: report presence, raw length, surrounding whitespace/quotes, and whether it contains `:`. Observed valid shape: `<uuid>:<hex>`, length ~69.

After updating, `/reset` or relaunch Hermes for the built-in `image_generate` to see it. If the user needs images now, use the fallback below.

## 2. Direct fallback generation script

Run with `/home/synth/.hermes/hermes-agent/venv/bin/python` (has `fal_client` 0.13.1; system python3 did not).

```python
import os, json, pathlib, urllib.request

env_path = pathlib.Path.home() / '.hermes' / '.env'
for line in env_path.read_text().splitlines():
    if line.startswith('FAL_KEY='):
        os.environ['FAL_KEY'] = line.split('=', 1)[1].strip().strip('"').strip("'")
        break

import fal_client

handler = fal_client.submit(
    'fal-ai/krea/v2/large/text-to-image',
    arguments={
        'prompt': prompt,
        'aspect_ratio': '16:9',   # '1:1' for icon, '9:16' portrait
        'creativity': 'medium',
    },
)
result = handler.get()
url = result['images'][0]['url']
req = urllib.request.Request(url, headers={'User-Agent': 'synthclaw-image-fetch/1.0'})
data = urllib.request.urlopen(req, timeout=120).read()
```

Observed output sizes: 1376x768 for `16:9`, 1024x1024 for `1:1` — NOT 2K. Always verify dimensions.

## 3. 2K wallpaper / icon finishing (PIL, Hermes venv)

```python
from PIL import Image, ImageFilter

def cover_resize(src, dst, size=(2560, 1440)):
    im = Image.open(src).convert('RGB')
    w, h = im.size
    tw, th = size
    scale = max(tw / w, th / h)
    im = im.resize((round(w*scale), round(h*scale)), Image.Resampling.LANCZOS)
    nw, nh = im.size
    left, top = (nw - tw)//2, (nh - th)//2
    im = im.crop((left, top, left+tw, top+th))
    im = im.filter(ImageFilter.UnsharpMask(radius=1.2, percent=80, threshold=2))
    im.save(dst, 'PNG', optimize=True)
```

- Wallpapers: `cover_resize(src, dst)` → exact 2560x1440, name `*-2k.png`.
- Icons: resize square source to 256x256 with LANCZOS.
- Report absolute paths; verify with `Image.open(path).size` before claiming dimensions.
