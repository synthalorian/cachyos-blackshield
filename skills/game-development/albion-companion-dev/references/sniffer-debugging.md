# Translator Sniffer Debugging Guide

## Problem: App shows IDLE, no chat messages

When the Translator app launches but shows nothing in the chat feed, follow this debugging path.

## Step 1: Verify the port filter matches the companion app

The companion app (Avalonia/.NET) captures on ports **[5055, 5056, 5058]**. The translator sniffer must match.

**Check:** `grep "cap.filter" src-tauri/src/sniffer.rs`

**Expected:** `cap.filter("udp port 5055 or udp port 5056 or udp port 5058 or udp port 4535", true)`

**Bug found this session:** The sniffer only had `udp port 5056 or udp port 4535` — missing 5055 and 5058. This is why the companion app showed chat but the translator didn't.

## Step 2: Verify the link type is passed to extract_udp_payload

The sniffer uses `extract_udp_payload(packet.data, None)` — passing `None` for the link type. The library's `extract_udp_payload` function requires `link_type == Some(1)` (DLT_EN10MB/Ethernet) or it returns `None` for every packet.

**Fix:** Get the link type from the capture and pass it:

```rust
let link_type = cap.get_datalink().0;
info!("Using device: {} (link type: {})", device.name, link_type);
// ... later ...
if let Some(udp_packet) = extract_udp_payload(packet.data, Some(link_type)) {
    // process packet
}
```

**Why this matters:** On wlan0, tcpdump reports `link-type EN10MB (Ethernet)`, so the link type IS 1. But passing `None` causes the library to reject all packets. The sniffer silently drops everything without logging.

**Verify:** Check the app's log for "Using device: wlan0 (link type: 1)" — if you see this, the link type is correct and packets should be processed.

## Step 3: Check the host filter isn't too restrictive

The sniffer uses `HostFilter::from_cidrs(&["5.188.125.0/24"])` to only keep packets from/to Albion servers.

**Verify:** The game's actual connections should all be in this CIDR:

```bash
sudo ss -uapn | grep "Albion-Online"
```

Expected output:
```
ESTAB  192.168.1.57:59180  5.188.125.56:4535  Albion-Online
ESTAB  192.168.1.57:35135  5.188.125.14:5055  Albion-Online
ESTAB  192.168.1.57:60726  5.188.125.30:5056  Albion-Online
```

All three server IPs (5.188.125.14, 5.188.125.30, 5.188.125.56) are in 5.188.125.0/24, so the host filter should pass them.

**Note:** The host filter keeps a packet if EITHER source OR destination is in the CIDR. So server→client packets (source=5.188.125.x, dest=192.168.1.57) pass because source is in CIDR. Client→server packets (source=192.168.1.57, dest=5.188.125.x) also pass because dest is in CIDR.

## Step 4: Verify the PhotonParser is decoding packets

The sniffer uses `albion_network_lib::PhotonParser` to decode packets. The parser only handles `00 00`-framed Photon envelopes (bytes 0-1 must be `0x0000`).

**Check:** Run the wire_probe to see what's on the wire:

```bash
cd ~/Projects/active/AlbionOnline-Translator/src-tauri
./target/release/wire_probe | head -40
```

**Look for:** `f3 04 04` (event message) or `00 00` (Photon envelope header).

**If you only see `f3 04 03` (move/position events):** The zone is quiet — no chat traffic. Type something in-game to generate chat packets.

**If you see `00 00`-framed packets:** The PhotonParser should decode them. Check the parser's output by adding debug logging.

**If you see `f3 04 04` but no decoded chat:** The PhotonParser may not be decoding Protocol16 event messages. Check if the library's `PhotonParserConfig` has `capture_unknown_packets` enabled.

## Step 5: Check the app's debug output

Launch the app with debug logging:

```bash
export RUST_LOG=debug,albion_translator_lib=debug
./target/release/albion-translator 2>&1 | grep -E "sniffer|capture|device|wlan0|filter|packet|decoded|ChatMessage|error|fail"
```

