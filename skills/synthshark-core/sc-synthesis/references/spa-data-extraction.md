# SPA Data Extraction via Browser Console

When scraping structured data from JavaScript-heavy single-page apps (SPAs) like VerseGuide, the browser's accessibility tree (`browser_snapshot`) often shows incomplete or truncated content. The fastest path to full data is extracting the app's internal state via the browser console.

## Technique

1. **Navigate** to the page with `browser_navigate(url)`

2. **Dump JS state objects** with `browser_console(expression)`. Common SPA framework state variables:

   | Framework | State Variable |
   |-----------|---------------|
   | Nuxt.js (Vue) | `window.__NUXT__` |
   | Next.js (React) | `window.__NEXT_DATA__` |
   | Angular Universal | `window.__INITIAL_STATE__` |
   | Remix | `window.__remixContext` |
   | Generic | `window.__INITIAL_STATE__` |

3. **Probe all at once:**
   ```javascript
   JSON.stringify(window.__NUXT__ || window.__NEXT_DATA__ || window.__INITIAL_STATE__ || {})
   ```

4. **Extract target data** from the returned JSON. For VerseGuide, the useful fields live in:
   - `state.status.systems.STANTON` — system metadata, celestial objects array
   - `state.locations` — location details (may be empty until planet is clicked)
   - `state.locations.details` — planet-specific data (temperature, atmosphere, sub-locations)

5. **Supplement with visual extraction** for fields loaded asynchronously (like atmospheric composition). Click each planet tab and use `browser_snapshot()` to read text content.

## When to Use This vs. Browser Snapshots

| Situation | Tool |
|-----------|------|
| Page is a JSON API, raw markdown, or static content | `curl` via terminal or `web_extract` |
| Page has interactive elements, forms, or dynamic content | `browser_navigate` + `browser_snapshot` |
| Page loads data via JS fetch/API calls into a state store | `browser_console` to dump `__NUXT__`, `__NEXT_DATA__`, etc. |
| Page has CAPTCHA or bot detection | Use `browser_vision` with `annotate=true` to handle visually |
| Need to interact with complex UI (multi-step forms, carousels) | `browser_navigate` + `browser_click` chain |

## Caution

- The dumped state may be truncated by the console output limit. Use `substring(0, 5000)` to get a preview, then extract the specific keys you need.
- Some frameworks serialize data with circular references that can't be `JSON.stringify`'d. If the dump fails, try extracting individual keys: `JSON.stringify(window.__NUXT__.state.locations)`.
- Large datasets (like VerseGuide's 100+ celestial objects) are better extracted in chunks or by filtering to specific keys.
