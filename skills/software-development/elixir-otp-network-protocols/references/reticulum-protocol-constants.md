# Reticulum Protocol Constants

Extracted from Python RNS reference implementation for interoperability with Elixir implementations.

## Packet Types

| Type | Value | Description |
|------|-------|-------------|
| `ANNOUNCE` | 0x00 | Destination announcement |
| `LINK_REQUEST` | 0x01 | Link establishment request |
| `LINK_PROOF` | 0x02 | Link proof/verification |
| `LINK_CLOSE` | 0x03 | Link teardown |
| `LINK_KEEPALIVE` | 0x04 | Link keepalive |
| `LINK_DATA` | 0x05 | Encrypted data over link |
| `LINK_DATA_ACK` | 0x06 | Data acknowledgment |
| `PATH_REQUEST` | 0x07 | Request path to destination |
| `PATH_RESPONSE` | 0x08 | Path response |
| `PATH_PROOF` | 0x09 | Path proof |
| `PATH_ERROR` | 0x0A | Path error |

## Link Constants

```python
# From RNS/Link.py
PENDING = 0x00
HANDSHAKE = 0x01
ACTIVE = 0x02
STALE = 0x03
CLOSED = 0x04

ECPUBSIZE = 64   # Ed25519 public key size (used for identity/signatures)
KEYSIZE = 32     # Symmetric key size
MDU = 431        # Maximum Data Unit (payload size)

KEEPALIVE = 360   # seconds
STALE_TIME = 720  # seconds
TIMEOUT = 900     # seconds
```

**Important:** `ECPUBSIZE = 64` refers to Ed25519 public keys (used for identity/signatures), NOT X25519 public keys (used for ECDH). X25519 public keys are 32 bytes. The Python code uses Ed25519 for identity and derives X25519 keys for ECDH.

## Cryptographic Parameters

```python
# From RNS/Cryptography/Hashes.py
SHA256 = hashlib.sha256
SHA512 = hashlib.sha512

# From RNS/Cryptography/Keypair.py
CURVE = "Ed25519"  # Signing
ECDH_CURVE = "Curve25519"  # Key exchange

# HKDF parameters
HKDF_HASH = SHA256
HKDF_LENGTH = 32
HKDF_SALT = None  # Often uses link_id or ephemeral pubkey
```

## Packet Structure

### Announce Packet
```
[Header: 1 byte type = 0x00]
[Destination Hash: 16 bytes (truncated SHA-256)]
[Public Key: 32 bytes (Ed25519) or 64 bytes (Ed25519 full)]
[Name Hash: 16 bytes (optional)]
[Signature: 64 bytes (Ed25519)]
[App Data: variable]
```

### Link Request
```
[Header: 1 byte type = 0x01]
[Link ID: 16 bytes]
[Ephemeral Public Key: 32 bytes (X25519)]
[Destination Hash: 16 bytes]
[Signature: 64 bytes (Ed25519)]
```

### Link Proof
```
[Header: 1 byte type = 0x02]
[Link ID: 16 bytes]
[Proof Payload: variable (signed with ephemeral key)]
```

## Transport Parameters

```python
# From RNS/Transport.py
DEFAULT_MTU = 500
MAX_HOPS = 128
ANNOUNCE_TTL = 86400 * 7  # 7 days
PATH_REQUEST_TIMEOUT = 30  # seconds
```

## Python RNS Source Locations

Installed at `~/.local/lib/python3.14/site-packages/RNS/` (or equivalent Python path).

Key files to inspect:
- `RNS/Link.py` — Link state machine, handshake, keepalive
- `RNS/Packet.py` — Packet encoding/decoding
- `RNS/Transport.py` — Transport mode, forwarding, path management
- `RNS/Destination.py` — Destination creation, announce handling
- `RNS/Cryptography/Keypair.py` — Key generation, signing
- `RNS/Cryptography/Hashes.py` — Hash functions
- `RNS/Identity.py` — Identity management

## Interoperability Notes

1. **Ed25519 vs X25519:** Python RNS uses Ed25519 for identity/signatures and derives X25519 keys for ECDH. The Elixir `:crypto` module supports both via `:eddsa` and `:ecdh` with `:x25519`.

2. **HKDF context string:** Python uses `"ReticulumLink"` as the HKDF info/context string for key derivation.

3. **AES-GCM mode:** Python uses `MODE_AES256_GCM` (mode value 2). The Elixir equivalent is `:aes_256_gcm`.

4. **Packet serialization:** Python uses a custom binary format. Match byte-for-byte for interoperability.

5. **Hash truncation:** Destination hashes are SHA-256 truncated to 16 bytes (128 bits).