**Look for:**
- "Using device: wlan0 (link type: 1)" — capture started
- "Packet capture started" — sniffer thread spawned
- "Filtering to 1 Albion server ranges" — host filter active
- "Capture timeout" — packets not arriving (normal, means no traffic)
- "Failed to send chat message" — TX channel closed

**If you see NOTHING from the sniffer:** The sniffer thread never started or died silently. Check if `PacketSniffer::start()` is being called from the UI.

## Step 6: Verify the binary has the fix

After rebuilding, verify the binary contains the port filter:

```bash
strings target/release/albion-translator | grep "5055\|5056\|5058\|4535"
```

Expected: `udp port 5055 or udp port 5056 or udp port 5058 or udp port 4535`

**Also verify:** The binary modification time is AFTER the source modification time:

```bash
stat -c '%y %n' src-tauri/src/sniffer.rs target/release/albion-translator
```

The binary should be newer than the source.

## Step 7: Check the decode chain end-to-end

If packets are being captured but not decoded, trace the chain:

1. **Sniffer captures packet** → `cap.next_packet()` returns Ok
2. **extract_udp_payload extracts UDP payload** → returns Some(UdpPacket)
3. **Host filter passes packet** → source or dest in 5.188.125.0/24
4. **PhotonParser receives packet** → `parser.receive_packet(payload, ...)`
5. **PhotonParser decodes packet** → `parser.decoded_packets()` returns new entries
6. **Sniffer checks for chat events** → `DecodedPacket::Event(event)` with `ExtractedPacket::ChatMessage`
7. **Sniffer sends to UI** → `tx.send(ui_msg).await`

**Add debug logging at each step** to find where packets are being dropped.

## Common failure modes

| Symptom | Likely cause | Fix |
|---------|-------------|-----|
| App shows IDLE, no packets | Port filter missing 5055/5058 | Add all three ports to filter |
| App shows IDLE, no "Using device" log | Sniffer thread never started or died | Check UI → start capture flow; add `info!` at thread entry |
| Packets captured but no decode | `extract_udp_payload` returns None | Pass link type, not None; check `cap.get_datalink().0` |
| Packets decoded but no chat events | PhotonParser not decoding event messages | Check library cfg, add debug logging at `handle_message_payload` |
| Chat events decoded but not shown | TX channel closed or UI not receiving | Check mpsc::channel, UI state, `tx.send().await` errors |

## Wire capture reference

The wire_probe binary captures raw UDP packets for debugging:

```bash
cd ~/Projects/active/AlbionOnline-Translator/src-tauri
sudo setcap 'cap_net_raw,cap_net_admin=eip' target/release/wire_probe
./target/release/wire_probe | head -40
```

The probe shows:
- Packet number, length, source/dest IP:port
- Hex dump of first 96 bytes of payload
- `f3 04 03` = Move/position event (noise)
- `f3 04 04` = Event message (chat, if present)
- `00 00` = Photon envelope header

## Companion app comparison

When the translator isn't working but the companion app is, compare:

1. **Ports:** Companion uses [5055, 5056, 5058]. Translator must match.
2. **Link type:** Companion's `LinuxSocketPacketProvider` uses raw sockets (no pcap). Translator uses pcap. Both should see the same traffic.
3. **Host filter:** Companion doesn't use a host filter — it captures all UDP on the ports. Translator uses a host filter. If the filter is too restrictive, the translator misses packets.
4. **Decode chain:** Companion uses `albion_network_lib::PhotonParser` (same as translator). If companion decodes chat but translator doesn't, the issue is in the translator's sniffer setup, not the decoder.

## Files

- `src-tauri/src/sniffer.rs` — PacketSniffer implementation
- `src-tauri/src/bin/wire_probe.rs` — Raw packet capture probe
- `src-tauri/src/photon.rs` — Protocol18 decoder (own code, not used by sniffer)
- `src-tauri/src/bin/packet_test.rs` — Test harness for photon parser
