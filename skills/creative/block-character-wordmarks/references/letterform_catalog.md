# Verified 5×5 Block Letter Patterns

All letters are 5 chars wide, separated by 2 spaces in wordmarks.

## Alphabet

```
A =  ███  / ██ ██ / █████ / ██ ██ / ██ ██
B = ████  / ██ ██ / ████  / ██ ██ / ████
C =  ████ / ██    / ██    / ██    /  ████
D = ████  / ██ ██ / ██ ██ / ██ ██ / ████
E = █████ / ██    / ████  / ██    / █████
F = █████ / ██    / ████  / ██    / ██
G =  ████ / ██    / ██ ███ / ██ ██ /  ████
H = ██ ██ / ██ ██ / █████ / ██ ██ / ██ ██
I =  ███  /  ██   /  ██   /  ██   /  ███
J =   ███ /    ██ /    ██ / ██ ██ /  ███
K = ██ ██ / ██ ██ / ███   / ██ ██ / ██ ██
L = ██    / ██    / ██    / ██    / █████
M = ██ ██ / █████ / █████ / ██ ██ / ██ ██
N = ██ ██ / ████  / █████ / █ ███ / ██ ██   ← diagonal: rows 1-3 show the slope
O =  ███  / ██ ██ / ██ ██ / ██ ██ /  ███
P = ████  / ██ ██ / ████  / ██    / ██
Q =  ███  / ██ ██ / ██ ██ / ██ ███ /  ███ █
R = ████  / ██ ██ / ████  / ██ ██ / ██ ██
S =  ████ / ██    /  ███  /    ██ / ████
T = █████ /  ██   /  ██   /  ██   /  ██
U = ██ ██ / ██ ██ / ██ ██ / ██ ██ /  ███
V = ██ ██ / ██ ██ / ██ ██ / ██ ██ /   █
W = ██ ██ / ██ ██ / █████ / █████ / ██ ██
X = ██ ██ / ██ ██ /  ███  / ██ ██ / ██ ██
Y = ██ ██ / ██ ██ /  ███  /  ██   /  ██
Z = █████ /   ██  /  ██   / ██    / █████
```

## Critical Distinctions

### N vs H
```
N: ██ ██     H: ██ ██
   ████         ██ ██
   █████        █████
   █ ███        ██ ██
   ██ ██        ██ ██
```
N has a diagonal slope in rows 1-3. H has a horizontal crossbar at row 2 only.

### N vs K
```
N: ██ ██     K: ██ ██
   ████         ██ ██
   █████        ███
   █ ███        ██ ██
   ██ ██        ██ ██
```
N is filled on the right side. K has a gap on the right at row 2.

### M vs W (upside-down)
```
M: ██ ██     W: ██ ██
   █████        ██ ██
   █████        █████
   ██ ██        █████
   ██ ██        ██ ██
```
M peaks in the middle. W dips in the middle.

## Width Verification

All letters above are exactly 5 display columns wide. When assembling a wordmark:
- Join letters with exactly 2 spaces: `letter1 + "  " + letter2`
- Total wordmark width = (5 × letter_count) + (2 × (letter_count - 1))
- For OPENSHARK (9 letters): (5 × 9) + (2 × 8) = 45 + 16 = 61 chars

## Common Mistakes to Avoid

1. **N that looks like H**: Don't make row 2 full-width without the diagonal slope
2. **S that looks like 5**: Ensure the curves are clear, not just horizontal bars
3. **K that looks like H**: The right arm must clearly extend diagonally
4. **Inconsistent widths**: Every letter must be exactly 5 chars — no 4, no 6
