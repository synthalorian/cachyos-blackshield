# Photon UDP Envelope — Live-Verified Wire Layout (Albion Online)

Captured 2026-08-11 from live Americas-server traffic (wlan0, ports 5055/5056)
with `AlbionOnline-Translator/src-tauri/src/bin/wire_probe.rs` — a hex-dump
probe written specifically so the parser comes from WIRE TRUTH, not from any
library's comments. Event-layer facts (event codes, channel IDs, party events)
live in `albion-protocol-verified.md`; this file is the ENVELOPE layer.

## Peer header (12 bytes)

```
peer_id(2) | crc_enabled(1) | command_count(1) | timestamp(4) | challenge(4)
```
- `crc_enabled == 1` → encrypted, skip.
- Multiple commands per packet are normal (7 seen in one packet).

## Command header (12 bytes), then data

```
type(1) | channel_id(1) | flags(1) | reserved(1) | length(4 BE) | seq(4 BE)
```
- `length` INCLUDES the 12-byte command header. Verified across 7 consecutive
  commands — next command starts exactly at `offset + length`.
- type 6 = SendReliable, 7 = SendUnreliable → data commands (game traffic).
- type 8 = SendReliableFragment (reassembly: seq, totalLen, fragOffset — rare
  on the chat path; implement if a message ever arrives split).
- type 5 with channel `0xff` = keepalive/control (24-byte packets both
  directions on 5055 and 5056). Skip.

## Albion's data-command framing (inside types 6/7)

```
00 00 | packet_counter(2 BE) | f3 | msg_type(1) | ...
```

- `00 00` prefix, then a big-endian u16 counter that increments across packets
  (watched c5→c6→cc→ce→cf→d0→d8→da live). Albion's own sequencing.
- `f3` = Protocol16 magic byte. Scan for it at fixed offset (4 bytes into the
  data section) — verified on every data command captured.
- `msg_type`: 2=operation request, 3=operation response, 4=event.

## Event payload (msg_type 4)

```
event_code(1) | param_count(1) | [key(1) type(1) value...]...
```

- Movement/state spam (the bulk of traffic — 46-byte commands seen at high
  frequency) uses type codes BEYOND the classic Photon set: `0x43` observed
  in the wild. A chat-path parser should parse ONLY the events it cares about
  (73 ChatMessage, 74 ChatSay, 75 ChatWhisper, 207 JoinedChatChannel) and
  SKIP unknown events/types rather than trying to fully deserialize the
  stream.
- Parameter value types needed for chat: 7=string (count-prefixed),
  10=compressed i64 (zigzag varint), plus the small-int family. Zigzag varint
  decode: `value |= (byte & 0x7f) << shift; stop when high bit clear;
  signed = (v >> 1) ^ -(v & 1)`.

## Ground-truth discipline (synth's style — pitfall 9 of the skill)

1. Write/extend the probe, hex-dump the wire, READ THE BYTES.
2. Write the parser against the dump.
3. Verify against live capture (game is usually already running — capture
  during a busy zone for movement spam; ask synth to send a chat message for
  the chat events).
4. Comments in ANY dependency (and old hardcoded ID tables) are hints, never
  truth. Two different ID spaces exist (see albion-protocol-verified.md).
