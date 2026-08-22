---
name: albion-photon-protocol
description: Use when decoding Albion Photon packets or chat channels.
tags: [albion, photon, protocol, packet-sniffing, chat, pcap, reverse-engineering]
triggers: ["Albion packet decode", "Albion chat channel mapping", "Photon event code", "Albion sniffer", "ChatMessage event 73", "JoinedChatChannel", "NewChatChannels", "Albion channel id"]
---

# Albion Online Photon Protocol (chat)

Ground truth for decoding Albion's chat traffic, verified against live captures
(2026-08, AlbionOnline-Translator + Companion). Reference implementations:
`beemerwt/albion-network-lib` (Rust, no license) and the local
AlbionOnline-Companion `StatisticsAnalysisTool/Network/` (C#). Both are
incomplete — where they disagree with live captures below, the captures win.

## Packet path

UDP ports 5055/5056/4535 (BPF filter). Photon header 12 bytes, then commands.
Chat rides SEND_RELIABLE(6)/SEND_UNRELIABLE(3)/SEND_FRAGMENT(8, needs
reassembly). Message type byte at payload[1]: 0=OperationRequest,
1=OperationResponse, 2=Event. The REAL Albion code rides in param 252
(events) / param 253 (operations), NOT the Photon-level byte.

## Event codes (param 252)

| Code | Event | Payload |
|------|-------|---------|
| 73 | ChatMessage | 0: channel runtime id (i64), 1: sender (str), 2: text (str) |
| 74 | ChatSay | 0: sender (str), 1: text (str). Also system messages with localization keys as param 0 (`@MOB_TRACKING_...`) — param 1 non-string then, drop them |
| 75 | ChatWhisper | 0: sender (str), 1: text (str) |
| 206 | NewChatChannels | ROSTER. 0: LE hex string of type enum (`"1b000000"`=27=Say), 1: array of runtime ids. Full roster at LOGIN; zone changes send only the new Say channel |
| 207 | JoinedChatChannel | 0: channel-TYPE enum, 1: RUNTIME id (ChatMessage's key), 2: name str ("" possible). Fires on zone change (Say) and mid-session joins |
| 208 | LeftChatChannel | 0: runtime id |

## Operation codes (param 253, client→server)

188=RegisterChatPeer, 189=SendChatMessage, 190=SendModeratorMessage,
191=JoinChatChannel, 192=LeaveChatChannel, 193=SendWhisperMessage, 194=Say.
Verified 189 wire: `{0: channel runtime id, 1: "text", 253: 189, 255: per-channel counter}`.
194 wire: `{0: "text", 253: 194}`.

**Your own messages:** the server echoes them back as normal event 73 with
your player name — do NOT build optimistic echo from op 189 or you get
duplicates. Op 189's value is learning which runtime id you typed into.

## Channel resolution

Two id spaces — confusing them is THE classic bug:
- **Type enum** (small, stable): 2=Recruitment, 3=LFG, 5=Global, 7=Faction,
  8=Trade, 24=Guild, 25=Alliance, 26=Party, 27=Say. Carried in 207 param 0
  and 206's hex string.
- **Runtime id** (dynamic per session/zone): the key in ChatMessage param 0.
  Say changes every zone; Guild/Alliance/Party are high dynamic ids.

Static runtime ids (capture-verified): 0=Say, 1=Global, 2=**English**
(language channel — was mislabeled "Trade" by the companion for months),
18=Recruitment, 19=LFG, 21=Global, 3517=Guild, 1856–1860/1868=Faction cities.
Unmapped → Unknown (never default to Say — it mislabels everything).

Resolution order: live map (206/207) → statics → Unknown. If capture starts
after login, party/guild stay Unknown until a relog (206) or relevant 207.

## Pitfalls

- **parse_event_code masking false positives:** the reference masks param 252
  to 16 bits (`to_signed_short`). A large event code whose low 16 bits are
  73/74/75 parses as chat. If "chat" decodes look like garbage/localization
  keys, suspect this — check the param count and param-0 string shape.
- **Companion code/comments contradict:** its JoinedChatChannelEvent assigns
  ChannelId=params[0], ChatIndex=params[1], but its tracker keys by the
  ChatIndex field. The verified truth is in the tables above.
- **Statics rot:** verify labels against live message content before trusting
  any hardcoded id table, including this one.
- **pcap needs caps:** `sudo setcap 'cap_net_raw,cap_net_admin=eip' <binary>`
  after EVERY build — relinking wipes file caps. "libpcap error: Attempt to
  create packet socket failed" = missing caps.
- **Verify pipelines headlessly:** a small `examples/` binary wiring
  sniffer→channel→print beats launching the GUI for every iteration.
- **Blocking capture loops belong in `spawn_blocking`, not `tokio::spawn`** —
  see the tokio-blocking-loop-starvation skill; a pcap `next_packet()` loop in
  an async task silently starves mpsc receivers.

See `references/live-captures.md` for the raw captured payloads these tables
were derived from.
