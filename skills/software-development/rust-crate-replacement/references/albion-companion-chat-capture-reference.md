# Albion Online Companion — Chat Capture Reference (2026-08-12)

The companion app's chat capture is the **working reference** for the translator. Any decoder or channel-map change in the translator should produce the same chat messages the companion sees in the same session.

## Capture Path

The companion uses two capture backends, selected at runtime:

### LinuxSocketPacketProvider (Linux, raw sockets)

File: `StatisticsAnalysisTool/Network/LinuxSocketPacketProvider.cs`

- Raw UDP sockets (`SocketType.Raw`, `ProtocolType.Udp`) bound to each local unicast IPv4/IPv6 address.
- No libpcap, no `setcap` needed — just `CAP_NET_RAW` or root.
- Receives all IP frames, parses IPv4/IPv6 headers manually, extracts UDP payloads.
- **Port filter**: `PhotonUdpPorts = [5055, 5056, 5058]` (NOT 4535).
- **LooksLikePhoton fallback**: if neither endpoint is on a known port, accept the packet anyway if `payload[0] is 0xF1 or 0xF2 or 0xFE`. This catches chat on dynamic ports.
- Delivers payload to `IPhotonReceiver.ReceivePacket(payload)`.

### LibpcapPacketProvider (cross-platform, libpcap/SharpPcap)

File: `StatisticsAnalysisTool/Network/PacketProviders/LibpcapPacketProvider.cs`

- BPF filter: `udp and (port 5055 or port 5056 or port 5058 or port 4535)` — includes 4535 unlike the LinuxSocket provider.
- No LooksLikePhoton fallback in the libpcap path — relies on port filter only.
- Uses `PacketDotNet` to parse Ethernet → IP → UDP, extracts `udpPacket.PayloadData`.

## Photon Receiver

The companion's `ReceiverBuilder` routes packets to event handlers. Chat events are handled by:

- `ChatMessageEventHandler` — event code 73 (ChatMessage), all channel-based chat.
- `ChatSayEventHandler` — event code 74 (ChatSay), local /say chat.
- `ChatWhisperEventHandler` — event code 75 (ChatWhisper).
- `JoinedChatChannelEventHandler` — event code 207, registers channel ID → type mapping.
- `LeftChatChannelEventHandler` — event code 208, unregisters.

## Verified Channel Map

From `StatisticsAnalysisTool/Network/ChatChannelTracker.cs` (verified 2026-08-11 live capture):

**Channel-type enum (JoinedChatChannel param 0) → runtime ID (param 1 / ChatMessage ChannelId):**

| Type enum | Channel type | Runtime ID | Notes |
|-----------|-------------|------------|-------|
| 2 | Recruitment | 18 | Verified: "RECLUTA" spam |
| 3 | LFG | 19 | Verified: "busco party/team" |
| 5 | Global | 21 | Verified: general English chat |
| 8 | Trade | 2 | Verified: joined runtime 2 |
| 24 | Guild | dynamic (high) | Verified pattern: high dynamic runtime ID |
| 25 | Alliance | dynamic (high) | Verified pattern: high dynamic runtime ID |
| 26 | Party | dynamic | Inferred by 24/25 sequence — needs live verify |
| 27 | Say | dynamic per cluster | Zone-local; 436, 182, 94, 307, 57, 471, 1479 seen across zones |

**Static known channel IDs (direct lookup, no join event needed):**
- 0 = Say (Local)
- 1 = Global (legacy, superseded by 21)
- 2 = Trade
- 18 = Recruitment
- 19 = LFG
- 21 = Global (verified 2026-08-11)
- 3517 = Guild (common, but dynamic)

**Name-based fallback**: when the type enum is unrecognized, derive from the channel name Albion sends — "LFG", "Trade", "Faction - Caerleon", "Guild", "Alliance", "Party", "Global", "Say", "Whisper" — case-insensitively.

## Current Translator Gaps vs Companion

| Feature | Companion | Translator |
|---------|-----------|------------|
| Port list | 5055, 5056, 5058 | 5055, 5056, 5058, 4535 |
| LooksLikePhoton fallback | Yes (0xF1/0xF2/0xFE) | No |
| Channel map | Verified enum→runtime + name fallback | Hardcoded IDs only (Say/Guild/Faction) |
| Channel types handled | Say, Whisper, Party, Guild, Alliance, Faction, Trade, LFG, Recruitment, Global | Say, Whisper, Party, Guild, Alliance, Faction, Trade, LFG, Unknown |
| Join/leave channel events | Handled (207/208) | Not handled |
| Capture backend (Linux) | Raw sockets + libpcap | libpcap only |
| Decode | Own C# decoder | `albion-network-lib` crate (license-blocked) |

## Testing Approach

Run both apps simultaneously while typing in-game chat. The companion's log shows the verified truth — compare the translator's captured messages against it. Key things to verify after any change:

1. Same chat messages appear in both apps at the same time.
2. Channel labels match (LFG shows as LFG, not Unknown).
3. Party chat is captured (currently not in the translator's channel map).
4. Messages on non-standard ports are captured (tests the LooksLikePhoton fallback).
