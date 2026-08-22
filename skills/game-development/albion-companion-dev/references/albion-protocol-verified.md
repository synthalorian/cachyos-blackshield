# Albion Online Protocol — Live-Verified Facts

Verified 2026-08-11 on the Americas server via the Companion's own packet capture.
Channel IDs are server-assigned; these were true on this date/session. Treat the
name-based fallback in `ChatChannelTracker.MapChannelName` as the robust path and
these IDs as fast-path hints.

## Chat channel IDs (ChatMessage event 73, param 0) — RUNTIME id space

| ID | Channel | Evidence |
|----|---------|----------|
| 0  | Say/Local | prior mapping |
| 1  | Global | unconfirmed but consistent |
| 2  | Trade | trade chatter confirmed |
| 18 | Recruitment | "RECLUTA" guild spam confirmed |
| 19 | LFG | "busco party/team" spam confirmed |
| 21 | Global (English general/help) | "what is raging storm?", destiny-board questions, 2026-08-11 |
| 3517 | Guild (dynamic!) | changes per session |
| 34125 | Party (dynamic!) | synth's own party msgs ("synthalorian: wyre"), per-session |

WARNING (2nd pass, 2026-08-11): runtime ids 94, 436, 182, 307, 57, 471, 1479 are
all the SAME channel — type 27, the zone-local chat, which gets a fresh runtime
id per cluster. "94 = Faction" was a false positive (faction trash talk happened
in zone say). The old 1856–1868 per-city faction table was removed as
unverified. Never hardcode zone-local/party/guild runtime ids.

**Old guesses 3=LFG / 4=Recruitment were WRONG.**

## JoinedChatChannel (207) — TWO different ID spaces (root-cause bug 2026-08-11)

- **param 0 = channel-TYPE enum** (small stable number)
- **param 1 = runtime channel ID** — the id space ChatMessage actually uses
- **NO name param exists.** RAW dump verified: only `[0:typeEnum] [1:runtimeId]
  [252:207]` is sent. Param 2 always empty because it isn't there.

`ChatChannelTracker.JoinChannel` originally keyed its dictionary by param 0 →
joined channels never matched ChatMessage lookups → everything non-hardcoded
showed `Unknown`. Fixed: key by param 1 (runtime id).

Verified type-enum → type (by correlating join events with live content):

| typeEnum | Type | Runtime id it joined | Status |
|----------|------|---------------------|--------|
| 2 | Recruitment | 18 | verified |
| 3 | LFG | 19 | verified |
| 5 | Global | 21 | verified |
| 7 | Faction? | 22 | inferred, unverified |
| 8 | Trade | 2 | verified |
| 24 | Guild | high dynamic (e.g. 15668) | verified pattern |
| 25 | Alliance | high dynamic (e.g. 5813) | verified pattern |
| 26 | Party | high dynamic | inferred by 24/25 sequence |
| 27 | Zone-local chat | DYNAMIC per cluster (436, 182, 94, 307...) | verified |

## Party events — verified live 2026-08-11 (2nd pass)

- **PartyPlayerJoined (233)**: fires once PER MEMBER on join/re-zone.
  `0=PARTY id (constant across members!), 1=member GUID byte[16], 2=member NAME,
  3-9=stats`. **No member ObjectId** — the old "0=ObjectId" assumption was
  WRONG (every member reported the same id 27562). Names → PartyTracker only;
  meter names still resolve via NewCharacter.
- **PartyJoined (231)**: name array often arrives EMPTY in the real event —
  roster effectively comes from PartyPlayerJoined. Never clear on empty payload.
- **PartyPlayerLeft (235)** / PartyLeaderChanged: param 0 = PARTY id too; the
  departing member is not identifiable from the payload.
- **PartyDisbanded (232)**: clears the roster.

Event code numbers = ordinal position in the `EventCodes` enum — compute
programmatically (regex the enum), never count lines by eye.

## Event duplication

Every health tick fires BOTH `HealthUpdate` (event 6) AND `HealthUpdates` batch
(event 7) — identical values, same millisecond in logs. Dedupe key:
`causerId:affectedId:timestamp:healthChange`.

`HealthUpdatesEvent` params are parallel arrays: 0=ids, 1=timestamps,
2=healthChanges, 3=newHealthValues, 4=effectTypes, 5=effectOrigins, 6=causerIds,
7=spellIndexes. Arrays arrive TYPED (`int[]`/`long[]`/`float[]`) — never `object[]`.

## JoinResponse (operation, fires on zone enter)

- param 0: UserObjectId (long) — changes per zone
- param 2: Username (string)
- param 8: MapIndex (string) — cluster index "3003" or "@ISLAND@<guid>"
- param 33: Silver (FixPoint), 34: Gold, 37: LearningPoints, 41: Reputation
- Fires twice per zone change (dedupe if it matters)

## Cluster index → zone name

`https://raw.githubusercontent.com/ao-data/ao-bin-dumps/master/formatted/world.json`
is a flat array of `{"Index": "3003", "UniqueName": "Caerleon"}` — UniqueName is
already the display name (1421 entries). `@ISLAND@<guid>` → display "Island".

## NewCharacter event

Params: 0=ObjectId, name, guild (numeric ID, NOT name — guild name needs GuildInfo),
equipment array. Fires per spawn; entities present before tracking starts are
unknown until they re-zone.

## UpdateFame event

0=ObjectId, 1=TotalPlayerFame, 2=FameWithZoneMultiplier, 3=ZoneFame,
4=Multiplier, 5=IsPremiumBonus, 10=SatchelFame, 17=BonusFactor.
SatchelFame>0 ⇒ crafting. Combat-vs-gathering distinction NOT yet determined —
ground-truth logging added 2026-08-11 to capture paired samples.
