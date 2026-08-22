---
name: game-mechanics-research
description: >
  Use when researching game mechanics with WAF-walled wikis.
---

# Game Mechanics Research

## When to use

- User asks for recipe ingredients, crafting costs, building material counts, feed requirements,
  stat formulas, drop rates, mastery tables, or any gameplay number that lives in-game.
- You're about to fetch a game wiki and it's behind a WAF / Cloudflare challenge.
- You have stale or uncertain knowledge and the user might have live in-game data.

## Core principle

**The player's in-game data beats AI memory.** Game mechanics change with patches. Wikis go stale.
AI training data is a snapshot. When a user gives you numbers from their actual game client,
treat that as ground truth unless you can independently verify otherwise from an accessible source.
If you're unsure, say so mid-answer rather than running with wrong numbers and needing a correction.

## Pitfalls

- **Don't silently run with stale numbers.** If your knowledge is uncertain or possibly outdated,
  flag it in the answer: *"I recall X, but that may be outdated — confirm in-game if it matters."*
  The user correcting you is a first-class signal, not a minor detail.
- **Don't burn turns re-hitting the same Cloudflare wall.** If a wiki returns an interactive
  JS challenge (`cType: 'interactive'`) or a 429 on re-fetch, stop and pivot. Repeated identical
  requests just re-trigger the challenge with no gain.
- **Don't treat an AI memory answer as verified.** When you don't have an accessible source in hand,
  say what you remember and label it unverified. Don't present it as fact.

## Fallback workflow when primary wikis are WAF-walled

1. **In-game data first.** Ask the user what they see in the game client. Construction window,
   recipe window, encyclopedia — that's the live source. Use it.
2. **Accessible secondary sources.** Try in this order:
   - Community calculators that embed recipe data (e.g. cooking profit calculators that list
     ingredient requirements for food items) — these often aren't on the same WAF as the wikis.
     Example that worked this session: Albion Online Grind cooking profit calculator
     (`https://albiononlinegrind.com/cooking-profit-calculator`) — curl-able, no JS challenge,
     returns recipe ingredient lists for cooked food.
   - YouTube setup/guide videos for the specific game mechanic — descriptions and pinned comments
     often contain the actual numbers.
   - Search engine caches (Google cache, Bing cache) — sometimes serve the pre-challenge content.
   - Wayback Machine specific snapshot URLs (not wildcard searches — those rate-limit hard).
   - Community wikis on different domains (wiki.gg, fandom, independent wikis) — each has its own
     WAF posture; one may be open when others are blocked.
3. **If all sources are blocked, tell the user plainly.** Don't fabricate numbers. Say which sources
   you tried, what blocked them, and ask the user to supply the in-game data so you can proceed.

## Reference data captured this session

See `references/pork-omelette-recipe.md` for the verified Pork Omelette recipe (72 pork, 18 eggs,
26 corn per omelette; 9 cabbage per goose; 9 corn per pig), station channeling mechanics, and a
full list of sources that were blocked vs. accessible during the session. Use that file as a template
for recording verified recipe data for other game mechanics in future sessions.

## Support files

- `references/recipe-verification.md` — verified recipe data captured during research, with source
  and access method noted. Use when you've confirmed numbers from an accessible source and want to
  record them for the session.

## Verification check

Before giving a final number, confirm you have at least one of:
- The user's in-game data (construction/recipe window).
- An accessible source that returned the data (calculator, video, cache, open wiki).
- A clear statement that the number is unverified and based on memory.

If you have none of the above, you are guessing — say so.
