# Albion server regions and community Discords

Verified August 10, 2026. Member/online counts are point-in-time only; re-check live invite metadata before quoting them.

## Regional server naming

- **Albion Americas** = the former **Albion West** server; use this for North America / English-language play unless the user has a reason to prefer another region.
- **Albion Asia** = the former **Albion East** server; Singapore/APAC.
- **Albion Europe** is the separate European server; Amsterdam/EU.
- AlbionStatus lists the underlying locations as Washington DC (West/Americas), Singapore (East/Asia), and Amsterdam (Europe): https://www.albionstatus.com/server-location
- Regional servers have separate worlds, economies, characters, guilds, and progression.
- Community Discords and older forum posts may still say **West** when they mean **Americas**.

## Community Discord discovery workflow

1. Start with the maintained faction hub: https://linktr.ee/FactionDiscords
2. If browser rendering hides target URLs, fetch the Linktree HTML and search its embedded JSON for `discord.gg` links and link titles.
3. Search the public Disdex index for broader/general communities:

   ```text
   https://disdex.io/api/v1/servers?q=<term>&limit=100&offset=0&sort=members
   https://disdex.io/api/v1/servers/<guild_id>
   ```

   Multi-word Disdex queries can over-filter. Query broad single terms (`albion`, `americas`, `english`, `lfg`) and filter results locally for Albion/NA/English/LFG relevance.
4. Verify each invite without joining via Discord's public invite endpoint:

   ```text
   https://discord.com/api/v10/invites/<invite_code>?with_counts=true&with_expiration=true
   ```

   Report only live HTTP-200 invites, including guild name, description, approximate member/presence counts, and whether `expires_at` is set. HTTP 404 with Discord error `10006` means the invite is dead/unknown.
5. If the guild widget is enabled, `https://discord.com/api/v10/guilds/<guild_id>/widget.json` can expose public widget channels and sometimes an instant invite. If disabled, use another public source; do not treat it as a blocker.
6. Prefer a server whose own Discord description explicitly matches the user's region/faction/language over older Reddit/forum posts; old invite links are frequently dead.
7. Do not join servers or use the user's Discord account for research.

## Verified general / LFG matches

- **Albion Online (official)** — https://discord.gg/albiononline
  - Discord description: “Albion Online | Official Discord Server”
  - Verified live, no expiration set; approximately 213,631 members / 26,835 online when checked.
  - Best general starting point even though it is not NA-only. Tell users to search channels/messages for `Americas`, `NA`, `LFG`, and guild recruitment.
- **Albion Online Grind** — https://discord.gg/albion-online-grind-1080852194091348010
  - Discord description: “A community for players who grind hard, mainly in Albion Online, but we sweat in other games too.”
  - Verified live, no expiration set; approximately 7,594 members / 1,073 online when checked.
  - General English-facing community, not Americas-exclusive.
- **VPG | Albion - Americas** — https://discord.gg/AKE4CNumA7
  - Verified live, no expiration set; approximately 27 members / 5 online when checked.
  - Exact Americas match, but very small; do not recommend it as the main option.
- **Small NA English Disboard listing** — https://disboard.org/server/1378111206241599530
  - Listing text: North American server, English VC, BZ content, dungeons, Ava roads, Hellgates, ganking, gathering/tracking, Arena.
  - Small listing (54 total members in the indexed page). Join is through Disboard; no direct invite was exposed in public metadata.

## Verified Caerleon / Americas matches

- **Caerleon Treasure Tales** — https://discord.gg/WwjczCSPXT
  - Discord description: “Albion online americas server home for Caerleon faction community and the guilds Treasure Tales & Tales of Bandits”
  - Verified live, no expiration set; approximately 2,517 members / 258 online when checked.
  - Best initial recommendation for an NA/English Caerleon community because the description explicitly says Americas and Caerleon.
- **⬛Caerleon faction⬛** — https://discord.gg/MCmK6Hcdkm
  - Discord description: “Active Caerleon discord hosting content anywhere from 22-04 UTC looking for more players (West Server)”
  - Verified live, no expiration set; approximately 288 members / 57 online when checked.
  - West Server here means the current Americas server.

## Response pattern

1. Lead with the game server recommendation: **Albion Americas** for NA/English.
2. Give direct Discord links immediately, ordered by usefulness/activity.
3. Label each as official, general, faction-specific, NA-only, or merely English-facing.
4. If NA-only general servers are small, say so plainly and recommend the practical stack: official Discord + relevant faction Discord + guild recruitment channels.
