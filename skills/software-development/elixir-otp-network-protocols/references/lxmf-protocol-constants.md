# LXMF Protocol Constants

Extracted from Python `LXMF` package for interoperability with Elixir implementations.

## Message Structure

```python
# From LXMF/LXMessage.py
DESTINATION_LENGTH = 16      # bytes — truncated SHA-256 hash
SIGNATURE_LENGTH   = 64      # bytes — Ed25519 signature
TIMESTAMP_SIZE     = 8       # bytes — float64 timestamp
STRUCT_OVERHEAD    = 8       # bytes — msgpack list overhead
```

### Wire Format
```
[Destination Hash: 16 bytes]
[Source Hash: 16 bytes]
[Signature: 64 bytes]
[MsgPack Payload: variable]
  └── [timestamp, title_bytes, content_bytes, fields_map]
```

### Message Hash
```python
hashed_part = destination_hash + source_hash + msgpack(payload)
message_hash = SHA256(hashed_part)
```

## Delivery Methods

| Constant | Value | Description |
|----------|-------|-------------|
| `UNKNOWN` | 0 | Unspecified |
| `OPPORTUNISTIC` | 1 | Single-packet delivery if size permits |
| `DIRECT` | 2 | Link-based delivery (default) |
| `PROPAGATED` | 3 | Store-and-forward via LXMF relay |

## Representations

| Constant | Value | Description |
|----------|-------|-------------|
| `UNKNOWN` | 0 | Unspecified |
| `PACKET` | 1 | Fits in single packet |
| `RESOURCE` | 2 | Requires resource transfer |

## States

| Constant | Value | Description |
|----------|-------|-------------|
| `GENERATING` | 0 | Building message |
| `OUTBOUND` | 1 | Ready to send |
| `SENDING` | 2 | In transit |
| `SENT` | 4 | Delivered to network |
| `DELIVERED` | 8 | Receipt confirmed |
| `FAILED` | 255 | Max attempts exceeded |

## Content Size Limits

```python
ENCRYPTED_PACKET_MAX_CONTENT = 295   # opportunistic, encrypted dest
PLAIN_PACKET_MAX_CONTENT     = 368   # opportunistic, plain dest
LINK_PACKET_MAX_CONTENT      = 319   # direct/propagated link delivery
```

## Unverified Reasons

| Constant | Value | Description |
|----------|-------|-------------|
| `SOURCE_UNKNOWN` | 1 | Can't verify — source identity unknown |
| `SIGNATURE_INVALID` | 2 | Signature verification failed |

## LXMF Fields

```python
FIELD_EMBEDDED_LXMS    = 1
FIELD_TELEMETRY        = 2
FIELD_TELEMETRY_STREAM = 3
FIELD_ICON_APPEARANCE  = 4
FIELD_FILE_ATTACHMENTS = 5
FIELD_IMAGE            = 6
FIELD_AUDIO            = 7
FIELD_THREAD           = 8
FIELD_COMMANDS         = 9
FIELD_RESULTS          = 10
FIELD_GROUP            = 11
FIELD_TICKET           = 12
FIELD_EVENT            = 13
FIELD_RNR_REFS         = 14
FIELD_RENDERER         = 15
FIELD_REPLY_TO         = 48
FIELD_REPLY_QUOTE      = 49
FIELD_REACTION         = 64
FIELD_COMMENT          = 65
FIELD_CONTINUATION     = 66
FIELD_CUSTOM_TYPE      = 251
FIELD_CUSTOM_DATA      = 252
FIELD_CUSTOM_META      = 253
FIELD_NON_SPECIFIC     = 254
FIELD_DEBUG            = 255
```

## Propagation Defaults

```python
# Typical relay settings
DEFAULT_TTL_SECONDS      = 86_400   # 24 hours
DEFAULT_MAX_MESSAGES     = 10_000   # per relay
DEFAULT_MAX_MESSAGE_SIZE = 65_536   # 64 KiB
DEFAULT_BATCH_SIZE       = 10       # messages per propagation round
DEFAULT_BATCH_INTERVAL   = 5_000    # milliseconds
DEFAULT_MAX_HOPS         = 8
DEDUP_WINDOW_SECONDS     = 300      # 5 minutes
```

## Python Research Commands

```bash
cd /path/to/project
python3 -m venv .venv
.venv/bin/pip install rns lxmf

# Extract all LXMessage constants
.venv/bin/python3 -c "
import LXMF
for name in dir(LXMF.LXMessage):
    val = getattr(LXMF.LXMessage, name)
    if not name.startswith('_') and not callable(val):
        print(f'{name} = {val}')
"

# Inspect pack() method
.venv/bin/python3 -c "
import LXMF, inspect
print(inspect.getsource(LXMF.LXMessage.pack))
"

# Inspect unpack_from_bytes() method
.venv/bin/python3 -c "
import LXMF, inspect
print(inspect.getsource(LXMF.LXMessage.unpack_from_bytes))
"
```

## Elixir Serialization Notes

Python uses `msgpack` for payload serialization. In Elixir, use `:erlang.term_to_binary/1` and `:erlang.binary_to_term/1` as a compatible alternative for same-VM deployments. For cross-language interop, consider a msgpack library.

**Pack flow:**
1. Build payload: `[timestamp, title_bytes, content_bytes, fields_map]`
2. Serialize payload to binary
3. Compute `hashed_part = dest_hash <> source_hash <> serialized_payload`
4. Compute `message_hash = SHA256(hashed_part)`
5. Build `packed = dest_hash <> source_hash <> signature <> serialized_payload`

**Unpack flow:**
1. Split packed binary: dest_hash (16) + source_hash (16) + signature (64) + payload
2. Deserialize payload → `[timestamp, title, content, fields]`
3. Recompute hash and compare
