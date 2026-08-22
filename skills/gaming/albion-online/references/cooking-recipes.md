# Albion cooking recipe ratios

Verified against `ao-data/ao-bin-dumps` `items.xml` + `localization.xml`, Aug 2026.

## Goat tier mapping

- `T4_MEAT` = Raw Goat
- `T4_MILK` = Goat's Milk
- `T4_BUTTER` = Goat's Butter
- Goat is T4, not T6. `T6_MEAT` is Raw Mutton and `T6_MILK` is Sheep's Milk.

## Base T4 meal recipes

Each craft outputs **10 meals** (`amountcrafted="10"`).

### Goat Stew (`T4_MEAL_STEW`)

Per batch of 10:

- 4 `T4_TURNIP`
- 4 `T4_BREAD`
- 8 `T4_MEAT`

### Goat Sandwich (`T4_MEAL_SANDWICH`)

Per batch of 10:

- 4 `T4_BREAD`
- 8 `T4_MEAT`
- 2 `T4_BUTTER`

### Intermediate crafts

- Goat's Butter: 1 `T4_MILK` -> 1 `T4_BUTTER`, crafted at the **Mill**, not the Cook (`buildings.xml` `T1_MILL` includes `T4_BUTTER`)
- Bread: 1 `T3_FLOUR` -> 1 `T4_BREAD`

## Fast split/max-output pattern

When synth gives raw material totals and asks for a cooking split, calculate in **batches**, not individual meals:

1. Sandwich batches are capped by `floor(milk / 2)` after milk -> butter.
2. Each sandwich batch consumes 8 meat, so remaining meat is `meat - 8*sandwich_batches`.
3. Stew batches are `min(floor(remaining_meat / 8), floor(turnips / 4))`.
4. Bread needed is `4 * (sandwich_batches + stew_batches)`.
5. Outputs are batches × 10 meals; leftovers are input totals minus consumed batch inputs.

For the Aug 2026 goat example (1,782 raw goat, 298 goat milk, 1,323 turnips): milk caps sandwiches at 149 batches, remaining meat allows 73 stew batches, and bread required is `(149 + 73) * 4 = 888`.
