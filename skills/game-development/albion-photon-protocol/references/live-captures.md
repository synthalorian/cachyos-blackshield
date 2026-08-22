# Live capture ground truth — Albion chat protocol

Captured 2026-08-15 with AlbionOnline-Translator (own Photon decoder, UDP 5055/5056).
These are the payloads the channel tables in SKILL.md were derived from.

## NewChatChannels (event 206) — the roster

Zone-change roster (Say only):

```json
{"0":"1b000000","1":[1682],"252":206}
```

- param 0: `"1b000000"` = little-endian u32 0x1b = 27 = Say type enum, as a hex STRING
- param 1: array of runtime channel ids of that type
- At login: full roster (one per channel type). Zone change: only the new zone's Say.

## JoinedChatChannel (event 207)

```
Chat channel joined: runtime=1682 type_enum=27 name="" -> Say
```

param 0 = type enum (27), param 1 = runtime id (1682), param 2 = name (may be "").
LeftChatChannel (208) fired on zone-out with param 0 = 1682. Confirms runtime ids
are per-zone for Say (1682 → 1683 across one zone transition).

## Outbound operations (local player sends)

SendChatMessage (op 189) — player typed "test" in party, then guild:

```json
{"0":18434,"1":"test","253":189,"255":4}
{"0":14735,"1":"test","253":189,"255":5}
```

- param 0 = channel runtime id (18434 / 14735 — dynamic, per session)
- param 1 = text
- param 255 = per-channel send counter (increments per message per channel)

Say (op 194) — player typed "test" in Say:

```json
{"0":"test","253":194}
```

## Own-message echo

Every one of those sends ALSO arrived back as a normal event 73:

```
ChatMessage: channel_id=18434 channel=Unknown sender=synthalorian text="test"
ChatMessage: channel_id=14735 channel=Unknown sender=synthalorian text="test"
```

No optimistic-echo needed; the server round-trips your own messages.

## ChatSay (event 74) raw wire shapes

Player say (decodes fine — param 0 name, param 1 text):

```
[01, 06, 00, 07, 0c, "synthalorian", 01, 07, 04, "test", 02, 22, ..., 05, 43, ...]
```

System message sharing code 74 (param 0 = localization key, no text param → drop):

```
[01, 06, 00, 07, 1c, "@MOB_TRACKING_ELEMENTAL_BOSS...", ...]
```

## Channel id → observed content (2026-08-15, Martlock-area)

| Runtime id | Content observed | Label |
|---|---|---|
| 2 | "Ill take two fish for 4 ore", English banter | English |
| 18 | "NOX GUILDA 4FUN...", "RECLUTA..." spam | Recruitment |
| 19 | "busco heal, tank, flami...", "alguien pára mazmorra grupal?" | LFG |
| 21 | "no entendí" (mixed-language help) | Global |
| 1682 | "GG" (zone-local, post-207 join) | Say |
| 18434 / 14735 | synth's own party/guild tests | dynamic (party/guild) |

## parse_event_code masking hazard

`to_signed_short` masks param 252 to 16 bits before matching. A genuine large
event code with low bits == 74 (e.g. 0x????004A) would false-positive as
ChatSay. The `@MOB_TRACKING` events above parse as 74 — whether that's a true
shared code or a masking artifact is unverified; either way the decoder must
tolerate non-chat param shapes on chat codes.
