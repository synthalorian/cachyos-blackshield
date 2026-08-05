---
name: project-triage
category: software-development
description: Evaluate multiple projects to recommend where to focus development effort — git recency, compile health, test status, feature completeness, and ship-readiness.
---

# Project Triage — Choosing What to Build Next

**Class**: Evaluating multiple projects to decide where the next development session should focus.

When the user asks "what project should we work on?" or similar, this skill provides the pattern for making an informed recommendation.

## Triage Signals (in priority order)

### 1. Freshness — What's been touched recently?
```
git log --oneline -5
```
Projects modified within the last 1-3 days are actively in mind. The user may have unfinished work, a hot mental model, or momentum to preserve.

### 2. Phase — Where is the project in its lifecycle?
| Phase | Implication |
|-------|-------------|
| Pre-alpha / scaffold | Needs foundation work — high impact, high effort |
| Active dev (phases in progress) | Has momentum — good for focused sessions |
| Pre-release (rc, beta) | Close to finish line — quick wins, validation |
| Maintenance / shipped | Lower urgency — iterate if user is invested |

### 3. Compile Health — Does the code actually build?
```
cargo check      # Rust
flutter analyze  # Flutter
dotnet build     # C# / Unity
```
A project that doesn't compile needs diagnosis before it's ready for feature work.

### 4. Test Health
```
cargo test
```
Tests passing == confidence the core works. Broken tests == debt.

### 5. Build & CI Infrastructure
- Do build scripts exist? (`scripts/*.sh`)
- Are they executable? (`chmod +x`)
- Does the CI workflow hit the right paths? (watch for workspace vs. subdirectory mismatches)
- Does CI pin the right SDK versions?

### 6. Critical Gap — What's the single biggest thing blocking ship?
For a v0.1.0 release, the checklist is:
- [ ] Compiles
- [ ] Tests pass
- [ ] UI exists and works
- [ ] Core features are real (not mocked)
- [ ] Bridge/wiring is wired (Rust ↔ Flutter)
- [ ] Build scripts produce artifacts
- [ ] README describes actual features

Identify the ONE missing item that everything else depends on.

## Making the Recommendation

Structure the pitch:
1. **Landscape**: Quick summary of all projects and their current state
2. **Top pick**: One recommendation with specific reasoning (aligns signals above)
3. **Alternative**: One runner-up if the user wants a different vibe
4. **Critical path**: The first 1-3 concrete steps to make progress

## Signals That a Project Is "Hot" (prioritize these)
- User created the project today or yesterday
- Recent commit message mentions phase completion or release prep
- Project aesthetic aligns with the user's current enthusiasm (synthwave, retro-futurist, game dev)
- You've been asked about this project before (check session_search)

## Pitfalls
- **Don't just pick the most recent project** — freshness is one signal, not the only one
- **Don't recommend a project that doesn't compile** unless the user explicitly wants debug time
- **Don't assume all projects need the same polish level** — a game prototype has different ship criteria than an app
- **Don't skip README reading** — the description tells you the project's scope and ambition faster than any other file
- **NEVER use directory modification times (`ls -la`) for freshness** — a project's root directory timestamp may reflect when the folder was created or last moved, not when code was last touched. Always use `git log --oneline -5` (or `git log -1 --format="%ci %s"`) to get actual recency. `ls` timestamps will burn you.
- **Don't write off projects with "Final production tuning pass" in git history as dormant** — that phrase is used across multiple projects as a delivery milestone, not abandonment.
- **Don't trust `ls -la` directory modification times over git log.** A project's root directory timestamp may reflect when it was created or the last git operation, not when source code was last touched. Always check `git log --oneline -5` for actual recency. This burned me specifically on `open-veterinarian` — the directory showed May 6 but the code had May 25 commits.
- **When returning to a project after previous sessions, check the working tree FIRST.** Run `git status --short` and the build/analysis command (`flutter analyze`, `cargo check`, etc.) before searching session history. Uncommitted files from previous sessions may be inconsistent with the committed base — session transcripts won't reveal this. The filesystem is the ground truth.
- **Watch for single-commit projects where most files are untracked.** `git log --oneline -1` showing one commit with `git status --short` showing dozens of untracked `??` files means the project is functionally unversioned. It's not "done" — it's uncommitted. Flag this as a necessary step before release.
- **When scanning many projects, batch git log queries in a for-loop** — one pass with `for dir in ...; do echo "$dir: $(cd ... && git log -1 --format='%ci %s')"; done` is faster and more accurate than inspecting individually.

## References
- `references/ship-readiness-checklist-template.md` — template for quickly assessing a single project's v0.1.0 readiness
- `references/shipping-workflow.md` — the 7-step sequence for taking an untracked/unreleased project from zero to a GitHub release with README, LICENSE, commit, push, and release notes
