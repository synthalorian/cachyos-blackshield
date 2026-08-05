---
name: elixir-crypto-debugging
description: >
  Debugging and working with Elixir/Erlang :crypto module, especially AEAD
  ciphers and NIF APIs. Covers AEAD API shapes, NIF debugging patterns, and
  common pitfalls when Elixir wrappers don't match Erlang source.
  Triggers: crypto, ae, aes_gcm, crypto_one_time_aead, NIF, elixir crypto,
  authenticated encryption, GCM, encryption, decryption, hex crypto.
version: 1.0.0
tags: [elixir, erlang, crypto, nif, ae, aes, gcm, encryption, hex]
---

# Elixir Crypto Debugging

Debugging and working with Elixir/Erlang `:crypto` module, especially AEAD ciphers and NIF APIs.

## Triggers
- Working with `:crypto.crypto_one_time_aead` or other AEAD ciphers
- AEAD cipher encryption/decryption issues
- NIF arity errors from Erlang crypto module
- Verifying crypto function signatures against OTP version
- Implementing authenticated encryption

## Core Pitfalls

### AEAD API shapes are NOT uniform

`crypto.crypto_one_time_aead` has different return shapes depending on the operation:

**Encrypt** (`crypto_one_time_aead/6` with `true` as 6th arg):
```
{Ciphertext, Tag}  ← 2-tuple, NOT a single binary
```

**Decrypt** (`crypto_one_time_aead/7` with `false` as 7th arg):
```
Plaintext  ← binary directly, NOT {:ok, plaintext}
```

The 6-arg encrypt takes `(cipher, key, iv, plaintext, aad, true)`.
The 7-arg decrypt takes `(cipher, key, iv, ciphertext, aad, tag, false)` — the tag is the 6th argument, not the 4th.

**Critical:** The encrypt return is `{Ciphertext, Tag}` — ciphertext FIRST, tag SECOND. Many docs get this reversed. Always verify with `byte_size/1`: ciphertext matches plaintext length, tag is 16 bytes for GCM.

### Elixir wrapper ≠ Erlang NIF

