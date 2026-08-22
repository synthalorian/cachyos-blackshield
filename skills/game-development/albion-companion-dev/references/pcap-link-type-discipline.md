# Pcap Link-Type Discipline for Packet Capture Apps

## The Bug

`extract_udp_payload(frame, link_type)` (albion-network-lib and any pcap-frame parser) requires the caller to supply the actual link-layer type of the capture device. Passing `None` (or any value other than the device's real link type) causes the function to return `None` for **every single packet** — no errors, no warnings, zero decoded packets. The sniffer appears to be running but captures nothing.

### Root Cause Signature

```rust
// BUG: link_type comes from the capture device, but caller passes None
if let Some(udp_packet) = extract_udp_payload(packet.data, None) {
    // This block NEVER executes — every packet dropped silently
}
```

The library's `extract_udp_payload` typically checks:
```rust
if link_type != Some(1) || frame.len() < 14 {
    return None;  // silently drops
}
```

Where `1` = `DLT_EN10MB` (Ethernet). If the device uses a different link type (e.g. `DLT_LINUX_SLL` on some wireless interfaces, or raw IP on others), `Some(1)` is also wrong, but `None` is *always* wrong.

## The Fix

Read the link type from the capture handle **after opening it**, then pass it to every call:

```rust
let mut cap = Capture::from_device(device)
    .promisc(true)
    .snaplen(65535)
    .timeout(1000)
    .open()
    .map_err(|e| SnifferError::CaptureOpen(e.to_string()))?;

// Read the ACTUAL link type from the open capture
let link_type = cap.get_datalink().0 as u16;

info!("Using device: {} (link type: {})", device.name, link_type);

// Pass it into every call — NOT None
if let Some(udp_packet) = extract_udp_payload(packet.data, Some(link_type)) {
    // Now packets actually parse
}
```

### Key Points

1. **Call `get_datalink()` AFTER `open()`** — the capture must be open for the link type to be available.
2. **Cast to `u16`** — `get_datalink()` returns a `pcap::DL` (an enum/int wrapper); the parser usually wants `Option<u16>`.
3. **Log the link type** at INFO level on startup so a future debug session can verify the capture device is what you think it is.
4. **Rule of thumb**: any `None` argument to a pcap-frame parser is a bug until proven otherwise. If the parser accepts `Option<u16>`, the caller must supply `Some(actual_link_type)`.

## Diagnosis Pattern

When a packet capture app shows no decoded packets and no errors:

1. Check the sniffer init log — does it print the device name AND link type?
2. Grep the binary for the `extract_udp_payload` call site — is the second argument `None` or `Some(...)`?
3. Run a raw capture (tcpdump or wire_probe) to confirm packets ARE on the wire on the expected ports.
4. If packets are on the wire but the app sees nothing, the link-type mismatch is the prime suspect.

## Verification

After fixing, the app log should show:
```
Using device: wlan0 (link type: 1)
Packet capture started
```

Followed by decoded packet counts increasing. If link type prints as `0` or an unexpected value, the capture device may not be what you think — verify with `tcpdump -i <dev> -c 1` and check its reported link-type header.
