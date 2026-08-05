# Open Ascension — Skill Expansion Session (2025-01-11)

## Talent Tree Visual Layout

**Before:** Simple list grouped by tier with checkboxes.
**After:** Grid-based layout with 3 columns per tier, CustomPainter for connecting lines, rank-based selection.

Key implementation details:
- Uses talent's `row`/`column` fields for positioning
- `_TalentGrid` widget uses `LayoutBuilder` + `Stack` + `Positioned`
- `_TalentLinesPainter` draws cubic bezier curves between prereq and child nodes
- Rank tracking: `Map<String, int> _ranks` (talent ID → current rank)
- Prereq enforcement: `_canSelect(t, talents)` checks if prereq is at max rank
- Lock overlay on locked talents
- Detail sheet on long-press with full description
- Reset button clears all ranks

Color coding: `specColor.from` tier 1-3, green/blue/purple/orange rarity colors preserved.

## Ability Data Expansion

Added 95 abilities (171 → 266) across all 9 classes:

| Class | Before | Added | After |
|-------|--------|-------|-------|
| Warrior | 20 | +14 | 34 |
| Paladin | 20 | +10 | 30 |
| Hunter | 16 | +11 | 27 |
| Rogue | 15 | +12 | 27 |
| Priest | 19 | +9 | 28 |
| Death Knight | 20 | +10 | 30 |
| Shaman | 20 | +8 | 28 |
| Mage | 21 | +12 | 33 |
| Warlock | 20 | +9 | 29 |

**Schema reminder:** Ability uses `DamageSchool` enum (not `AbilitySchool`), has `minLevel`, `manaCost`, `cooldown`, `isPassive` fields.

## Gear Integration into Class Builder

- Added Gear tab (5th tab in the builder)
- `_equippedGear: Map<GearSlot, GearItem?>` tracks which gear is equipped per slot
- `computeSecondaryStats` receives gear bonuses: `gearArmor`, `gearBonusAP`, `gearBonusSpellPower`, `gearBonusCrit`, `gearBonusHaste`, `gearBonusResilience`
- Stats tab shows equipped gear count and gear source summary
- Gear list filterable by search and rarity
- One item per slot (radio-style equip)

## Model Change: EnchantTier Renamed

- `EnchantTier.common` → `EnchantTier.uncommon` (to match wiki's Green tier)
- `EnchantSlot` enum REMOVED (Ascension uses collection-based system, not physical slots)
- The MysticEnchantScreen now uses `_selectedEnchantIds: Set<String>` with `_tabs` organized by tier
- All screens referencing `EnchantSlot` needed to be updated in the same commit
