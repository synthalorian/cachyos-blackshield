# Sourcing Public Domain Images from Wikipedia

A reusable pattern for enriching data-driven content features (encyclopedias, codexes, history timelines) with public domain Wikimedia images.

## Technique: Wikipedia REST API + Thumbnail Extraction

The Wikipedia REST API (`/api/rest_v1/page/summary/{title}`) returns a JSON summary with a `thumbnail.source` URL — the fastest and most reliable way to get a representative image for any Wikipedia topic.

### Primary Method (REST API — Preferred)

```python
from hermes_tools import terminal
import json

def get_wikipedia_image(wiki_title, output_path):
    """Fetch the summary thumbnail from a Wikipedia article."""
    url = f"https://en.wikipedia.org/api/rest_v1/page/summary/{wiki_title}"
    r = terminal(f'curl -s -A "Mozilla/5.0" "{url}"', timeout=15)
    try:
        data = json.loads(r['output'])
        img_url = data.get('thumbnail', {}).get('source')
        if not img_url:
            return None
        dl = terminal(
            f'curl -sL -A "Mozilla/5.0" "{img_url}" -o "{output_path}" --max-time 15 -w "%{{http_code}}"',
            timeout=20
        )
        if dl['output'].strip() == '200' and \
           os.path.getsize(output_path) > 2000:
            return os.path.getsize(output_path)
    except:
        pass
    return None
```

### Fallback Method (Printable HTML — for pages without thumbnails)

When the REST API returns no thumbnail, scrape the printable version of the page for the first embedded image URL:

```python
import re, os

def get_first_image_from_raw(wiki_title, output_path):
    """Extract first image URL from raw Wikipedia HTML."""
    url = f"https://en.wikipedia.org/w/index.php?title={wiki_title}&printable=yes"
    r = terminal(f'curl -s -A "Mozilla/5.0" "{url}"', timeout=15)
    html = r['output']
    pattern = r'//upload\.wikimedia\.org/wikipedia/commons/[^"\'\\]+\.(?:jpg|jpeg|png)'
    matches = re.findall(pattern, html, re.IGNORECASE)
    if not matches:
        return None
    img_src = "https:" + matches[0]
    dl = terminal(
        f'curl -sL -A "Mozilla/5.0" "{img_src}" -o "{output_path}" --max-time 15 -w "%{{http_code}}"',
        timeout=20
    )
    if os.path.exists(output_path) and os.path.getsize(output_path) > 2000:
        return os.path.getsize(output_path)
    return None
```

### Combined Function

```python
def download_wiki_image(wiki_title, output_path):
    """Try REST API first, fall back to HTML scraping."""
    size = get_wikipedia_image(wiki_title, output_path)
    if size:
        return size
    return get_first_image_from_raw(wiki_title, output_path)
```

## Wikipedia Article Title to Filename Mapping

```python
# Format: (wiki_title, local_filename)
images = [
    ("Church_of_the_Holy_Sepulchre", "holy_sepulchre.jpg"),
    ("St._Peter%27s_Basilica", "st_peters.jpg"),
    ("Hagia_Sophia", "hagia_sophia.jpg"),
    ("Augustine_of_Hippo", "augustine.jpg"),
    ("Thomas_Aquinas", "thomas_aquinas.jpg"),
    ("Francis_of_Assisi", "francis_assisi.jpg"),
    # Use underscores for spaces, URL-encode apostrophes as %27
]
```

Use `urllib.parse.quote()` when constructing URLs with special characters, but the REST API handles most characters directly.

## Minimum Image Quality Threshold

`os.path.getsize(output_path) > 2000*` is too low — files under 5KB are icons/logos, not usable photos. Use **8KB minimum**:

```python
MIN_IMAGE_SIZE = 8000  # 8KB — real photos start here

if os.path.exists(output_path) and os.path.getsize(output_path) > MIN_IMAGE_SIZE:
    return os.path.getsize(output_path)
```

## Cleanup Pattern for Failed Downloads

A partially-downloaded file that falls below the threshold will block future retries (the script sees it exists and skips). **Always remove partial files:**

