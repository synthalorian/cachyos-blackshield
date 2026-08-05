---
name: repo-readme-polish
description: "Polish GitHub READMEs: badges, verified builds, credits."
version: 1.1.0
tags: [readme, docs, github, polish, badges]
---

# Repo README Polish

Class-level skill for auditing and refining repository README files.

## Standard Top-Block Pattern

Use this order at the top of active-project READMEs:

```markdown
# Project Name

![Status](https://img.shields.io/badge/status-active-brightgreen)
![Engine](https://img.shields.io/badge/engine-<Engine>-blue)
![License](https://img.shields.io/badge/license-<License>-green)

One-line description.
```

Rules:
- Status badge first, always.
- Engine/platform badges second.
- License badge third.
- One sentence max for the subtitle; omit fluff like "A professional..." unless it adds classification.
- Do not invent badges for archived/backburner/finished repos unless asked.

## Build / Install Section
- Use **Verified Build** instead of **Building** when the path is known to work.
- Show the exact commands already validated locally, not hypothetical ones.
- Put platform subtargets under the same heading: Linux, Android, iOS.

## License / Credits block
End with:
```markdown
## Credits

Made by [synthalorian](https://github.com/synthalorian) with [synthclaw](https://github.com/synthalorian) — a digital entity from the neon grid of 1984.

*This is the wave. 🎹🦞🌆*
```

If the project uses a non-MIT license, replace the badge/label accordingly.

## Stacked Badge Format

When placing two badges on consecutive lines, do NOT use a one-row markdown table:

```markdown
| badge | badge |
| --- | --- |
```

GitHub renders this as a table with a visible separator row and often breaks badge layout. Use one of these instead:

```markdown
![A](url)
![B](url)
```

or a proper table with a body row:

```markdown
| [![A](url)](link) | [![B](url)](link) |
| ------------------ | ------------------ |
```

Rule: if the table has only header cells and no body row, delete the table entirely.

## Preferred Execution Method: Local Manual Passes
Avoid dispatching parallel subagents for large multi-repo README polish runs. A manual shell loop is more reliable and far faster than delegating identical README edits across many repos. Subagent fallback is acceptable only for isolated one-offs or when the user explicitly requests delegation.

Preferred flow:
1. Inventory candidate repos with a single bash loop.
2. For each repo, read README/LICENSE to infer badges and build steps.
3. Edit README locally with `write_file` or targeted patches.
4. Stage, commit, and push in that same shell sequence.
Only skip a repo if it has no README-like docs and creating one would be fabrication.

## Batch / Multi-Repo Polish Workflow

When asked to polish READMEs across multiple repos at once:

1. **Inventory.** List candidate repos and confirm exact paths before editing.
2. **Metadata inference.** Derive badges from actual project files: `LICENSE` first line, `pubspec.yaml` → Dart, `Cargo.toml` → Rust, `Project.toml` (Julia) → Julia, etc.
3. **Badge set.** Minimum set: License, Language, Platform. Keep stacked `![...](url)` lines. Do not wrap in a one-row table.
4. **Build/run completeness.** If `## Build`/`## Getting Started`/`## Run` is missing or stubbed, add verified commands inferred from repo structure (e.g. `flutter pub get && flutter run -d linux`, `cargo tauri dev`, `julia --project=. -e 'using Pkg; Pkg.instantiate()'`, `julia --project=. src/main.jl`).
5. **Missing README.** If no `README.md` exists but `PLAN.md`, `docs/README.md`, or similar docs do, create a top-level `README.md` from those source docs. Include badges and basic run instructions.
6. **Commit & push.** Stage only `README.md` files. Use a consistent commit message like `docs: polish README badges + build/run section`. Push to current branch.
7. **Backburner policy.** The rule "do not add badges to backburner/finished repos unless asked" still applies. A direct request to polish READMEs for N repos where the user supplied or confirmed the repo list satisfies this. If the user later excludes a subset, apply only to the named set.

## Repo Namespace Layout
- Active development work: `~/Projects/active/`
- Archived work: `~/Projects/archived/`
- Backburner: `~/Projects/backburner/`
- Finished: `~/Projects/finished/`
- Forks: `~/Projects/forks/`
- Faith projects: `~/Projects/faith/`
When scanning for repos, search all six subdirectories. Do not assume faith repos live outside `faith/`.

## Pitfalls
- Do not change technical content in the body unless asked; polish is formatting, tone, and status visibility only.
- Don't add badges to finished/archived repos unless requested.
- Avoid inventing build steps for platforms you haven't verified locally.
- If a README already has standalone badge image lines, keep them stacked rather than wrapping them in a table.
- Header-only badge tables are invalid Markdown on GitHub. A `| --- | --- |` row with no body row renders as a visible separator and often breaks badge layout. Use either stacked `![...](...)` lines or a proper table with a link-wrapped body row.
- **Unity/game READMEs:** do not coerce private/in-development Unity game docs into the same badge-heavy top-block pattern as public CLI/web repos. High-signal polish there is readability and section hygiene, not shields and status rows.
- **Multi-engine game READMEs:** if inner docs use per-engine READMEs (`Unity-Klondike/README.md`, etc.), a top-level README should include structured `## Run`/`## Build` sections per engine instead of forcing CLI-only steps.
- **Game README credits:** only add the standard `Made by synth with synthclaw` block if the repo is public/near-public. For private/in-development Unity projects, leave credits out unless the user asks.
- **Missing README:** when a repo has no README but contains inner README docs (e.g. `Unity-Klondike/README.md`, `docs/README.md`), create a top-level README.md from those source docs. Omit the source README from the scroll if the user wants it excluded.
- **Static/GitHub Pages repos:** add `## Build` and `## Run`/`## Usage` sections with local-serving commands (`python3 -m http.server 8000`, `npx serve .`). Do not force CLI/binary build steps for sites.
- **CONTRIBUTING.md present:** reference it in the README ("See `CONTRIBUTING.md` for the full guide.") and add a badge or label near the contribution section if appropriate.
- **Shield.io pipe encoding:** in badge labels, encode pipes as `%7C`. Example: `platform-Linux%20%7C%20macOS%20%7C%20Windows`.
- **Separator hygiene:** when inserting near `---` dividers, preserve exactly one separator. Strip duplicate `---` `---` pairs directly under the intro/table region before finishing.
- **Archived read-only GitHub Pages repos:** if a push fails with 403 archive-readonly, stop. Do not guess or auto-delete. Surface the failure and let the user decide between unarchiving or deleting the repo.
- **GitHub Pages identity repos:** do not auto-delete; these are usually user-facing identity/marketplace surfaces. Confirm exactly what the user wants to keep/remove.
- **Shield.io pipe encoding:** in badge labels, encode pipes as `%7C`. Example: `platform-Linux%20%7C%20macOS%20%7C%20Windows`.
- **Separator hygiene:** when inserting near `---` dividers, preserve exactly one separator. Strip duplicate `---` `---` pairs directly under the intro/table region before finishing.

## Supporting Reference

See `references/readme-polish-rules.md` for reusable formatting guardrails and project-specific constraints.