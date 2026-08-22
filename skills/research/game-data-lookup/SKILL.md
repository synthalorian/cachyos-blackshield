---
name: game-data-lookup
description: >
  Look up game constants blocked by Cloudflare.
---

# game-data-lookup

## Trigger

User asks for a game constant (recipe ingredients, item stats, island crop yields,
goose/pet feed costs, channel-type IDs, market prices) and the first instinct — curl
the wiki or the data API — returns a Cloudflare challenge page. This is especially
common for Albion Online (wiki.albiononline.com, albion-online-data.com, albiononline2d.com)
and other CF-walled game wikis.

## Core principle

The goal is **authoritative numbers**, not "something that looks plausible." A wrong
island-yield figure or feed-cost ratio is worse than no figure — it gets baked into
tools and spreadsheets. Every number you return must trace back to either (a) an
endpoint you actually retrieved, or (b) a named community source with a retrieval
path you can re-verify.

## Cloudflare-wall bypass playbook

### 1. Try the data API with a browser-like User-Agent first

```
curl -s --max-time 10 -H "User-Agent: Mozilla/5.0" \
  "https://www.albion-online-data.com/api/v2/recipes/pork-omelette"
```

Some endpoints that return 404 under a bare curl will respond under a browser UA.
If it still returns CF HTML, proceed to the next rung.

### 2. Use a Bing/web search to find cached or mirror copies

When the canonical API is CF-walled, a search engine cache or a quoted community
post is the next-best source of record. Bing returns snippets and cached page links
that can carry the exact numbers you need — especially for recipe ingredient lists
and item stats that are widely quoted.

Pattern:
```
curl -s --max-time 10 "https://www.bing.com/search?q=<game>+<item>+<property>" \
  | grep -o -i '<snippet-pattern>' | head -20
```

For recipe lookups the most reliable Bing query shape is:
```
<game> <item> recipe ingredients
```
For island-yield questions:
```
<game> <island> <crop> yield production
```

### 3. Prefer endpoints that are NOT behind CF

- **albion-online-data.com** `/api/v2/` endpoints are frequently CF-walled from
  server-side curl. If you hit CF, do NOT retry the same endpoint hoping it'll
  change — move to a search-based retrieval.
- **Third-party mirrors and aggregators** (e.g. albiononline2d.com, community
  spreadsheet mirrors, Reddit posts with quoted tables) are valid secondary sources
  when the primary is unreachable, but note the source in your answer.

### 4. When you can't reach any source, say so

If both the canonical API and search-based retrieval come back empty, the correct
move is to tell the user: "I can't reach a source for the current numbers — the
wiki and data API are both CF-walled from here, and search didn't surface a pinned
figure." Do NOT invent a number or carry forward one you already had from a
previous session unless you can re-verify it now.

## Game-mechanics lookup by domain

### Recipes / ingredients / yields

- Recipe endpoints: `/api/v2/recipes/<item-slug>` on the data API.
- Item endpoints: `/api/v2/items/<item-slug>` or `/api/v2/items?name=<item-slug>`.
- Many recipe calls return 404 if the slug is wrong — item names use hyphens, not
  spaces, and are lowercase (e.g. `pork-omelette`, not `Pork Omelette`).
- If the recipe endpoint 404s, try the item endpoint — sometimes the item page
  carries the recipe breakdown even when the dedicated recipe endpoint is missing.

### Crop yields per island

- Yields are island-specific and patch-version-specific. A cabbage yield on one
  island ≠ the same yield on another island, and yields change between patches.
- Always name the island when stating a yield. "Cabbage yields 10 on Avgoth" is
  verifiable; "cabbage yields 10" without an island is not.
- When the in-game number and the tool's stored number disagree, treat the in-game
  number as ground truth and flag the stored number for rework — do not average
  them or pick one arbitrarily.

### Pet / goose feed costs

- Feed cost is "ingredient units consumed per animal per tick" — it is a ratio, not
  a raw count. A goose that eats 9 units of cabbage per tick from a farm producing
  10 per harvest is on the edge of viable; a goose that eats 9 from a farm producing
  1 is not.
- When the user says "it takes 9 to feed each goose," confirm the unit: is that 9
  items per goose per production cycle, or 9 items total across all geese?

### Channel-type enums (network protocol side)

- Channel type enums are confirmed by joining the channel in-game and observing the
  runtime id + type enum pair, not by quoting a stale table. If a table says type
  enum 8 = Trade and live observation shows type enum 8 joining runtime id 2 = English
  language chat, the table is wrong and the live observation wins.

## Pitfalls

- **Do not treat a CF challenge page as a 404.** It is not a missing endpoint — it
  is an access control layer. Retrying the same curl without a UA change or a
  different retrieval path will not help.
- **Do not silently normalize item names.** `pork-omelette` and `PorkOmelette` and
  `pork_omelette` are three different slugs; pick the one the API/docs actually use
  before falling back to search.
- **Do not carry forward last-patch numbers as current.** If you retrieved a yield or
  recipe two patches ago, treat it as stale until re-verified. The user's in-game
  observation always beats a stale stored number.
- **Do not invent a number because the user seems to want one.** A "probably around X"
  answer in a spreadsheet or tool is technical debt. Flag it as unverified instead.

## What to return

Every number you surface should come with:
1. The source you retrieved it from (endpoint URL, search result, community post).
2. The retrieval path so the user or a future session can re-verify it.
3. A confidence note: "verified against live API" / "verified against in-game
   observation" / "from community source, not yet re-verified against live data."

## See also

- `research/web-research` — the broader web-research skill for dynamic page extraction
  and Bing-based research patterns. game-data-lookup is a domain-specific overlay:
  it handles the CF-wall case and the game-constants semantics that generic web
  research does not.
