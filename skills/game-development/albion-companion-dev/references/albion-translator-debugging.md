# Albion Translator — Sniffer/Debug Reference

## CRITICAL: know which chat path your sniffer uses

Albion chat can arrive on the wire through **two different paths**, and which one your sniffer sees depends on which protocol layer you're decoding. Do not debug "no chat" before you know which path your code targets.

### Path A — Photon Events on UDP (what the Translator app's own `photon.rs` decoder targets)

The Translator app's standalone `src-tauri/src/photon.rs` decodes Photon Events directly from UDP packets on ports 5055/5056/4535. Chat arrives as **Photon Event 73 (ChatMessage)**, 74 (ChatSay), 75 (ChatWhisper) inside a `SendReliable`/`SendUnreliable` command. The event code lives in Photon parameter 252; the chat payload (channel_id, player_name, text) is in params 0/1/2.

**This path works.** The Translator app has decoded live chat on UDP from Americas servers — verified 2026-08-14 (channel_ids 2/Trade, 18/Recruitment, 19/LFG all decoded, `Event code: 73` logged). The UDP protocol DOES carry chat when you decode Photon Events. The old claim that "UDP carries no chat" was wrong for this decoder path and should not block debugging.

### Path B — Steam overlay WebSocket (TCP, localhost:57343)

The Albion client's Steam overlay (`gameoverlayui`) relays chat through a **TCP WebSocket on localhost:57343**. This is a separate channel from the UDP game protocol. Some companion apps saw chat arrive as **OperationResponse 43** through a library path, and a library bug that dropped OperationResponses made it *look* like UDP had no chat. The WebSocket path is the one that matters if you're hooking Steam IPC rather than decoding Photon UDP.

**Before debugging "no chat" for more than 10 minutes, verify which path your code targets and whether chat is actually on that path:**

```bash
# Confirm chat is happening in-game right now (player presence ≠ chat)
# Then check what's on the wire:
ss -upn | grep Albion-Online | grep -v 127.0.0.1   # UDP game protocol
ss -tnpa | grep 57343                               # Steam WebSocket
```

- If your sniffer decodes Photon Events on UDP and there's visible in-game chat but zero `Event code: 73` log lines → decoder bug (event code not extracted, wrong param source, channel_map empty — see pitfalls below).
- If you see UDP packets but no Photon Events at all and you're NOT decoding the Steam WebSocket → you may be on the wrong path; the UDP packets you're seeing may be movement/state only if your decoder isn't surfacing Events.
- If chat in-game is silent → there's nothing to capture. Type in-game.

---

## Log-driven chat verification (the technique that works)

When the sniffer is running with `tracing` at debug level, the log is your ground truth. Don't guess — grep it.

### Step 1 — Confirm chat is being decoded at the decoder level

```bash
# Count how many Photon Events the decoder saw
grep -c "EVENT photon_code=3" tauri-dev.log

# Count actual chat messages (these are the ones that MATTER)
grep -c "ChatMessage: channel_id=" tauri-dev.log

# Count JoinedChatChannel / LeftChatChannel events (channel map population)
grep -c "Chat channel joined\|Chat channel left" tauri-dev.log

# Count by event code (what the decoder resolved)
grep "Event code:" tauri-dev.log | grep -oP 'Event code: \K\d+' | sort | uniq -c | sort -rn
```

If `ChatMessage: channel_id=` count is zero but `Event code: 73` is non-zero → decoder recognized the event but the chat payload extraction failed (missing params, deserialization error, or channel_map returned Unknown).

### Step 2 — Check channel mapping

```bash
# See what channels chat is actually arriving on
grep "ChatMessage: channel_id=" tauri-dev.log | grep -oP 'channel_id=\K\d+' | sort | uniq -c | sort -rn

# See when JoinedChatChannel events arrived vs chat
grep -n "Chat channel joined\|ChatMessage: channel_id=" tauri-dev.log | head -40
```

If JoinedChatChannel lines appear AFTER ChatMessage lines → the channel_map is empty when chat first arrives. Early messages land as Unknown until the map fills.

### Step 3 — Check what the decoder is actually seeing (raw event dump)

```bash
# Find a ChatMessage line and look at the preceding raw EVENT line
grep -B1 "ChatMessage: channel_id=" tauri-dev.log | head -20
```

The raw EVENT line shows `photon_code=... params=N raw=[...]`. If params=2 and the raw bytes are there, the decoder is receiving the event but the param deserialization may be failing to extract params 0/1/2 (channel_id, player_name, text).

### Verify the game is actually producing chat traffic

