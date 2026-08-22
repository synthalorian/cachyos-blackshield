# Pork Omelette — Verified Recipe Data

## Recipe (per 1 Pork Omelette)

| Ingredient | Quantity | Notes |
|------------|----------|-------|
| Pork | 72 | Processed via butcher from pig output |
| Eggs | 18 | From goose output |
| Corn | 26 | Direct recipe ingredient |

**Total per omelette:**
- **Corn demand:** 72 (pig feed) + 26 (recipe) = **98 corn**
- **Cabbage demand:** 18 × 9 = **162 cabbage** (each goose eats 9 cabbage)
- **Pork yield assumption:** 8 pigs × 9 pork each = 72 pork (9:1 pig-to-pork ratio). Confirm in-game — if ratio differs, pork demand math changes.

## Feed requirements per animal

| Animal | Feed | Per unit |
|--------|------|----------|
| Goose | Cabbage | 9 per goose |
| Pig | Corn | 9 per pig |

## Station mechanics

- **Butcher:** Channeled (single station, player must be present). Same as cook. Throughput is the binding constraint on pig pastures — 1 butcher caps pig pasture count.
- **Cook:** Channeled. Single station. Player must be present.
- Neither station is "fed" with food as fuel — they consume recipe ingredients, not station upkeep.

## Sources verified this session

| Source | What it confirmed | Access method |
|--------|-------------------|---------------|
| User's in-game data | Full recipe (72 pork, 18 eggs, 26 corn), feed ratios (9 cabbage/goose, 9 corn/pig), station channeling | Direct — construction/recipe window |
| Albion Online Grind cooking profit calculator | Recipe data accessible (no Cloudflare wall); calculator lists ingredient requirements for cooked food items | `https://albiononlinegrind.com/cooking-profit-calculator` — curl-able, no JS challenge |
| YouTube setup videos | Pork omelette farm island layouts, pasture/farm/cook/butcher counts, single-station channeling pattern | `https://www.youtube.com/results?search_query=albion+online+pork+omelette+recipe` |

## Sources blocked this session (Cloudflare WAF, interactive challenge or 429)

Do NOT retry these expecting different results — the WAF posture is what it is:

| Source | Block type |
|--------|-----------|
| wiki.albiononline.com | Interactive JS challenge (`cType: 'interactive'`) on all paths including `?action=raw` |
| wiki.gg (albion.wiki.gg) | Cloudflare challenge |
| albiononline.fandom.com | Cloudflare challenge |
| Wayback Machine wildcard searches (`/web/2025*/...`) | 429 Too Many Requests |
| Wayback specific snapshots | 429 or empty (rate-limited at session time) |
| albiononline.com (official) | Cloudflare challenge on `/en/game/encyclopedia/food`, `/en/building/recipes`, `/en/game/info/food` |
| albiononlinegrind.com item pages | 404 — item detail pages not exposed at guessed paths; the cooking calculator page itself was accessible |

## session date

2026-08-14

## note

These numbers are for the standard Pork Omelette as of this session. If Albion Online patches the recipe, feed ratios, or station mechanics after this date, in-game data overrides everything in this file.
