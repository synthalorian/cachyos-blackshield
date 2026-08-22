# Reference Implementation Audit — Albion Translator

## When to use this

When your decoder isn't surfacing chat (or surfacing it wrong), and you have access to a known-working reference implementation of the same protocol layer, audit your code against the reference to find the gap. This is the technique used in the 2026-08-14 Translator debugging session.

## The pattern

### 1. Locate or obtain a reference checkout

The reference should be a complete, compilable implementation of the same protocol layer your code targets (Photon UDP decoding, chat extraction, channel mapping). In this session, two references were available in `/tmp/opencode/`:

- **`albion-network-lib-ref/`** — the third-party `albion-network-lib` crate (the lib the Companion app originally depended on). Contains `ChatChannel` enum, `from_chat_index`, `from_i64`, `HostFilter`, `ChatState`, full `EventCode` enum, and the extractor that maps channels at the event level.
- **`albion-translator-ref/`** — a standalone Rust implementation with a richer translation backend architecture than the current Translator app.

### 2. Read the reference's channel mapping code

The key question: how does the reference resolve a `channel_id` from a `ChatMessage` event to a `ChatChannel` enum?

**What the reference (`albion-network-lib-ref/src/albion/types.rs`) does:**
- `ChatChannel` enum: `Say = 27`, `Guild = 24`, `Faction = 29`
- `from_chat_index(value)` — maps chat index to channel: 27→Say, 24→Guild, 29→Faction, `_ → Say` (defaults to Say for unknown)
- `from_i64(value)` — maps well-known channel_ids: 0→Say, 3517→Guild, 1856–1868→Faction, `_ → Say`
- `Display` impl: `Say → "Local"`, `Guild → "Guild"`, `Faction → "Faction"`

**What the current app (`photon.rs`) does:**
- `ChatChannel` enum: `Say`, `Guild`, `Faction`, `Alliance`, `Global`, `Trade`, `LFG`, `Faction`, `Unknown`
- `from_chat_index(index)` — maps 27→Say, 24→Guild, 29→Faction, `_ → Say`
- `map_channel(channel_id)` — checks `channel_map` (from JoinedChatChannel events), then static fallback: 0→Say, 3517→Guild, 1856–1868→Faction, `_ → Unknown`
- `Display` impl: `Say → "Say"`, `Guild → "Guild"`, `Faction → "Faction"`, `Unknown → "Unknown"`

### 3. Identify the gaps

| Gap | Reference | Current app | Impact |
|-----|-----------|-------------|--------|
| Unknown channel default | Say | Unknown | Chat on unmapped channels shows Unknown instead of Say |
| Display name for Say | "Local" | "Say" | Inconsistent channel labels |
| Static channel_id coverage | 0, 3517, 1856–1868 | same | Neither covers channel_ids 2, 18, 19 seen in log |
| Channel map population | JoinedChatChannel events via `ChatState::join_channel` | JoinedChatChannel events via `handle_joined_chat_channel` | Same mechanism, different timing |

### 4. Read the reference's filter code

**What the reference (`albion-network-lib-ref/src/capture/hosts.rs`) does:**
- `HostFilter` struct with `ranges: Vec<CidrRange>`
- `CidrRange` enum: `V4 { network: u32, mask: u32 }`, `V6 { network: u128, mask: u128 }`
- `from_file(path)` — reads CIDR ranges from a file, skips comments (`#`) and blank lines, returns error on invalid entries
- `from_cidrs(iter)` — builds from an iterator of CIDR strings
- `contains(ip: IpAddr)` — checks if IP falls in any range
- IPv4 and IPv6 prefix masking

**What the current app (`sniffer.rs`) does:**
- No CIDR filtering at all
- Only filters on UDP ports: `udp port 5055 or udp port 5056 or udp port 4535`
- No `hosts.txt` in the project

### 5. Read the reference's event handling code

**What the reference (`albion-network-lib-ref/src/albion/extractor.rs`) does:**
- `extract_chat_message(parameters)` — extracts channel_id (param 0), player_name (param 1), message (param 2)
- `extract_joined_chat_channel(parameters)` — extracts chat_index (param 0), channel_id (param 1), calls `chat_state.join_channel(channel_id, chat_index)`
- `extract_left_chat_channel(parameters)` — extracts channel_id (param 0), calls `chat_state.leave_channel(channel_id)`
- Uses `chat_state.channel_type(channel_id)` to resolve channel for ChatMessage events

**What the current app (`photon.rs`) does:**
- `decode_chat_message(params)` — same param extraction (0=channel_id, 1=player_name, 2=message)
- `handle_joined_chat_channel(params)` — extracts chat_index (param 0), channel_id (param 1), calls `channel_map.insert(channel_id, ChatChannel::from_chat_index(chat_index))`
- `handle_left_chat_channel(params)` — extracts channel_id (param 0), removes from map
- Uses `map_channel(channel_id)` for resolution

### 6. Check the log for timing evidence

The reference tells you WHAT should happen. The log tells you WHEN it actually happens.

```bash
# Find the temporal relationship between JoinedChatChannel and ChatMessage
grep -n "Chat channel joined\|ChatMessage: channel_id=" tauri-dev.log | head -40
```

In this session: JoinedChatChannel events appeared at line ~2260+ (09:05+), ChatMessage events at line ~2260- (08:59–09:02). The Join events came AFTER the chat — confirming Race 1.

### 7. Port the fix

Based on the gap analysis, port the reference's approach:

1. **Channel default:** change `map_channel` fallback from `Unknown` to `Say` (matching ref)
2. **Display names:** change `Display` impl to use "Local" instead of "Say" (matching ref)
3. **CIDR filtering:** port `HostFilter` from ref, create `hosts.txt` in project
4. **Investigate timing:** determine why JoinedChatChannel arrives after chat — may require live capture analysis

## What this technique catches

- **Wrong defaults** — your code defaults unknown channels to Unknown, reference defaults to Say
- **Naming inconsistencies** — your Display returns "Say", reference returns "Local"
- **Missing infrastructure** — reference has CIDR filtering, your code doesn't
- **Timing bugs** — reference shows the correct mechanism, log shows the mechanism fires too late
- **Assumption errors** — reference's `from_chat_index` defaults to Say, your `map_channel` defaults to Unknown; the difference is a one-line change but causes every unmapped channel to render wrong

## Limitations

- The reference may be wrong too — verify reference claims against live captures before porting
- The reference may target a different game version or server region — channel_ids and event layouts can differ
- Porting infrastructure (HostFilter) is straightforward; porting timing-dependent behavior (when JoinedChatChannel arrives) may require understanding why the timing differs