Chat packets only appear on the wire **when someone types in-game**. Player presence in a town generates movement/keepalive packets, NOT chat packets. Before digging into the decoder, confirm:

- There is visible text in the Albion client's chat window right now.
- Someone (not just bots/NPCs) has spoken recently.

If nobody has typed, the sniffer correctly shows nothing — there's nothing to capture. The fix is to type in-game, not to change code.

---

## The two racing conditions that cause "Unknown" channels

### Race 1 — channel_map builds too late

The `channel_map` (HashMap<i64, ChatChannel>) is populated by `JoinedChatChannel` (event 207) handlers. If chat messages arrive before any JoinedChatChannel events, the map is empty and `map_channel()` falls through to the static fallback. Static fallback only covers channel_ids 0, 3517, 1856–1868. Chat on channel_ids 2, 18, 19 hits `_ => Unknown`.

The log showed this exact pattern: chat at 08:59–09:02, JoinedChatChannel at 09:05+. The map was empty when chat first arrived.

### Race 2 — `from_chat_index` is too narrow

The `from_chat_index` function maps only 3 chat indices: 27→Say, 24→Guild, 29→Faction. The ref implementation (`albion-network-lib-ref/src/albion/types.rs`) has the same 3 mappings but defaults unknown indices to Say (not Unknown) and uses `from_i64` for well-known channel_ids.

Two inconsistencies in the current app:
1. Unknown channels render as `Unknown` instead of `Say` (the ref defaults to Say)
2. Display name mismatch: current app returns `Say`/`Guild`/`Faction`, ref uses `Local`/`Guild`/`Faction`

### Fix approach

Either ensure JoinedChatChannel events arrive before chat (may not be possible — the game may send chat before channel joins on some server paths), or expand the static `map_channel` fallback to cover more well-known channel_ids, or default unknown channels to Say (matching the ref). The ref also shows that some channel_ids are session-scoped dynamic numbers — only the JoinedChatChannel event can map them.

---

## CIDR vs port filtering

The sniffer filters on UDP ports 5055/5056/4535 only — no IP/CIDR filtering. The `albion-network-lib-ref` implements `HostFilter` (CIDR ranges loaded from a file) and applies it to decoded packets. Without CIDR filtering:

- All UDP on those ports passes through, including non-Albion traffic
- No `hosts.txt` exists in the Translator project
- The sniffer can't distinguish Albion server traffic from other UDP on the same ports

**To add CIDR filtering:** port the `HostFilter` from the ref (`capture/hosts.rs` — loads CIDR ranges from a file, supports IPv4/IPv6, comment lines with `#`), create a `hosts.txt` in the project with Albion server ranges, and apply it in the sniffer before forwarding messages. The ref's `CaptureFilter` combines host filtering with port-based fallback.

---

## Tracing noise management

The `tauri-dev.log` is dominated by photon DEBUG spam — every packet dumps raw bytes. With 113K+ `EVENT photon_code=3` lines in a single session, the log balloons to 35MB+ and drowns actual signal. The `tracing-subscriber` env filter is set to `debug` for the photon module.

**To reduce noise:** change the env filter from `debug` to `info` or `warn` for `albion_translator_lib::photon`. Keep `debug` only when actively hunting a decoder bug. At `info` level, only `ChatMessage:`, `Chat channel joined/left:`, and `Event code:` lines appear — the signal you actually care about.

---

## Common failure modes

| Symptom | Likely cause |
|---------|-------------|
| Chat messages decoded but all show `channel=Unknown` | `channel_map` empty when chat arrives (Race 1), OR channel_id not in static fallback map |
| JoinedChatChannel events appear AFTER chat messages in log | channel_map populates too late; early messages can't be mapped |
| `from_chat_index` returns Say for unknown indices but app shows Unknown | mismatch between `from_chat_index` default and `map_channel` fallback |
| 100K+ photon EVENT lines but only 26 ChatMessage lines | Photon decoder is parsing everything but only a tiny fraction are chat events; tracing noise drowning signal |
| No `hosts.txt` in project, no CIDR filtering | sniffer passes all UDP on Albion ports regardless of source IP |
| Log grows to 35MB+ in one session | photon tracing at debug level; every packet dumps raw bytes |

---

## Verified findings from 2026-08-14 session

### Chat IS working via Photon Events on UDP

