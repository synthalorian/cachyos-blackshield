# Adding Reference Data from Web Sources to Flutter Apps

## When to Use This Pattern

When the user wants to pull data from a reference website (wiki, database, documentation portal) into a Flutter app as offline-capable reference content. Especially when the site uses SPA routing and standard scraping tools can't fetch individual pages.

## Workflow

### Phase 1: Scrape — Extract Structured Data from Browser

The browser toolset handles SPAs better than HTTP scraping. Use this sequence:

```
browser_navigate(url) → browser_click(nav links) → browser_console(extract via JS)
```

1. **Navigate** to the site with `browser_navigate(url)`
2. **Explore** sections via `browser_click` and `browser_snapshot(full=true)` to understand the data structure
3. **Extract** using `browser_console(expression='document.querySelector("main").innerText')` for pure text, or targeted JS queries for structured data
4. **Re-navigate** for each major section (the SPA may not handle internal links well)

**Tip for table data**: Use `browser_console` to extract `document.querySelector('main').innerText` and parse the tab-separated text manually. The browser's virtual DOM rendering gives you the completely rendered table, not infinite-scroll chunks.

**Tip for accordion data**: All accordion sections are usually rendered in the DOM even if collapsed. `main.innerText` dumps everything in reading order.

### Phase 2: Model — Create Data Structures

1. Create `lib/data/models/ascension/<entity>.dart` following the project's `@immutable` + `const` constructor + `fromJson`/`toJson` pattern
2. Add a `FutureProvider.autoDispose<List<T>>` in `lib/data/repository/ascension_repository.dart`
3. Use existing models in `lib/data/models/ascension/` as templates — they all follow the same shape

### Phase 3: Data Files — Create JSON Assets

1. Create the JSON file at `assets/data/<entity>.json`
2. Register it in `assets/data/meta.json` with count + path
3. Register the asset path in `pubspec.yaml` under `flutter > assets` if it's in a new directory

### Phase 4: Screen — Build the UI

1. Create screen at `lib/features/<section>/<entity>_screen.dart`
2. Use `ConsumerWidget` (Riverpod) and `asyncCategories.when(loading:, error:, data:)` pattern
3. Match existing UI conventions: `Theme.of(context)`, `theme.colorScheme.primary/secondary/tertiary`, `theme.hintColor`
4. Use `SingleChildScrollView` for scrollable tables, `ExpansionTile` or custom accordion for collapsible data

### Phase 5: Navigate — Wire Into Routing

1. Add route in `lib/core/navigation/app_router.dart` with fade transition
2. Add nav item in `lib/features/home/app_drawer.dart`
3. Add quick-access card in `lib/features/home/home_screen.dart`
4. Adjust existing sections if similar cards need to move (e.g., promote from Reference to Quick Access)

### Phase 6: Brand & Document

1. Update Android manifest label, iOS Info.plist display name
2. Update `pubspec.yaml` description
3. Rewrite README comprehensively — every feature gets a section

### Phase 7: Verify

```
cd /project && flutter analyze
```

Expect 0 errors, 0 warnings. Info-level lint is acceptable.

## Parallel Execution Pattern

For speed, use `delegate_task` with parallel tasks for:

1. **Data file creation** — creating the large JSON asset files
2. **Model + provider creation** — Dart class + Riverpod provider
3. **Screen creation + navigation wiring** — UI + router + drawer + home cards

Each subagent gets the project conventions context. Verify results after all complete.

## Pitfalls

- Don't try to scrape SPA sub-pages via `browser_navigate` — SPAs often return 404 for direct URL access. Navigate to the main page, then click through.
- `browser_console(expression)` is significantly more reliable than `browser_snapshot(full=true)` for getting complete text data. Snapshots truncate at ~1300 lines.
- When the screen wraps a DataTable in two `SingleChildScrollView`s (horizontal + vertical), the columns may not have a fixed first column. Use `SizedBox(width: 90)` on the first DataColumn as a workaround.
- The user's project already has all 8 slot-category columns mapped into `MplusUpgrade` model. If copying this pattern, match the exact JSON field names to the Dart model (snake_case → camelCase).