# Rust UTF-8 Corruption Debugging Reference

## The Pattern: Emoji Shows as Mojibake in SSE Stream

### Symptoms

Emoji characters (🎹🦞) appear corrupted in the output as Latin-1 characters (ð\x9f\x8e¹). 
The specific corruption is the 4-byte UTF-8 encoding of an emoji being interpreted as 
4 individual Latin-1 codepoints and then re-encoded as UTF-8.

| Expected | Corrupted output | Raw bytes in corrupted SSE |
|----------|-----------------|---------------------------|
| `🎹` (U+1F3B9) | `ð\x9f\x8e¹` (4 chars) | `C3 B0 C2 9F C2 8E C2 B9` |

### Root Cause

**`bytes[i] as char`** in Rust — casting individual bytes to `char` instead of 
decoding UTF-8 sequences properly.

```rust
// 🚫 WRONG: treats each byte as an independent codepoint
let bytes = s.as_bytes();
result.push(bytes[i] as char);  // 0xF0 → U+00F0 (ð), not 🎹
```

For byte `0xF0` (first byte of 🎹's UTF-8 encoding `F0 9F 8E B9`):
- `0xF0 as char` = `U+00F0` = LATIN SMALL LETTER ETH = `ð`
- The byte value is treated as a raw Unicode scalar value

For complete emoji `F0 9F 8E B9` → 4 codepoints `U+00F0`, `U+009F`, `U+008E`, `U+00B9`

### Fix: Use UTF-8 Decoded Chars

```rust
// ✅ CORRECT: iterate over properly decoded characters
let chars: Vec<char> = s.chars().collect();  // proper UTF-8 decoding
result.push(chars[i]);  // pushes the full U+1F3B9 codepoint
```

### Discovery Process (from actual debugging session)

1. **Screenshot analysis**: User showed AI response with `ð🗲🗲¡` at the end instead of `🎹🦞`
2. **Hex dump the SSE stream**: Used `curl` piped to Python to inspect raw bytes
3. **Identified the corruption pattern**: Bytes were `C3 B0 C2 9F C2 8E C2 B9` — double-encoded Latin-1
4. **Traced data flow**: Model → llama-swap → Rust SSE handler (`chat_stream_handler`) → strip_think_tags_stream → JSON → Flutter
5. **Read the function**: Found `bytes[i] as char` in `strip_think_tags_stream()` at line 1755
6. **Fixed**: Changed to `s.chars().collect()` and `result.push(chars[i])`
7. **Verified**: `curl` test confirmed proper `U+1F3B9 (🎹)` and `U+1F99E (🦞)` codepoints

### Why `bytes[i] as char` Works for ASCII But Breaks UTF-8

| Byte value | `bytes[i] as char` | Correct interpretation |
|-----------|-------------------|----------------------|
| `0x3C` (`<`) | `'<'` ✅ | `'<'` |
| `0x74` (`t`) | `'t'` ✅ | `'t'` |
| `0xF0` (start of 🎹) | `U+00F0` (`ð`) ❌ | `U+1F3B9` (`🎹`) requires next 3 bytes too |
| `0x9F` (2nd byte of 🎹) | `U+009F` (control char) ❌ | (part of multi-byte sequence) |
| `0x8E` (3rd byte of 🎹) | `U+008E` (control char) ❌ | (part of multi-byte sequence) |
| `0xB9` (4th byte of 🎹) | `U+00B9` (`¹`) ❌ | (part of multi-byte sequence) |

### When to Suspect This Bug

Any Rust function that:
- Processes text by iterating over `s.as_bytes()` or raw byte slices
- Manipulates individual characters (finding tags, splitting, filtering)
- Outputs strings that should contain non-ASCII characters
- Was originally designed for ASCII-only text and later used with UTF-8

### Prevention Checklist

- [ ] Are you using `s.chars()` instead of `s.as_bytes()` when you need actual characters?
- [ ] Are you building strings from individual chars using `result.push(ch)`?
- [ ] Are you using `s.as_bytes()` only for byte-level operations (binary protocols, specific byte checks)?
- [ ] When you DO need byte-level processing (e.g., finding `<think>` tags in SSE), use pattern matching on bytes but reconstruct the output string using char-level iteration
