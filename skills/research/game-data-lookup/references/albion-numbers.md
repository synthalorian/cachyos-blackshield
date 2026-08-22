# Albion Online — known numbers (in-game constants)

> **Status:** partial. Recipe numbers verified via web search; island-yield and
> goose-feed numbers NOT yet retrieved from an authoritative source for this session
> (wiki + data API both CF-walled from the server-side curl path). Treat anything
> below the "unverified" marker as needing re-verification before baking into a tool.

## Pork Omelette (Cooking skill 1)

**Recipe** (per craft, yields 5 pork omelettes):
- 1 Pork
- 1 Egg
- 1 Cabbage
- 1 Corn

**Source:** web search (Bing) for "albion online pork omelette recipe ingredients".
This is the widely-quoted in-game recipe. Needs a live re-verification against the
data API or in-game observation before treating as authoritative for a tool.

**Slug note:** the canonical item slug is `pork-omelette` (lowercase, hyphenated).
Recipe endpoint path on the data API is `/api/v2/recipes/pork-omelette` — but that
endpoint is Cloudflare-walled from server-side curl in this environment. The item
endpoint (`/api/v2/items/pork-omelette`) is also CF-walled. Both returned CF
challenge HTML, not JSON, when hit with bare curl and with a browser UA.

**What did NOT work this session:**
- `curl https://www.albion-online-data.com/api/v2/recipes/pork-omelette` → CF HTML
- `curl https://www.albion-online-data.com/api/v2/items/pork-omelette` → CF HTML
- `curl https://www.albiononline2d.com/api/v2/items/pork-omelette` → CF HTML
- `curl https://www.albiononline2d.com/api/v2/recipes/pork-omelette` → CF HTML
- Adding `-H "User-Agent: Mozilla/5.0"` did not bypass the CF wall on the data API.

**What did work:** a Bing web search returned the recipe snippet from community
sources. That is the retrieval path used here — secondary source, not primary API.

## Caerleon island crop yields

**NOT YET RETRIEVED** for this session. The user said cabbage and corn only produce
10 on some Caerleon island(s), and that it takes 9 to feed each goose. The specific
island name and the exact yield-per-harvest number need to come from either:
- the user's in-game observation (treat as ground truth), or
- a re-verified authoritative source (wiki, data API, or a named community source).

**Immediate question to resolve before any rework:** which island exactly? "Caerleon"
is a city — the islands around it have different names and different yields. The
relevant islands for cabbage/corn farming near Caerleon are typically referenced by
their map names; pin the exact island before recomputing.

## Goose feed cost

**NOT YET RETRIEVED** as a pinned number. The user's statement "it takes 9 to feed
each goose" is the working figure for this session — treat as ground truth pending
re-verification. Before recomputing yields, confirm:
- Is "9" per goose per production cycle, or total across all geese?
- Is the feed ingredient cabbage, corn, or both? (The pork omelette recipe uses both
  cabbage and corn as separate ingredients — if the goose eats both, the yield
  shortfall compounds.)

## Channel-type enums (protocol side — different concern)

These are NOT game-mechanics numbers; they are network-protocol constants for the
Albion Translator. Latest verified state (from `photon.rs` in the Translator, live
verified 2026-08-15):

| type_enum | ChatChannel | runtime id | verification |
|-----------|-------------|------------|--------------|
| 1 | Trade | 17 | live-verified 2026-08-15 |
| 2 | Recruitment | 18 | live-verified (joined runtime 18) |
| 3 | LFG | 19 | live-verified (joined runtime 19) |
| 5 | Global | 21 | live-verified (joined runtime 21) |
| 7 | Faction | 22 | inferred (runtime 22, unverified) |
| 8 | Language | 2 | live-verified 2026-08-15 — type enum 8 joins runtime 2 = English, NOT Trade |
| 24 | Guild | high dynamic | high dynamic runtime id |
| 25 | Alliance | high dynamic | high dynamic runtime id |
| 26 | Party | inferred | inferred by 24/25 sequence |
| 27 | Say | zone-local | dynamic per cluster |

**Correction embedded here:** type enum 8 was previously mapped to Trade in the
Companion's `ChatChannelTracker::MapChatIndex`. Live observation on 2026-08-15
showed type enum 8 joining runtime id 2 = English language chat. The Translator's
`photon.rs` maps 8 → `ChatChannel::Language` (correct). The Companion side needs
the same correction applied — see `AlbionOnline-Companion/StatisticsAnalysisTool/Network/ChatChannelTracker.cs`.