The Elixir `:crypto` module is a thin wrapper around Erlang NIFs. Common mismatches:
- The wrapper may not export all function arities (e.g., `crypto_one_time_aead/5` doesn't exist)
- Different OTP versions expose different arities
- **Always check the Erlang source** if the Elixir function doesn't compile

### NIF Debugging Checklist

When `:crypto` functions fail with arity or function clause errors:

1. **Find the Erlang source**:
   ```bash
   find /usr/lib/erlang/lib/crypto* -name "*.erl"
   ```

2. **Look up the actual function clause**:
   ```bash
   grep -n "^crypto_one_time_aead" /usr/lib/erlang/lib/crypto-*/src/crypto.erl
   ```
   This reveals the real signatures and guards.

3. **Verify arity availability** at the REPL:
   ```elixir
   :erlang.function_exported(:crypto, :crypto_one_time_aead, 6)
   ```

4. **Match the return shape** — the NIF's return type is the source of truth, not the Elixir docs.

### AEAD Tag Extraction

When encrypting with AEAD, the tag is returned separately from the ciphertext (as a 2-tuple `{Ciphertext, Tag}` — **ciphertext first**). To store/transmit both, concatenate them:
```elixir
{ciphertext, tag} = :crypto.crypto_one_time_aead(:aes_256_gcm, key, nonce, plaintext, aad, true)
stored = ciphertext <> tag  # tag is appended for transport
```

To decrypt, split the tag back out:
```elixir
tag_size = 16
{ciphertext, tag} = :erlang.split_binary(stored, byte_size(stored) - tag_size)
plaintext = :crypto.crypto_one_time_aead(:aes_256_gcm, key, nonce, ciphertext, aad, tag, false)
```

**On auth failure, decrypt returns the atom `:error`** (not `{:error, reason}`). Wrap accordingly:
```elixir
case :crypto.crypto_one_time_aead(:aes_256_gcm, key, nonce, ciphertext, aad, tag, false) do
  plaintext when is_binary(plaintext) -> {:ok, plaintext}
  :error -> {:error, :decrypt_failed}
end
```

## X25519 Key Exchange

For X25519 (Curve25519) shared secret derivation, use `:crypto.compute_key/4`:
```elixir
secret = :crypto.compute_key(:ecdh, x25519_public_key, x25519_private_key, :x25519)
```

**Do NOT** implement a custom Montgomery ladder. The OTP `:crypto` NIF handles clamping, constant-time operations, and edge cases correctly.

## HMAC Argument Order

`:crypto.mac(:hmac, :sha256, key, message)` — **key first, message second**.

Common mistake in HKDF extract: swapping salt and IKM:
```elixir
# WRONG — salt and ikm are swapped
:crypto.mac(:hmac, :sha256, ikm, salt)

# CORRECT
:crypto.mac(:hmac, :sha256, salt, ikm)
```

## ETS Table Management in GenServers

When a GenServer owns an ETS table and the table must be accessible from multiple processes (tests, other GenServers), **avoid named tables**. Named tables cause `:already_started` / `:badarg` collisions when multiple instances start in async tests.

**Pattern: Unnamed ETS table ref stored in GenServer state**

```elixir
def init(opts) do
  table = :ets.new(:path_table, [:set, :protected])
  {:ok, %{table: table, paths: %{}}}
end
```

**Client API goes through GenServer calls** — never expose the table ref directly:

```elixir
# WRONG — test collision when two instances exist
def get_path(destination_hash) do
  case :ets.lookup(:path_table, destination_hash) do
    [{_, path}] -> {:ok, path}
    [] -> :error
  end
end

# CORRECT — each GenServer has its own table ref
def get_path(destination_hash) do
  GenServer.call(__MODULE__, {:get_path, destination_hash})
end

def handle_call({:get_path, hash}, _from, state) do
  result = case :ets.lookup(state.table, hash) do
    [{_, path}] -> {:ok, path}
    [] -> :error
  end
  {:reply, result, state}
end
```

**ETS Match Spec Syntax**

The `:ets.select/2` match spec uses `:"$1"`, `:"$2"` etc. for variables. The map pattern `%{expires_at: :"$1", :_ => :_}` is **invalid** — ETS match specs don't support wildcard map keys.

```elixir
# WRONG — :_ => :_ is invalid in ETS match spec
:ets.select(state.table, [
  {{:_, %{expires_at: :"$1", :_ => :_}}, [], [:"$1"]}
])

# CORRECT — match only the fields you need
:ets.select(state.table, [
  {{:_, %{expires_at: :"$1"}}, [], [:"$1"]}
])
```

## PubSub Topic Conventions

When building decoupled transport layers in Elixir, establish topic conventions early:

```elixir
# Interface layer publishes raw packets
Phoenix.PubSub.broadcast(pubsub, "reticulum:packets", {:packet, raw_packet, meta})

# Path discovery broadcasts
Phoenix.PubSub.broadcast(pubsub, "reticulum:path_requests", {:path_request, destination_hash, via_interface})

# Transport forwarding layer
Phoenix.PubSub.broadcast(pubsub, "reticulum:forward", {:forward, packet, next_hop})
```

**Benefits:** Interfaces, path managers, link handlers, and transport coordinators can all subscribe independently without direct coupling.

## GenServer State Machine Pattern

For protocol state machines (links, connections, handshakes), use atom states with explicit transitions:

```elixir
defmodule Link do
  use GenServer

  @states [:pending, :handshake, :active, :stale, :closed]

  defstruct [
    :id, :state, :ephemeral_pub, :shared_secret,
    :tx_key, :rx_key, :tx_seq, :rx_seq,
    :created_at, :last_activity
  ]

  # State transitions are explicit and logged
  defp transition(%{state: :pending} = state, :handshake_complete) do
    %{state | state: :active, last_activity: System.monotonic_time(:second)}
  end
  defp transition(%{state: :active} = state, :keepalive_missed) do
    %{state | state: :stale}
  end
  defp transition(state, event) do
    Logger.warning("Invalid transition: #{state.state} -> #{event}")
    state
  end
end
```

**Timeout handling:** Use `Process.send_after/3` for watchdog timers, store the timer ref, and cancel on state change:

```elixir
defp schedule_keepalive(interval) do
  Process.send_after(self(), :keepalive, interval)
end

defp cancel_timer(nil), do: :ok
defp cancel_timer(ref), do: Process.cancel_timer(ref)
```

## Related
- See `references/erlang-crypto-api.md` for detailed AEAD API shapes and examples
- See `references/elixir-otp-pitfalls.md` for ExUnit, Dialyzer, and Credo patterns
- See `elixir-otp-network-protocols` skill for GenServer state machines, ETS routing tables, DynamicSupervisor patterns, and transport layer architecture