```python
if os.path.exists(output_path) and os.path.getsize(output_path) < MIN_IMAGE_SIZE:
    os.remove(output_path)  # cleanup — next attempt will re-download
    return None
```

## Bulk Batch Scraping Pattern

When downloading 50+ images in one session, use a loop with progress tracking and rate limiting:

```python
needed = [
    ("Wikipedia_Article_Title", "local_filename.jpg"),
    # ... 60+ entries
]

success = 0
for wiki_title, filename in needed:
    filepath = os.path.join(img_dir, filename)
    if os.path.exists(filepath) and os.path.getsize(filepath) > 8000:
        success += 1  # already have it
        continue

    print(f"  {filename:35s} ...", end=" ")
    size = get_first_image_from_raw(wiki_title, filepath)
    if size:
        print(f"✓ {size//1024}KB")
        success += 1
    else:
        print("✗")
    time.sleep(0.3)  # Rate limit: 300ms minimum between requests

print(f"{success}/{len(needed)} images obtained")
```

**Rate limit considerations:** Wikimedia's REST API (`/api/rest_v1/page/summary/`) returns thumbnails faster but many articles lack them. The HTML `?printable=yes` fallback always works but costs more bandwidth. Spread requests with `time.sleep(0.3-1.0)` to avoid HTTP 429 regardless of method.

**Repeated requests to the same article:** When multiple entry IDs map to the same Wikipedia article (e.g., `templar_founding`, `templar_banking`, `templar_rule` → "Knights_Templar"), each request may return a DIFFERENT first image from the page. This gives each dedicated image a slightly different angle — good for visual variety. However, `curl` to the same URL can also return cached/throttled results.

## Articles With No Usable Images

Some Wikipedia articles have NO usable images at all:
- Article pages that are lists, stubs, or disambiguation pages
- Abstract concepts covered by text-only pages
- Recently created articles without uploaded media

When the secondary HTML scrape also fails, **fall back to a category-level image** (e.g., a generic cross image for cross-type entries, a generic church photo for denomination entries). Copy an existing good image as the fallback:

```python
import shutil
# Last resort — use a sibling category image as fallback
src = os.path.join(img_dir, 'latin_cross.jpg')  # known good image
if os.path.exists(src):
    shutil.copy2(src, os.path.join(img_dir, 'jerusalem_cross.jpg'))
```

This ensures every entry has an image without blocking the entire download pipeline. The user can replace with a more specific image later.

## Pitfalls

- **Rate limiting:** Insert `time.sleep(0.3-1.0)` between requests to avoid HTTP 429. Without delays, sequential curl calls trigger Wikimedia's rate limiter. At 300ms spacing, 80 images take ~25 seconds.
- **User-Agent required:** Wikimedia rejects requests without a `User-Agent` header. Always set `-A "Mozilla/5.0"` or `-A "YourApp/1.0 (contact@example.com)"`.
- **`curl --max-time`** prevents hung connections from blocking the pipeline. Always add `--max-time 15` to curl calls.
- **Image sizes:** Wikipedia thumbnails are typically 200-500KB at 800px width — sufficient for app detail views without bloating the APK. The REST API returns smaller (~30-50KB) thumbnails than HTML scraping (~200-500KB). Accept both.
- **No thumbnail:** Some static/philosophical articles (e.g., "Chi_Rho") have no page image. The REST API returns no `thumbnail` key — fall back to the printable HTML method.
- **SVG images:** The thumbnail API converts SVGs to PNG. If you need SVG, use the HTML scrape method and download the original SVG from the `//upload.wikimedia.org/wikipedia/commons/` path.
- **Licensing:** Wikipedia/Wikimedia Commons images are CC BY-SA or public domain. Always include attribution in the app credits.
- **User preference signal:** If the user corrects you about image quality or placeholder usage (e.g., "most of the placeholders dont have an image"), the lesson is: **every entry needs its own dedicated image.** Shared placeholder images will be called out. This is both a memory fact and a skill-level quality standard for content features.

## Integration with Flutter Encyclopedia Features

