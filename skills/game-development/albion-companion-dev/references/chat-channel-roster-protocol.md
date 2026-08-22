# Albion chat channel roster protocol (live-verified 2026-08-15, Americas)

Ground truth captured via the Translator app's raw-param dumps during a real
relog + party join. This supersedes guesswork in older tables where noted.

## Event 206 (NewChatChannels) — the channel ROSTER, now decoded

Fires at LOGIN with every channel you belong to, and again on ZONE CHANGE
for the zone-local Say channel only, and when you join a party mid-session.

Wire format:
- param 0: little-endian hex string of the channel-TYPE enum.
  `"1b000000"` → bytes LE → 0x1b = 27 = Say.
- param 1: array of RUNTIME channel ids of that type.
- param 252: 206 (the event code, as usual).

Verified captures:
```
{"0":"1b000000","1":[1682],"252":206}     # zone change: Say roster
# login roster produced: 1682->Say(27), 14735->Guild(24), 14736->Alliance(25)
# party joined mid-session: {"..":[25395]} type 26 -> Party
```

## Event 207 (JoinedChatChannel) — confirmed again at login

param 0 = channel-TYPE enum, param 1 = RUNTIME id, param 2 = name string
(EMPTY in every 2026-08-15 capture — don't rely on it).

Full verified set from one login (client then sends one op 191 per channel):
```
runtime 2     type 8   -> "Trade" per enum table (CONTESTED — see below)
runtime 18    type 2   -> Recruitment
runtime 19    type 3   -> LFG
runtime 21    type 5   -> Global
runtime 22    type 7   -> Faction
runtime 1682  type 27  -> Say (zone-local, fresh id per cluster)
runtime 14735 type 24  -> Guild
runtime 14736 type 25  -> Alliance
runtime 25395 type 26  -> Party (206 roster, mid-session join)
```

## OPEN CONFLICT: runtime id 2 = Trade or English?

- Type-enum table (companion-verified correlation) says type 8 = Trade.
- synth's in-game observation 2026-08-15: the content on runtime 2 is the
  ENGLISH language channel (banter/help, e.g. "Ill take two fish for 4 ore",
  "sorry about your mom noct"), "not trade chat".
- Content on 18/19 matches Recruitment/LFG exactly, so the enum table is
  right there; either type 8 means something else (language channel?) or
  runtime 2 really is Trade and its content is just banter-heavy in cities.
- RESOLVE by reading the in-game chat tab name for that channel (param 2
  name string arrives empty, so the wire won't tell you).
- Until resolved: translator labels static id 2 as English (user's call),
  knowing a 207 join will flip it to Trade — statics-vs-207 precedence is
  undecided. Whichever way it resolves, make ONE source win.

## Outbound ops (client->server, MESSAGE_OPERATION_REQUEST, op code in param 253)

- **189 SendChatMessage**: `{"0":<runtime_id>,"1":"<text>","253":189,"255":<n>}`
  — param 255 is a per-channel incrementing send counter (4,5,6,7 observed
  across two channels). Carries NO type info — can't label a channel from it.
- **194 Say**: `{"0":"<text>","253":194}` — no channel id (zone-local).
- **191 JoinChatChannel**: `{"0":<runtime_id>,"253":191}` — client sends one
  per channel at login right after the 206/207 burst.
- 188 RegisterChatPeer / 192 LeaveChatChannel / 193 SendWhisperMessage exist
  (operation_codes.rs) but were not observed in this capture.

## Own messages: NO optimistic echo needed

The server echoes your own channel chat back as normal event-73 ChatMessages
with sender = your name (verified: party + guild "test" messages echoed
~instantly after the op 189 went out). Say echoes as event 74. So a chat UI
gets self-messages for free — just label the channel right.

## Event 74 (ChatSay) structure verified

`{0: "<sender name>", 1: "<text>"}` for player says. ALSO fires for system
localization-key messages (`param 0 = "@MOB_TRACKING_ELEMENTAL_BOSS"`, param
1 not a string) — a decoder that requires param 1 as string drops these
harmlessly, which is what you want.

## Duplicate deliveries

Reliable-command retransmits get decoded twice (identical text ~370ms apart
observed 2026-08-15). A chat UI needs dedup (sender+text+~1s window) or it
shows doubles on lossy links (e.g. USB-tethered capture).
