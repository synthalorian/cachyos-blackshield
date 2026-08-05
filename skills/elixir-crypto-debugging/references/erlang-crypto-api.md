# Erlang :crypto AEAD API

## Encryption (`crypto_one_time_aead/6`)

```erl
{Ciphertext, Tag} = :crypto.crypto_one_time_aead(:aes_256_gcm, Key, IV, PlainText, AAD, true)
```

**Returns:** A 2-tuple `{Ciphertext, Tag}` — **ciphertext FIRST, tag SECOND**.
- `Ciphertext` — the encrypted data (same length as plaintext for GCM)
- `Tag` — 16-byte authentication tag

**NOT** a single binary. Do NOT pattern match with `<<ciphertext::binary>>`.

**Verify the order:** `byte_size(ciphertext)` should equal plaintext length, `byte_size(tag)` should be 16.

### Example
```elixir
key = :crypto.strong_rand_bytes(32)
nonce = :crypto.strong_rand_bytes(12)
plaintext = "hello"

{ciphertext, tag} = :crypto.crypto_one_time_aead(:aes_256_gcm, key, nonce, plaintext, <<>>, true)
# ciphertext: <<210, 206, ...>> (5 bytes — same as plaintext)
# tag: <<158, 29, 129, ...>> (16 bytes)
```

## Decryption (`crypto_one_time_aead/7`)

```erl
Plaintext = :crypto.crypto_one_time_aead(:aes_256_gcm, Key, IV, CipherText, AAD, Tag, false)
```

**Returns:** The plaintext binary directly on success. On auth failure, returns the atom `:error` (not `{:error, reason}`).

**Arguments:**
1. `:aes_256_gcm` — the cipher name (use `:aes_256_gcm` for 256-bit keys, `:aes_gcm` also works)
2. `Key` — 32-byte AES-256 key
3. `IV` (nonce) — 12-byte initialization vector
4. `CipherText` — the ciphertext (tag already separated out)
5. `AAD` — associated authenticated data (empty binary if not used)
6. `Tag` — the 16-byte tag to verify
7. `false` — decrypt flag

### Example
```elixir
{ciphertext, tag} = :crypto.crypto_one_time_aead(:aes_256_gcm, key, nonce, plaintext, <<>>, true)

result = :crypto.crypto_one_time_aead(:aes_256_gcm, key, nonce, ciphertext, <<>>, tag, false)
# result == "hello" on success, :error on tampered data
```

## Tag Storage Pattern

### Encrypt + Store
```elixir
{ciphertext, tag} = :crypto.crypto_one_time_aead(:aes_256_gcm, key, nonce, data, aad, true)
stored = ciphertext <> tag  # tag at end for easy extraction
```

### Decrypt
```elixir
tag_size = 16
{ciphertext, tag} = :erlang.split_binary(stored, byte_size(stored) - tag_size)

result = :crypto.crypto_one_time_aead(:aes_256_gcm, key, nonce, ciphertext, aad, tag, false)
```

## Version Notes

The Elixir `:crypto` wrapper in OTP 27/28 may not export all function arities. Specifically:
- `crypto_one_time_aead/5` — **does not exist**
- `crypto_one_time_aead/6` — encrypt (returns `{Ciphertext, Tag}`)
- `crypto_one_time_aead/7` — decrypt (returns `Plaintext` or `:error`)

To check what's available:
```elixir
:erlang.function_exported(:crypto, :crypto_one_time_aead, 6)  # => true
:erlang.function_exported(:crypto, :crypto_one_time_aead, 5)  # => false
```

## Debugging Tip: Inspect the Erlang Source

When the Elixir wrapper doesn't compile or the return shape is unexpected:

```bash
# Find the Erlang source
find /usr/lib/erlang/lib/crypto* -name "*.erl"

# Look up the actual function clause
grep -n "^crypto_one_time_aead" /usr/lib/erlang/lib/crypto-*/src/crypto.erl
```

The Erlang source (not Elixir docs) is the source of truth for:
- Function arities
- Return types
- Guard clauses
- Error handling
