# Unicode styling for Discord server theming

Discord exposes no server-wide font. The only lever is Unicode codepoint
substitution in guild/category/channel names. Choose by legibility tier:

## Legibility tiers (synth's preference order)

1. **Small caps** (phonetic extensions) — most legible "styled" option. Use for
   channels. Survives Discord's forced ASCII-lowercase because these are
   distinct codepoints, not uppercase letters.
2. **Mathematical bold serif** — strong, readable, slightly medieval. Use for
   categories and the guild name.
3. **Mathematical bold italic / sans bold** — acceptable accents.
4. **Fraktur (𝕭/𝔅) — REJECTED by synth** ("cool but annoying to read").
   Never use for names people must read.

## Character maps (verified working 2026-08-21)

Small caps: aᴀ bʙ cᴄ dᴅ eᴇ fꜰ gɢ hʜ iɪ jᴊ kᴋ lʟ mᴍ nɴ oᴏ pᴘ qǫ rʀ sꜱ tᴛ uᴜ vᴠ wᴡ xx yʏ zᴢ
(note: x has no small-caps form, use ASCII x)

Math bold serif: A-Z = U+1D400..1D419, a-z = U+1D41A..1D433
**Off-by-one trap:** bases are 1D400 (A) and 1D41A (a). Using 1D401/1D41B
shifts every letter +1 ("Contracts" → "Dpousbdut") and it WILL go live before
anyone notices. Always print the transformed string and eyeball it, then PATCH
one channel and read back the response name before batching.

## Python transforms (corrected)

```python
SM = dict(zip('abcdefghijklmnopqrstuvwxyz', 'ᴀʙᴄᴅᴇꜰɢʜɪᴊᴋʟᴍɴᴏᴘǫʀꜱᴛᴜᴠᴡxʏᴢ'))
def small_caps(s):
    return ''.join(SM.get(c, SM.get(c.lower(), c) if c.isalpha() else c) for c in s)

def bold_serif(s):
    out = []
    for c in s:
        if 'a' <= c <= 'z': out.append(chr(0x1D41A + ord(c) - ord('a')))
        elif 'A' <= c <= 'Z': out.append(chr(0x1D400 + ord(c) - ord('A')))
        else: out.append(c)
    return ''.join(out)
```

## Workflow notes

- Keep emojis, hyphens, spaces untouched; transform letters only.
- Categories and guild names allow mixed case → bold serif works there.
  Text channels get lowercased by Discord → use small caps (or bold, which
  also survives but looks heavy in lists).
- Rate limit: 2 name changes per channel per 10 minutes. Wrong batch + fix
  batch = both slots gone. Test first.
- ~0.4s between PATCHes; on 429 sleep `retry_after` from the JSON body.
- Usability tradeoff: styled names can't be typed for mentions — users must
  use autocomplete. Offer an ASCII revert if synth complains.
