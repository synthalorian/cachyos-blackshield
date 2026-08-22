# Albion Online chat channel IDs (verified from live capture)

Verified 2026-08-11 on the Americas server via the Companion's packet sniffer
(method: log every `ChatMessage` event's raw channel_id, match IDs against
message content — LFG spam vs guild recruitment spam is unmistakable).

| ID        | Channel      | Evidence |
|-----------|--------------|----------|
| 0         | Say/Local    | upstream SAT + protocol docs |
| 1         | Global       | upstream (not re-verified) |
| 2         | Trade        | verified: trade chatter |
| 18        | Recruitment  | verified: "RECLUTA..." guild spam |
| 19        | LFG          | verified: "busco party/team..." |
| 1856-1868 | Faction (per city: 1856 Martlock, 1857 Bridgewatch, 1858 Lymhurst, 1859 Fort Sterling, 1860 Caerleon, 1868 Thetford) | upstream |
| 3517      | Guild        | DYNAMIC per session — upstream guess, not stable |

## Pitfalls

- **IDs 3/4 are NOT LFG/Recruitment** — an earlier guess had them wrong; real IDs are 19/18. Channel IDs for global channels are small integers but NOT 1,2,3,4 sequential.
- **Guild/party/alliance channel IDs are server-assigned per session.** Hardcoding only works for global/faction channels. `JoinedChatChannel` events (event code 209 per SAT's EventCodes enum) should map dynamic IDs, but its parameter structure is not what naive parsers assume (param 0 ≠ channelId — observed multiple channels reporting the same "id" 27 with varying second params). Robust fallback: parse the channel NAME Albion sends ("LFG", "Trade", "Faction - Caerleon") case-insensitively for known tokens (lfg/looking, recruit, trade, faction, guild, alliance, party/group, global/english, say/local, whisper).
- Chat events: ChatMessage=73, ChatSay=74, ChatWhisper=75 (Albion Photon event codes, Protocol18).
- Chat messages only flow while the sniffer runs; channels joined at login won't re-announce unless a `NewChatChannels` event (code 208) fires on zone change.
