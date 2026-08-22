# Google Translate free gtx endpoint

No API key. Used for the AlbionOnline-Companion live chat translator.

## Endpoint

```
GET https://translate.googleapis.com/translate_a/single?client=gtx&sl=<src|auto>&tl=<target>&dt=t&q=<urlencoded text>
```

Send a browser-ish User-Agent. ~200 ms minimum interval between requests is polite and avoids throttling; cache aggressively (key = text + target lang).

## Response format

```json
[[["translated segment 1","original 1",null,null,1],["segment 2","original 2",...]],null,"<detected_source_lang>"]
```

- **Concatenate ALL segments in root[0]** — a naive `root[0][0][0]` read silently drops every sentence after the first (multi-sentence chat messages got truncated in production).
- **root[2]** = Google's detected source language (when `sl=auto`). Compare it to the target to decide "already in target language, don't mark as translated".

## Lesson: always use sl=auto, never local accent heuristics

The original code detected language locally by looking for accented chars (ñ, á, ç...) and non-Latin scripts. Accent-free Spanish/Portuguese ("Busco party soy healer", "armo party pra rastreo") — a huge share of MMO chat — got classified as English and never translated. `sl=auto` + reading back root[2] is both simpler and correct.

## Two-entry-point pattern

- `TranslateAsync(text)` → uses the app's configured target (chat feed)
- `TranslateAsync(text, targetLang)` → explicit target (type-to-translate / reply-compose box)

Both funnel into one private core; the compose box for replying to players defaults its target to the most common non-English chat language (Spanish on the Americas server).
