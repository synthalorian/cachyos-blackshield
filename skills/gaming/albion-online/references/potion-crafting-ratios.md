# Albion Online — Potion Crafting Ratios

Confirmed in-session recipes (Albion wiki / in-game alchemist). Add more as they come up.

## Gigantify Potion

Per craft: **24 Dragon Teasel / 12 Burdock / 6 Goose Eggs** — ratio **4 : 2 : 1**.

Scaling math (given N teasel):
- Burdock = N / 2
- Goose Eggs = N / 4
- Full crafts = floor(N / 24); leftover teasel = N mod 24... note: ratio-wise the binding constraint is eggs (N/4 crafts if matching all herbs proportionally).

Example (asked 2026-08-10): 2015 teasel → 1008 burdock + 504 eggs (rounded up), or 503 clean crafts = 2012 teasel + 1006 burdock + 503 eggs.
