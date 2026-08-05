# Reticulum Protocol Reference — Packet Format & Constants

Extracted from Python RNS v1.3.1 reference implementation. Use this when implementing Reticulum protocol parsers or generators.

## Packet Types

| Name | Value | Description |
|------|-------|-------------|
| DATA | 0x00 | Generic data packet |
| ANNOUNCE | 0x01 | Destination announcement |
| LINKREQUEST | 0x02 | Link establishment request |
| PROOF | 0x03 | Packet receipt proof |

## Header Types

| Name | Value | Description |
|------|-------|-------------|
| HEADER_1 | 0x00 | Normal header (19 bytes) |
| HEADER_2 | 0x01 | Transport forwarding header (35 bytes) |

## Destination Types

| Name | Value | Description |
|------|-------|-------------|
| SINGLE | 0 | Identity-bound, encrypted |
| GROUP | 1 | Pre-shared key, encrypted |
| PLAIN | 2 | Unencrypted, anonymous |
| LINK | 3 | Ephemeral link destination |

## Transport Types

| Name | Value | Description |
|------|-------|-------------|
| BROADCAST | 0 | Broadcast to all peers |
| TRANSPORT | 1 | Transport node forwarding |

**Note:** Transport type uses only 1 bit in the flags byte (bit 4). Values 2-3 would overflow into context_flag.

## Context Bytes

| Name | Value | Description |
|------|-------|-------------|
| NONE | 0x00 | Generic data |
| RESOURCE | 0x01 | Part of a resource transfer |
| RESOURCE_ADV | 0x02 | Resource advertisement |
| RESOURCE_REQ | 0x03 | Resource part request |
| RESOURCE_HMU | 0x04 | Resource hashmap update |
| RESOURCE_PRF | 0x05 | Resource proof |
| RESOURCE_ICL | 0x06 | Resource initiator cancel |
| RESOURCE_RCL | 0x07 | Resource receiver cancel |
| CACHE_REQUEST | 0x08 | Cache request |
| REQUEST | 0x09 | Request packet |
| RESPONSE | 0x0A | Response packet |
| PATH_RESPONSE | 0x0B | Path request response |
| COMMAND | 0x0C | Command packet |
| COMMAND_STATUS | 0x0D | Command status |
| CHANNEL | 0x0E | Link channel data |
| KEEPALIVE | 0xFA | Keepalive |
| LINKIDENTIFY | 0xFB | Link peer identification |
| LINKCLOSE | 0xFC | Link close |
| LINKPROOF | 0xFD | Link packet proof |
| LRRTT | 0xFE | Link request RTT measurement |
| LRPROOF | 0xFF | Link request proof |

## Flags Byte Layout

```
Bit 7-6: header_type     (2 bits: 0-1)
Bit 5:   context_flag    (1 bit: 0-1)
Bit 4:   transport_type  (1 bit: 0-1)
Bit 3-2: destination_type (2 bits: 0-3)
Bit 1-0: packet_type     (2 bits: 0-3)
```

Python reference:
```python
packed_flags = (header_type << 6) | (context_flag << 5) | (transport_type << 4) | (destination_type << 2) | packet_type
```

## Header Sizes

| Type | Size | Structure |
|------|------|-----------|
| HEADER_1 | 19 bytes | flags(1) + hops(1) + dst_hash(16) + context(1) |
| HEADER_2 | 35 bytes | flags(1) + hops(1) + transport_id(16) + dst_hash(16) + context(1) |

## Destination Hash Computation

```python
name_hash = SHA256(expand_name(app_name, *aspects))[0:10]  # 80 bits
addr_hash_material = name_hash
if identity:
    addr_hash_material += identity_hash  # 128-bit truncated hash
dest_hash = SHA256(addr_hash_material)[0:16]  # 128 bits
```

Expanded name format: `app_name.aspect1.aspect2...identity_hexhash`

## Packet Size Limits

| Limit | Value |
|-------|-------|
| MTU | 500 bytes |
| MDU (plain) | 464 bytes |
| MDU (encrypted) | 383 bytes |
| HEADER_MAXSIZE | 35 bytes |
| TRUNCATED_HASHLENGTH | 128 bits (16 bytes) |
| NAME_HASH_LENGTH | 80 bits (10 bytes) |

## Encryption Exemptions

These packet types/contexts do NOT get encrypted:
- `packet_type == ANNOUNCE` (0x01)
- `packet_type == LINKREQUEST` (0x02)
- `context == CACHE_REQUEST` (0x08)
- `context == KEEPALIVE` (0xFA)
- `packet_type == PROOF && context == RESOURCE_PRF` (0x05)
- `packet_type == PROOF && destination_type == LINK` (0x03)
- `context == RESOURCE` (0x01) — resource handles its own encryption

## TCP Framing

Reticulum over TCP uses a 2-byte big-endian length prefix:

```
+--------+--------+------------------+
| Length | Length |     Packet       |
|  MSB   |  LSB   |   (Length bytes) |
+--------+--------+------------------+
```

Max frame: 502 bytes (500 MTU + 2 length).

## KISS Framing (Serial/RNode)

- FEND (0xC0) marks frame boundaries
- FEND in data → escape as 0xDB 0xDC
- 0xDB in data → escape as 0xDB 0xDD

## AutoInterface Discovery

- UDP multicast group: 224.0.0.1
- Port: 2970
- Announce interval: 60 seconds
- Announce format: `RETICULUM:v{version}`

## Python Reference Extraction

```python
import RNS
import inspect

# Packet constants
print(RNS.Packet.DATA, RNS.Packet.ANNOUNCE, RNS.Packet.LINKREQUEST, RNS.Packet.PROOF)
print(RNS.Packet.HEADER_1, RNS.Packet.HEADER_2)
print(RNS.Packet.HEADER_MAXSIZE)
print(RNS.Reticulum.MTU, RNS.Reticulum.MDU)
print(RNS.Reticulum.TRUNCATED_HASHLENGTH)

# Destination constants
print(RNS.Destination.SINGLE, RNS.Destination.GROUP, RNS.Destination.PLAIN, RNS.Destination.LINK)

# Transport constants
print(RNS.Transport.BROADCAST, RNS.Transport.TRANSPORT)

# Packet packing (for interop testing)
dest = RNS.Destination(identity, RNS.Destination.IN, RNS.Destination.SINGLE, 'app', 'aspect')
packet = RNS.Packet(dest, b'payload')
packet.pack()
print(packet.raw.hex())  # Compare with Elixir implementation
```
