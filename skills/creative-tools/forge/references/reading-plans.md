# forge word plan — Reading Plans Reference

Location: `src/spirit_cmd.rs` — `word_plan()` function, `PLANS` static array, `plan_connect_db()` helper.

## Architecture

Reading plans are **hardcoded const data** + **runtime SQLite state** in spirit.db.

### Static Plan Definitions

Each plan is a `ReadingPlan` struct:

```rust
struct ReadingPlan {
    name: &'static str,        // plan identifier (psalms-30, gospels-40, etc.)
    description: &'static str, // human-readable summary
    total_days: u32,           // total days in the plan
    readings: &'static [(u32, &'static str, u32, u32)], // (day, book, start_chapter, end_chapter)
}
```

The `readings` array maps each day to one or more Bible chapters. `forge word plan` runs `lookup_reference(cfg, book, Some(chapter), None)` to fetch the first verse of each chapter for display.

### Runtime State (spirit.db)

Table schema in `plan_connect_db`:

```sql
CREATE TABLE IF NOT EXISTS reading_plans (
    name TEXT PRIMARY KEY,
    active INTEGER NOT NULL DEFAULT 0,
    current_day INTEGER NOT NULL DEFAULT 1,
    started_at TEXT NOT NULL DEFAULT (datetime('now'))
);
```

State transitions:
- `--activate <plan>` — sets all plans to inactive, inserts/updates selected plan with day=1
- `--today` (default) — shows the current day's reading, then auto-advances `current_day` by 1
- `--progress` — reads `current_day` and computes percentage for a progress bar
- `--list` — queries active plan to show which plan is active

## Adding a New Plan

1. Add a new `ReadingPlan` entry to the `PLANS` static array in `spirit_cmd.rs`
2. Each entry needs: name (kebab-case), description, total_days, readings array
3. Readings must cover every day 1..total_days with no gaps
4. Book names must match exactly what `crate::spirit::lookup_reference` expects (standard Bible book names: "Psalms", "Proverbs", "Matthew", "John", "Acts", "Romans", "1 Corinthians", "Revelation", etc.)
5. The `gospels-40` and `new-testament-90` plans show how to handle multi-chapter readings; `proverbs-month` shows single-chapter

## Display

`forge word plan --list` shows all plans with active indicator:
```
● psalms-30 — 30 days through the Psalms
    → Day 5 of 30
○ proverbs-month — 31 days of Proverbs
```

`forge word plan` shows today's reading with verse text and auto-advances:
```
psalms-30 — Day 5 of 30
==================================================
Psalms 21: The king shall joy in thy strength, O LORD...
Psalms 22: My God, my God, why hast thou forsaken me?...
...
→ Next: Day 6 tomorrow
```