The log at `/tmp/opencode/tauri-dev.log` (156,935 lines, ~35MB) confirmed:
- 171 lines with `Event code: 73` (ChatMessage events recognized)
- 26+ `ChatMessage: channel_id=...` lines decoded and forwarded
- Channel_ids seen: 2 (Trade), 18 (Recruitment), 19 (LFG)
- Senders: moltorlol, gatoatroz, vi18, ootick, chadaphract, hc1warrior, heroxstarx, avalir99
- Languages: Spanish, Russian, English all present in decoded messages

### Chat arrives BEFORE channel map is populated

- Chat messages: 08:59:13 – 09:02:30
- First JoinedChatChannel: 09:05:16 (channel_id=436, index=27 → Say)
- The channel_map was empty for the first ~6 minutes of chat

### Photon Event code 3 (Move) dominates the log

- 114,099 lines with `EVENT photon_code=3 params=2` (Move events)
- These are NOT chat — they're movement/position updates
- They drown out the 171 actual chat-related `Event code: 73` lines

### Reference implementation at /tmp/opencode/albion-translator-ref/

A full standalone Rust implementation with richer translation backend architecture:
- `src/translator.rs` (1129 lines) — engine-neutral `TranslationRouter` with pluggable backends: ct2, argos (deprecated), google, http (template-driven, vLLM-compatible), noop
- `TranslationConfig::from_env()` — env-driven configuration
- SQLite caching for Google translations
- Model manifest-driven loading (`models/manifest.json`)
- Device selection: cpu/cuda/auto
- CLI args: `--pretty`, `--debug`, `--all`, `--help`
- `build.rs` reads manifest, warns on missing models
- Translation sidecar (deprecated): FastAPI on port 8787, Argos packages

This ref is significantly more developed than the current `src-tauri/src/translator.rs` (~400 lines, single-file engine with Google free + ct2 + lingua detection).

### Reference implementation at /tmp/opencode/albion-network-lib-ref/

A copy of the `albion-network-lib` crate with:
- `src/albion/types.rs` — `ChatChannel` enum (Say=27, Guild=24, Faction=29), `from_chat_index` (same 3 mappings, defaults to Say), `from_i64` (0→Say, 3517→Guild, 1856–1868→Faction, default Say)
- `src/capture/hosts.rs` — `HostFilter` struct: loads CIDR ranges from file, supports IPv4/IPv6, comment lines with `#`, `from_file(path)` and `from_cidrs(iter)` constructors, `contains(ip)` method
- `src/albion/chat_state.rs` — `ChatState` struct with `channels_by_id: HashMap<i64, ChatChannel>`, `join_channel(channel_id, chat_index)`, `leave_channel(channel_id)`, `channel_type(channel_id) -> Option<ChatChannel>`
- `src/albion/codes/event_codes.rs` — full `EventCode` enum (681 variants), `try_from(u8)` implementation
- `src/albion/extractor.rs` — `extract_chat_message`, `extract_joined_chat_channel`, `extract_left_chat_channel`, uses `chat_state.channel_type(channel_id)` for mapping
- `hosts.txt` — not present in this checkout (file is optional, `from_file` returns error if missing)

### What still needs fixing

1. **Add `hosts.txt` + CIDR filtering** — port `HostFilter` from ref, create `hosts.txt` in project
2. **Fix channel display names** — `Display` impl returns `Say`/`Guild`/`Faction`, ref uses `Local`/`Guild`/`Faction`
3. **Default unknown channels to Say** — match ref behavior, not Unknown
4. **Investigate why JoinedChatChannel events arrive after chat** — check if event code mapping or param reading is off, or if the game sends them in a different order on some server paths
5. **Expand static channel_id fallbacks** if needed — ref's `from_i64` covers 0, 3517, 1856–1868; current `map_channel` has these but they don't cover channel_ids 2, 18, 19 seen in the log

### Files

- `src-tauri/src/sniffer.rs` — packet capture loop, UDP port filter (no CIDR), channel_map population
- `src-tauri/src/photon.rs` — own Protocol18 decoder: `decode()`, `decode_event()`, `decode_chat_message()`, `handle_joined_chat_channel()`, `handle_left_chat_channel()`, `map_channel()`, `from_chat_index()`, `is_relevant_event()`, `parse_event_code()`
- `src-tauri/src/lib.rs` — Tauri setup, `start_capture`/`stop_capture` commands, message forwarder
- Reference: `/tmp/opencode/albion-network-lib-ref/` — `src/albion/types.rs`, `src/capture/hosts.rs`, `src/albion/chat_state.rs`, `src/albion/codes/event_codes.rs`, `src/albion/extractor.rs`
- Reference: `/tmp/opencode/albion-translator-ref/` — `src/translator.rs`, `build.rs`, `Cargo.toml`, `README.md`
