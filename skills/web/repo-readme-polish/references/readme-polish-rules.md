# README Polish Rules

## Stacked Badge Format

Badge pairs should render cleanly without creating visual table artifacts. Preferred forms:

```markdown
![A](url)
![B](url)
```

Linked table body row:

```markdown
| [![A](url)](link) | [![B](url)](link) |
| ------------------ | ------------------ |
```

Do not use header-only tables:

```markdown
| badge | badge |
| --- | --- |
```

A header-only table with no data row renders as a visible separator on GitHub.

## Glean/Privacy Rule

Some repos are private/clean-room. Do not add stars/fork/PR claims, contributor badges, or social proof lines unless user has explicitly asked; polishing formatting is allowed.

## Game READMEs

For private/in-development Unity projects, prefer readability/section hygiene over forced CLI/web-style badge blocks. Credits block only near-public/public repos.

## Separator Hygiene

When editing near `---` dividers, preserve exactly one separator under headings/table blocks. Duplicate `---` `---` lines create visual gaps.

## Chompers-Style Changes

If changing drawer/session markup from div-based click targets, prefer semantic buttons or role+tabindex plus matching keyboard handlers. Make behavior explicit rather than suppressing warnings.

## Language Detection by Project File

Quick mapping from project file → badge language label:

| File / dir | Language badge |
|---|---|
| `pubspec.yaml` | Dart |
| `Cargo.toml` | Rust |
| `Project.toml` (Julia) | Julia |
| `package.json` | TypeScript / JavaScript |
| `go.mod` | Go |
| `setup.py` / `pyproject.toml` | Python |
| `CMakeLists.txt` | C++ |

## Platform / Context Inference

| Signal | Platform badge |
|---|---|
| Flutter single-file (`lib/`, `pubspec.yaml`, `linux/` dir) | Linux / Desktop |
| Flutter + `ios/`/`android/`/`macos/`/`windows/` | Cross-platform (pick dominant target or separator-encoded multi) |
| Bevy / Rust + `src/main.rs` + `Cargo.toml` | Linux / macOS / Windows |
| Tauri (`src-tauri/`) | Desktop |
| Julia + PortAudio / GLMakie | Desktop / Native |

## Missing README Reconstruction

When a repo has no `README.md` but contains architect docs (`PLAN.md`, `CHANGELOG.md`, `docs/`):
- Create a minimal `README.md` from those source docs.
- Always include one-line description, badges, and a minimal run block.
- Omit deep architecture detail unless it belongs in a dedicated section.

## Build Command Validation Pattern

When inserting build/run steps, validate against the actual repo structure:
- Check for `src-tauri` → use `cargo tauri dev`
- Check for `pubspec.yaml` → use `flutter pub get`, `flutter run -d linux`
- Check for `Cargo.toml` + binary target → use `cargo build --release <bin>`
- Check for `Project.toml` + `src/main.jl` → use `julia --project=. <file>`
- Check for `Manifest.toml` → use `julia --project=. -e 'using Pkg; Pkg.instantiate()'`

Do not invent steps for platforms you haven't observed in the repo.