After downloading, register images in `pubspec.yaml` under `flutter:` → `assets:`. **CRITICAL: Flutter does NOT recursively include subdirectory assets.** Each subdirectory must be explicitly declared:

```yaml
flutter:
  assets:
    - assets/data/                        # ← includes files directly in data/ but NOT images/
    - assets/data/christian_history/
    - assets/data/christian_history/images/  # ← MUST declare explicitly!
```

**WRONG assumption that caused real bugs:** Declaring a parent directory does NOT auto-include files in subdirectories. `- assets/data/` includes `assets/data/books.json` but NOT `assets/data/christian_history/images/hagia_sophia.jpg`. You must declare each directory path that contains assets, even if it's under another declared directory.

### Image Loading: rootBundle.load() + Image.memory() (Preferred)

`Image.asset()` can fail mysteriously even when the asset manifest has the correct path. The most robust approach is `rootBundle.load()` + `Image.memory()`.

**But for swipeable galleries (PageView), a simple async function isn't enough** — the widget's `initState` fires only once. When the user swipes to a new entry, the body widget is REUSED, not recreated. Use a `StatefulWidget` with `didUpdateWidget` to detect the entry change and trigger a fresh load:

```dart
class HistoryDetailBody extends StatefulWidget {
  final HistoryEntry entry;
  const HistoryDetailBody({super.key, required this.entry});
  @override
  State<HistoryDetailBody> createState() => _HistoryDetailBodyState();
}

class _HistoryDetailBodyState extends State<HistoryDetailBody> {
  ImageProvider? _image;
  String? _imageError;

  @override
  void initState() {
    super.initState();
    _loadImage();  // first page
  }

  @override
  void didUpdateWidget(HistoryDetailBody old) {
    super.didUpdateWidget(old);
    if (old.entry.imageUrl != widget.entry.imageUrl) {
      _image = null;
      _imageError = null;
      _loadImage();  // reload on swipe
    }
  }

  Future<void> _loadImage() async {
    final url = widget.entry.imageUrl;
    if (url == null) return;
    try {
      final data = await rootBundle.load(url);
      if (!mounted) return;
      setState(() {
        _image = MemoryImage(data.buffer.asUint8List());
        _imageError = null;
      });
    } catch (e) {
      debugPrint('Image FAILED: $url: $e');
      if (!mounted) return;
      setState(() => _imageError = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    // Render _image or error widget
  }
}
```

**Why this works:** It bypasses the asset manifest for image decoding. The bytes are read directly from the bundle, then decoded in memory. This handles:
- Files with `.jpg` extension that are actually PNG format (Wikipedia does this)
- Grayscale JPEGs (1-component color)
- Files with unusual metadata/EXIF headers

**When to use Image.asset() instead:** Only for simple cases with properly formatted, verified images. For encyclopedia/data-driven content with images from external sources, use `rootBundle.load()`.

### Verify Assets Are in the APK

After building, confirm images are actually bundled:

```bash
unzip -l build/app/outputs/flutter-apk/app-release.apk | grep "myproject/images/" | head -5
unzip -l build/app/outputs/flutter-apk/app-release.apk | grep "myproject/images/" | wc -l  # count
```

Also check the asset manifest:

```bash
unzip -p build/app/outputs/flutter-apk/app-release.apk "assets/flutter_assets/AssetManifest.bin" 2>/dev/null | strings | grep "myproject"
```

Set the `imageUrl` field in the encyclopedia entry JSON:

```json
{
  "id": "hagia_sophia",
  "title": "Hagia Sophia",
  "imageUrl": "assets/data/myproject/images/hagia_sophia.jpg"
}
```

## Reference

- Wikipedia REST API docs: https://en.wikipedia.org/api/rest_v1/
- Wikimedia Commons: https://commons.wikimedia.org/
- Flutter rootBundle asset loading: `await rootBundle.loadString('assets/...')` / `rootBundle.load('assets/...')` for binary assets
- Flutter asset manifest: Declared in pubspec.yaml, compiled into `AssetManifest.bin` in the APK
- Verify assets post-build: `unzip -l build/app/outputs/flutter-apk/app-release.apk | grep your_directory/`
