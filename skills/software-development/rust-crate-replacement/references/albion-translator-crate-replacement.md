# Albion Translator — Crate Replacement & Architecture Review (2026-08-12)

## The License Block

**`albion-network-lib`** (beemerwt's GitHub, v0.1.0) is the crate the translator's sniffer depends on for Photon protocol decoding. Its license is unresolved — beemerwt has an open issue about it — and that blocks the translator's monetization path (Lemon Squeezy paid product can't depend on an unlicensed crate without risking the same blocker).

The translator's own `photon.rs` already implements Protocol18 parameter table deserialization and chat event decoding (event codes 73/74/75) — it's standalone, owned code. It just isn't wired into the sniffer; the sniffer goes through `albion_network_lib::PhotonParser` instead.

## What the Own Decoder Already Does

From `src-tauri/src/photon.rs`:

- **Photon header parsing**: peer_id (2 bytes) + flags (1) + command_count (1) + timestamp (4) + challenge (4). Skips encrypted packets (flags == 1).
- **Command dispatch**: SendReliable (cmd_type 6) and SendUnreliable (cmd_type 7) feed into `decode_message`.
- **Message type dispatch**: type 2 = operation request, 3 = operation response, 4 = event. Only events are decoded for chat.
- **Event codes**: 73 = ChatMessage, 74 = ChatSay, 75 = ChatWhisper.
- **Protocol18 parameter table**: full `deserialize_parameter_table` with Reader struct handling compressed integers (u32, u64, i32, i64), strings, floats, bools, and all type codes 0-28.
- **Channel mapping**: hardcoded IDs (0=Say, 3517=Guild, 1868-1860=Faction by city). Missing: LFG, Trade, Recruitment, Party, Alliance, Global with verified runtime IDs.

## What the Sniffer Currently Does

From `src-tauri/src/sniffer.rs`:

- Uses `pcap` crate for capture (libpcap on Linux, Npcap on Windows).
- BPF filter: `udp port 5055 or udp port 5056 or udp port 5058 or udp port 4535`.
- Passes packets through `albion_network_lib::PhotonParser` (the blocked crate).
- Converts decoded `DecodedPacket::Event`/`DecodedPacket::Operation` with `ExtractedPacket::ChatMessage` into UI messages.
- Has a CIDR host filter for Albion server ranges but also passes non-CIDR traffic on Albion ports.

## What Needs to Change

### 1. Wire the own decoder into the sniffer (drop albion-network-lib)

Replace the `PhotonParser` path in the sniffer's packet loop with a direct call to the local `PhotonDecoder::decode()`. The sniffer already extracts UDP payloads via `extract_udp_payload` — feed those bytes into the local decoder instead of the library's parser.

Concrete change: in the `while running` loop, replace:
```rust
let before = parser.decoded_packets().len();
let _ = parser.receive_packet(udp_packet.payload, packet_number, ...);
let after = parser.decoded_packets().len();
for decoded in &parser.decoded_packets()[before..] { ... }
```
with:
```rust
if let Some(chat_msg) = decoder.decode(&udp_packet.payload) {
    // convert chat_msg (our own ChatMessage) into UI message
    tx.send(convert_to_ui_message(chat_msg, &mut translator).await).await.ok();
}
```

This eliminates the `albion_network_lib` dependency entirely. The `PhotonParserConfig`, `HostFilter`, `DecodedPacket` enum, and `extract_udp_payload` imports from `albion_network_lib` all go away.

### 2. Add LooksLikePhoton fallback

The companion app's `LinuxSocketPacketProvider.LooksLikePhoton()` accepts **any** UDP packet whose first byte is `0xF1`, `0xF2`, or `0xFE` — regardless of port. This catches chat on dynamic ports the game may use. The translator's sniffer has no such fallback; it only accepts packets on the hardcoded port list.

Add the same check: after the port filter, if neither endpoint is on a known Albion port, check `payload[0] is 0xF1 or 0xF2 or 0xFE` and pass it to the decoder anyway. The decoder's own length/type validation will reject non-Photon payloads.

### 3. Expand the channel map

The current `map_channel` in `photon.rs` only knows Say/Guild/Faction by hardcoded IDs. Port the companion's verified `ChatChannelTracker`:

**Channel-type enum → runtime ID (verified 2026-08-11):**
- 2 → Recruitment (runtime 18)
- 3 → LFG (runtime 19)
- 5 → Global (runtime 21)
- 8 → Trade (runtime 2)
- 24 → Guild (high dynamic runtime ID)
- 25 → Alliance (high dynamic runtime ID)
- 26 → Party (inferred, needs live verify)
- 27 → Say (zone-local, DYNAMIC per cluster — 436, 182, 94, 307, 57, 471, 1479 seen)

**Name-based fallback**: when the type enum is unrecognized, derive from the channel name Albion sends ("LFG", "Trade", "Faction - Caerleon", etc.), case-insensitively.

### 4. Cross-platform capture

Keep `pcap` crate for Windows (Npcap) and macOS. On Linux, offer raw-socket capture as an option (no libpcap, no `setcap` needed) following the companion's `LinuxSocketPacketProvider` pattern — bind a raw UDP socket to each local unicast address, receive all IP frames, parse IPv4/IPv6 headers manually, deliver UDP payloads that pass the port + LooksLikePhoton filter.

## Verification Target

The companion app's chat capture is the working reference. Any decoder change in the translator should produce the same chat messages the companion sees in the same session. Test by running both apps simultaneously while typing in-game chat and comparing the captured messages.

## Dependency Impact

Removing `albion_network_lib` from `Cargo.toml`:
- Drop the `albion-network-lib` line.
- Remove `use albion_network_lib::{...}` imports from `sniffer.rs`.
- The `pcap`, `tokio`, `tracing`, `lingua`, `ct2rs`, `reqwest`, `chrono`, `serde`, `thiserror`, `anyhow`, `dirs`, `ctrlc` dependencies all stay.
