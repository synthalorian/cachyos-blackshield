# Open Ascension — Mystic Enchant Data Session Notes (2026-05-12)

## Summary
Session to fix 4 bugs in open_ascension Flutter app:
1. Class Builder gray screen
2. Gear Browser gray screen
3. Talent descriptions not showing
4. Missing Mystic Enchants (especially rare/epic tiers)

## Gray Screen Root Cause
The `Center()` widget with `theme.hintColor` icons/text rendered as invisible blobs against the ultra-dark scaffold backgrounds (Neon Grid: `#080812`, Midnight Pulse: `#080115`, etc.). Empty state widgets using `hintColor` were invisible.

**Fix pattern**: Replace `Center()` with `SingleChildScrollView` + padding, use `theme.colorScheme.primary` for icons (always visible against dark), and `titleMedium` for text with explicit color guidance.

## Files Modified
- `lib/features/class_builder/class_builder_screen.dart`
- `lib/features/talent_tree/talent_tree_screen.dart`
- `lib/features/gear/gear_browser_screen.dart`
- `lib/data/models/mystic_enchant.dart`

## Wiki Scraping Results
- Pulled full wiki content via MediaWiki API
- Wiki only has "examples" for rare (5) and epic (4) tiers
- Legendary tier is comprehensive (119 entries)
- Uncommon tier is comprehensive (13 entries - generic modifiers)

## Final Counts in Code
| Tier | Count | Notes |
|------|-------|-------|
| Uncommon | 47 | +34 generic skill modifiers (damage/heal/shield etc.) |
| Rare | 37 | +21 stat bonuses + class-specific utility |
| Epic | 26 | +13 transformed spells + conditional buffs |
| Legendary | 99 | +2 wiki-missing: Restorative Shadows, Lost Knowledge |
| **Total** | **209** | No duplicate IDs |

## Key Discovery
The MediaWiki API (`/api.php?action=parse&page=...&prop=wikitext`) works perfectly past Cloudflare bot detection. This is the reliable scraping method.
