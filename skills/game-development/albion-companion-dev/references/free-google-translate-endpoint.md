# Free Google Translate Endpoint — the endpoint the Companion used

## The endpoint (no API key, no billing)

```
https://translate.googleapis.com/translate_a/single?client=gtx&sl=auto&tl={target}&dt=t&q={encoded_text}
```

- `client=gtx` — same backend as translate.google.com web UI
- `sl=auto` — let Google detect source language. **CRITICAL:** never use a local heuristic. Accent-free Spanish/Portuguese ("busco party soy healer") defeats accent-based detection; Google's server-side detection catches it (git commit `5ec6b0e`).
- `dt=t` — text-only output (no slats/html/phonetic hints)
- No API key, no billing, no quota check visible. Works for all languages.

## Response format

```json
[[["translated text","original text",null,null,offset]], null, "detected_source_lang", null, null, null, 1, [], [["detected_lang"], null, [1], ["detected_lang"]]]
```

- `root[0]` — array of sentence segments; each segment is `[translated, original, null, null, offset]`
- **Concatenate ALL segments** in `root[0]` — not just `root[0][0]`. Multi-sentence chat messages otherwise truncate.
- `root[2]` — detected source language (e.g. `"es"`). Read this, don't predict it.
- Skip the translation if `detected_lang == target_lang || translated == original` — Google's verdict that it's already in target.

## What we learned from the Companion (git archaeology)

The translator was removed from the Companion (commit `40c52d4`, "Remove translator feature (now a separate product)"). To recover the implementation:

```bash
# 1. Find the commits that touched translation
git log --all --oneline | grep -i "translat\|google"

# 2. Read the full diff of the commit that implemented it
git show 6c1f3e3 -p -- StatisticsAnalysisTool/Common/TranslationService.cs

# 3. Read the commit that added sl=auto detection (the edge-case fix)
git show 5ec6b0e -p -- StatisticsAnalysisTool/Common/TranslationService.cs
```

Key commits:
- `6c1f3e3` — switched to free gtx endpoint, proper response parsing, 200ms rate limiter, translation cache
- `5ec6b0e` — sl=auto Google detection (catches accent-free Spanish/Portuguese), multi-sentence parse, type-to-translate compose box

## Companion implementation details (from git)

- **User-Agent header:** `Mozilla/5.0 (X11; Linux x86_64) AlbionOnlineCompanion/1.0` — set on the HttpClient, not optional.
- **Rate limiter:** `SemaphoreSlim` with 200ms between requests (down from 300ms).
- **Cache:** in-memory `ConcurrentDictionary<string, TranslationResult>` keyed by `{text}:{targetLanguage}`.
- **Multi-sentence parse:** loop over `root[0].EnumerateArray()`, append `segment[0].GetString()` to StringBuilder.
- **Detected lang read from `root[2]`**, not predicted.

## Edge cases we had to handle

From commit `5ec6b0e` and user feedback:

- **Accent-free Spanish/Portuguese:** local charset heuristics failed on words like "busco", "party", "soy", "healer" — no ñ, á, é, í, ó, ú. `sl=auto` handles this.
- **Half-spoken languages / rare languages:** if a word has special characters or letters from an uncommon script, Google's server-side detection still translates it correctly. The key is trusting `sl=auto` and not pre-filtering.
- **Multi-sentence messages:** chat messages can be several sentences. Concatenating only the first segment drops the rest.
- **Already-in-target detection:** when Google returns the translated text equal to the original (or detected lang == target lang), don't show a duplicate — return the original.

## Rust implementation sketch

```rust
async fn translate_google_free(
    &self,
    text: &str,
    target_lang: &str,
) -> Result<String, reqwest::Error> {
    let encoded = urlencoding::encode(text);
    let url = format!(
        "https://translate.googleapis.com/translate_a/single?client=gtx&sl=auto&tl={}&dt=t&q={}",
        target_lang, encoded
    );

    // Set User-Agent — Google may block bare requests
    let response = self.http_client
        .get(&url)
        .header("User-Agent", "Mozilla/5.0 (X11; Linux x86_64)")
        .send()
        .await?;

    if !response.status().is_success() {
        let status = response.status();
        return Err(reqwest::Error::new(
            reqwest::error::ErrorKind::StatusCode,
            format!("Google Translate returned {}", status),
        ));
    }

    #[derive(Deserialize)]
    struct GoogleFreeResponse {
        trans: Vec<Vec<serde_json::Value>>,
        #[serde(default)]
        detected: Option<String>,
    }

    // Note: serde won't map root[2] to a field automatically.
    // Either parse the raw JSON and read root[2], or use a custom deserializer.
    let result: GoogleFreeResponse = response.json().await?;

    // Concatenate all sentence segments
    let translated = result.trans.iter()
        .filter_map(|seg| seg.first()?.as_str())
        .collect::<String>();

    if translated.is_empty() {
        return Ok(text.to_string());
    }

    Ok(translated)
}
```

## Rate limiting

- Companion used 200ms between requests. For the Translator, a simple approach:
  - Track `std::time::Instant::now()` of last request.
  - If `now - last < 200ms`, sleep the remainder.
  - Or: batch multiple text fragments into one request (Google supports multiple `q` params? verify — the Companion sent one at a time).

## Caching

- Key: `{text}:{target_lang}` (exact text + target).
- In-memory HashMap<String, String> is fine for a desktop app.
- The Companion's cache had a lock (`SemaphoreSlim` / `_cacheLock`).
- Consider persisting cache to disk only if restart churn is a real problem (chat is transient).

## What NOT to do

- **Don't use a local language detector to set `sl=`** — accent-free text defeats it. Always `sl=auto`.
- **Don't concatenate only `root[0][0]`** — multi-sentence messages lose data.
- **Don't skip the User-Agent header** — bare requests may get blocked.
- **Don't try to parse `root[2]` with serde's default struct** — serde maps by field name, and the JSON array has no field names. Read it manually from the raw JSON or use `serde_json::Value` and index.
- **Don't ship without the free endpoint wired** — without it AND without a CTranslate2 model, the app returns `[es] Hola` instead of real translations. That's the current blocker.
