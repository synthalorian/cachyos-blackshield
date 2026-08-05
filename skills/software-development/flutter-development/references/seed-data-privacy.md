# Seed Data Privacy Checklist

## Rules (NEVER violate these)

1. **No real location data** — No city names, school names, districts, or any geographic identifiers in seed/demo content.
2. **No real personal names** — Even common first/last combos are unnecessary and potentially identifiable.
3. **No real email addresses** — Don't use patterns that imply a real domain or location (e.g., `lakeland.high@...`).
4. **No real phone numbers** — Area codes tied to real locations are geographic identifiers.
5. **No sensitive medical/Special Ed data tied to real locations** — IEP data, accommodations, medical notes.
6. **App starts COMPLETELY BLANK** — First-run experience is empty. Teachers fill their own data.

## When a Privacy Breach is Discovered

1. **Delete the offending release immediately** — `gh release delete <tag> --yes`
2. **Remove ALL seed data from the codebase** — Replace SeedData class with a no-op, remove the seeding call from main.dart
3. **Remove the export from open_agenda_core.dart** if seed data was the only consumer
4. **Replace any "Reset Sample Data" UI** with "Clear All Data" that wipes everything to blank without re-seeding
5. **Create a new release** with the clean code — `gh release create vX.Y.Z --title "..." --notes "..." ./path/to/apk`
6. **Verify no stale imports remain** — `search_files("SeedData")` should return only the no-op class definition
7. **Apologize directly** — this is a real privacy failure, not a minor oversight

## Why This Matters

Seed data that contains real location info (even in a scratch file or comment) is a privacy breach. If the app goes public, that data is visible in the git history forever. Even if the repo is private, accidental screenshots, demos, or CI artifacts can expose it. Zero seed data = zero risk.
