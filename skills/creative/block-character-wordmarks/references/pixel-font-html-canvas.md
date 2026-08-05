# Pixel Font HTML Canvas — Reference Notes

Session: OpenShark title screen pixel font fix (2026-05-31).

## Problem

HTML Canvas pixel font rendered tagline "FAST. PRECISE. HUNGRY." as "AS . PRE SE. H N R ." — missing letters rendered as blank spaces. Additionally, the letter N was ambiguous and looked like a K.

## Root Cause

The pixel font only defined characters needed for "OPENSHARK" (O, P, E, N, S, H, A, R, K) plus `.` and ` `. When the tagline used F, T, I, C, U, G, Y, those characters fell back to the space glyph silently.

## Fix

Added complete 5×7 pixel definitions for the missing letters:

```javascript
const font = {
    // ... existing O, P, E, N, S, H, A, R, K ...
    'F': [
        '11111',
        '10000',
        '10000',
        '11110',
        '10000',
        '10000',
        '10000'
    ],
    'T': [
        '11111',
        '00100',
        '00100',
        '00100',
        '00100',
        '00100',
        '00100'
    ],
    'I': [
        '01110',
        '00100',
        '00100',
        '00100',
        '00100',
        '00100',
        '01110'
    ],
    'C': [
        '01111',
        '10000',
        '10000',
        '10000',
        '10000',
        '10000',
        '01111'
    ],
    'U': [
        '10001',
        '10001',
        '10001',
        '10001',
        '10001',
        '10001',
        '01110'
    ],
    'G': [
        '01111',
        '10000',
        '10000',
        '10011',
        '10001',
        '10001',
        '01111'
    ],
    'Y': [
        '10001',
        '10001',
        '01010',
        '00100',
        '00100',
        '00100',
        '00100'
    ],
};
```

Also fixed N to have a thicker diagonal for distinctness:
```javascript
'N': [
    '10001',
    '11001',
    '11101',
    '10111',
    '10011',
    '10001',
    '10001'
],
```

## Key Lessons

1. **Always define the full alphabet** — partial pixel fonts fail silently when encountering undefined characters. The fallback to space is invisible in code review.

2. **Diagonal letters need extra weight at small grids** — At 5×7 with 6× scale, a 1-pixel diagonal step on N can look like a K or H. Thicken the diagonal (2 pixels wide in middle rows) to make it unambiguous.

3. **Verify by rendering the full text** — Don't just check that the code compiles. Render the actual string and read it visually.

4. **5×7 grid constraints** — Some letters are inherently hard at 5-wide:
   - N, M, W need careful diagonal placement
   - K's two diagonal arms compete for space
   - S needs clear top/bottom/middle distinction
   Consider 6×7 or 7×7 if letters look ambiguous.

## Verification Checklist for Pixel Fonts

- [ ] All characters in the target text have defined glyphs
- [ ] No two letters have identical silhouettes
- [ ] Diagonal letters (N, K, M, W) are visually distinct
- [ ] Render at target scale and read the text aloud
- [ ] Check spacing between letters is uniform
