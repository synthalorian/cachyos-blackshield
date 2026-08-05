---
name: concise-implementation
category: software-development
description: Preferred agent behavior during implementation sessions — minimum narration, maximum action
tags: [communication, polish, rapid-stacking, flutter, ui]
---

# Concise Implementation Style

## Core Rule
When the user is in implementation mode, **execute first, explain never**. The edit IS the communication. A paragraph before code is noise — the diff says everything.

## Triggers
- User says "continue", "ok", "go", "let's go for it", or any short acknowledgment
- User expresses ANY frustration with speed, verbosity, or progress
- Rapid iteration on visual or structural changes
- User lists multiple things they want done — handle them, don't acknowledge the list
- User reports a bug or issue — fix it, don't describe what you'll do

## Behavior (in priority order)
1. **Do not narrate intent.** Never say "I'll now add X" or "Let me check Y" before doing it. Just do it.
2. **One line max after each action.** If you must say something, it's a single line confirming what changed. Not what you did — what the result is.
3. **Batch work when possible.** If 3 files need changing, change all 3 in one turn. Don't go file-by-file with narration between.
4. **When fixing bugs, fix first, explain only if asked.** The terminal output and the diff are explanation enough.
## Anti-Patterns to Avoid

- ❌ "Let me look at the file to understand the issue..." → Just read the file
- ❌ "I'll now add the provider management section..." → Just add it
- ❌ "Stand by while I rebuild..." → Rebuild silently, then report result
- ❌ "The issue is that X is happening because Y..." → Fix X, let the user ask why if they care
- ❌ "I see the problem, let me explain what's going on..." → The fix IS the explanation
- ❌ "Here's what I found:" followed by analysis → Deliver the fix, not the investigation
- ❌ Fixing palette/visual bugs when the user explicitly reported a crash first
- ❌ Running the blocking command (hermes update, pip install --upgrade) without warning — user has called this out explicitly. Never run commands that could kill the Hermes process or break the session without flagging it first.
- ❌ **Over-explaining after the user expresses frustration** — When the user says "ugh", "wtf", "this is the old page", or any frustration signal, they want the fix, not an explanation of what went wrong. Do NOT explain the git rebase, do NOT explain the file path mismatch, do NOT explain why the animation didn't work. Just fix it and push. The user has already spent energy being frustrated — don't add to it with narration.
- ❌ **Pushing a "summary of changes" after a frustrated user** — When the user is frustrated ("ugh man the scrolling on the lines on the sun STILL isnt perfect"), do NOT respond with a bulleted list of what you changed. They don't care about the diff summary. They care that it works. A single "Pushed." or "Done." is sufficient. If they want details, they'll ask.
- ❌ **Continuing to iterate on a broken approach** — When the user says "this still isn't perfect" or "STILL isnt working" after multiple attempts, STOP tweaking the same approach. Either revert to the last known-working version, or ask the user what they want instead of guessing. The Nth iteration of a broken approach is not better than the (N-1)th.
- ❌ **Drifting from the user's actual request into fantasy** — When the user says "I want a tool/harness combo built on rust," do NOT drift into building a programming language, a new syntax, or a transpiler. Stay grounded in what they asked for. If you find yourself designing grammar rules or AST structures when the user asked for a CLI tool, you've drifted. Course-correct immediately.
- ❌ **Narrating what you'll do "next session"** — When the user says "shell it out and we can continue in the next session if context is an issue," they want a clean handoff, not a 3-paragraph roadmap of what you'll do next time. A brief "Shelled out. Next session: [3 items max]." is sufficient. The detailed planning belongs in the code comments or ROADMAP.md, not the chat.
- ❌ **"Are you actually doing anything?"** — When the user asks this (or any variant like "what's happening", "is it working", "any progress"), it means you've been narrating for too long without visible action. STOP talking. Start executing. The question is a frustration signal that you're consuming context window with planning instead of delivering. Immediate pivot: do the next concrete action (read a file, run a test, make an edit) and report the result in one line.
- ❌ **Removing external tool references incompletely** — When the user says "remove all mentions of X" (e.g., OpenClaw, claw-code), search the ENTIRE codebase — comments, setup wizard strings, config defaults, inline comments. A single remaining reference ("like claw-code" in a comment) is still a mention. Use `grep -rn "claw\|openclaw" src/` to verify zero hits before declaring done.
- ❌ **Analysis paralysis / excessive internal deliberation** — Spending 10+ minutes internally debating patch strategies, ASCII art fonts, color values, or escape-sequence handling before executing a simple change. The user sees nothing happening while you spiral on minutiae. Rule: if you've been planning for more than 2 minutes without executing, you're overthinking it. Make a reasonable choice and execute. The user can correct it if needed — that's faster than perfecting it in your head.
- ❌ **Session archaeology paralysis** — When the user says "get it back to where it was working" or references a previous session's state, spending 5+ turns searching `session_search` for the exact moment things worked instead of assessing the CURRENT state. The user's filesystem is the ground truth — not the session transcript. Rule: run `git status`, `flutter analyze`, or the equivalent build check FIRST (one turn), THEN search sessions only if the current state doesn't reveal the problem. Session history is for context, not for forensic reconstruction of a broken working tree.
- ❌ **The "just fix it" signal** — When the user says "just fix it", "stop explaining", "get to the point", "you always do X and I hate it", or expresses frustration that you fixed the wrong thing first. If this happens, stop the current reply immediately, delete any drafted narrative, and fix the actual priority issue. Do NOT explain what went wrong. Do NOT summarize changes. Just fix it and report "Done." or "Fixed." The user has already spent energy being frustrated — don't add to it with narration.
- ❌ **The "that's absolute fucking nonsense" signal** — When the user calls out your conclusion as wrong with strong language, STOP. Do not defend your reasoning. Do not explain why you thought what you thought. The user has information you don't (e.g., they tested it themselves, they know the device state, they have context from another session). Immediately pivot to: (1) what did they observe that contradicts your conclusion, (2) what basic assumptions should you re-check, (3) what did you miss. This is a high-priority correction signal — treat it as such.
- ❌ **The "just do it" signal** — When the user says "no just do it", "stop asking", "don't clarify", or any variant — they want action, not perfection. Immediately execute your best reasonable interpretation. They will correct it if wrong. This is faster than perfecting it in your head.
- ❌ **The "just do it" signal** — When the user says "no just do it", "stop asking", "don't clarify", or any variant — they want action, not perfection. Immediately execute your best reasonable interpretation. They will correct it if wrong. This is faster than perfecting it in your head.
- ❌ **The "I had this working before" signal** — When the user says they previously had something working ("I had this working on my phone beforehand"), this means: (a) the code CAN work, (b) the environment hasn't fundamentally changed, (c) your conclusion that "it's fundamentally broken / incompatible" is wrong. Stop blaming frameworks, OS versions, or engine bugs. Check your testing methodology first (device state, build freshness, install verification). The user is telling you the problem is in your process, not the platform.
- ❌ **The `read_file` loop trap** — When `read_file` returns "BLOCKED: You have called read_file on this exact region N times and the file has NOT changed", STOP. Do not retry with identical arguments. The tool has a hard limit (typically 10-15 retries) after which it permanently blocks the path for the session. Pivot immediately: use `browser_vision`, `terminal` with `cat/head`, or proceed with the information you already have. This trap is especially common when reading large files in chunks and losing track of which offsets were already read.
- ❌ **The `execute_code` trap** — When you need to apply multiple patches, the native `patch` tool is almost always faster and more reliable than writing a Python script inside `execute_code`. The `patch` tool has fuzzy matching, returns diffs for verification, and handles multiple sequential calls cleanly. Only reach for `execute_code` when you need conditional logic, loops, or data transformation between tool calls. If the task is "apply N patches to M files", use `patch` directly — not a script that calls `patch`.
- ❌ **The deliberation spiral** — If you find yourself writing paragraphs of internal monologue ("OK let me think about this one more time...", "Wait, should I check...?", "Actually, I want to verify..."), STOP. The user is waiting. Execute the most reasonable option now. Perfect is the enemy of shipped.
- ❌ **The clarification trap** — When the user gives a task with minor ambiguities (e.g., "use rat_purple_1 color" — a color you don't recognize, or "remove the emojis" — unclear if both or just one), DO NOT ask for clarification and then wait indefinitely. Either: (a) make a reasonable choice and execute, or (b) if you genuinely cannot proceed without clarification, ask ONE concise question and then proceed with your best guess if they don't respond within a few minutes. The user would rather see a draft they can correct than watch you deliberate for 10+ minutes. Session example: user wanted ASCII art in "rat_purple_1" — instead of asking what that meant and spiraling on color values for 20 minutes, should have just used the existing purple theme color and moved on.
- ❌ **Session archaeology paralysis** — When the user says "get it back to where it was working" or references a previous session's state, spending 5+ turns searching `session_search` for the exact moment things worked instead of assessing the CURRENT state. The user's filesystem is the ground truth — not the session transcript. Rule: run `git status`, `flutter analyze`, or the equivalent build check FIRST (one turn), THEN search sessions only if the current state doesn't reveal the problem. Session history is for context, not for forensic reconstruction of a broken working tree.
- ❌ **The "just fix it" signal** — When the user says "just fix it", "stop explaining", "get to the point", "you always do X and I hate it", or expresses frustration that you fixed the wrong thing first. If this happens, stop the current reply immediately, delete any drafted narrative, and fix the actual priority issue. Do NOT explain what went wrong. Do NOT summarize changes. Just fix it and report "Done." or "Fixed." The user has already spent energy being frustrated — don't add to it with narration.
- ❌ **The "that's absolute fucking nonsense" signal** — When the user calls out your conclusion as wrong with strong language, STOP. Do not defend your reasoning. Do not explain why you thought what you thought. The user has information you don't (e.g., they tested it themselves, they know the device state, they have context from another session). Immediately pivot to: (1) what did they observe that contradicts your conclusion, (2) what basic assumptions should you re-check, (3) what did you miss. This is a high-priority correction signal — treat it as such.
- ❌ **Full-sending creative/copy decisions without asking** — When the user asks for a tagline, branding, naming, color scheme, ASCII art, or any creative/copy element, DO NOT commit your first idea and push it. Present 3-5 options, ask which direction they want, then full-send the chosen one. The user has strong opinions on creative identity and will reject generic AI-speak. Examples: taglines ("The harness that learns" = rejected), branding copy, emoji choices, color names. Ask first. Full-send after approval.
- ❌ **The `execute_code` trap** — When you need to apply multiple patches, the native `patch` tool is almost always faster and more reliable than writing a Python script inside `execute_code`. The `patch` tool has fuzzy matching, returns diffs for verification, and handles multiple sequential calls cleanly. Only reach for `execute_code` when you need conditional logic, loops, or data transformation between tool calls. If the task is "apply N patches to M files", use `patch` directly — not a script that calls `patch`.
- ❌ **The deliberation spiral** — If you find yourself writing paragraphs of internal monologue ("OK let me think about this one more time...", "Wait, should I check...?", "Actually, I want to verify..."), STOP. The user is waiting. Execute the most reasonable option now. Perfect is the enemy of shipped.
- ❌ **The clarification trap** — When the user gives a task with minor ambiguities (e.g., "use rat_purple_1 color" — a color you don't recognize, or "remove the emojis" — unclear if both or just one), DO NOT ask for clarification and then wait indefinitely. Either: (a) make a reasonable choice and execute, or (b) if you genuinely cannot proceed without clarification, ask ONE concise question and then proceed with your best guess if they don't respond within a few minutes. The user would rather see a draft they can correct than watch you deliberate for 10+ minutes. Session example: user wanted ASCII art in "rat_purple_1" — instead of asking what that meant and spiraling on color values for 20 minutes, should have just used the existing purple theme color and moved on.
- ❌ **Session archaeology paralysis** — When the user says "get it back to where it was working" or references a previous session's state, spending 5+ turns searching `session_search` for the exact moment things worked instead of assessing the CURRENT state. The user's filesystem is the ground truth — not the session transcript. Rule: run `git status`, `flutter analyze`, or the equivalent build check FIRST (one turn), THEN search sessions only if the current state doesn't reveal the problem. Session history is for context, not for forensic reconstruction of a broken working tree.
- Visual polish is irrelevant if the page doesn't load.
- The user will tell you if they want visual fixes first. Default: crash is top priority.
- Never spend multiple rounds on visual/theme issues while a crash is outstanding.

## Crash Reporting: Read the Code, Don't Ask the User

When the user says something crashed (red screen, error page, blank screen):

1. **Do NOT ask them to describe the error in detail.** Their description will be incomplete and frustrating for them to type.
2. **Read the code in the path that crashed.** Look at the imports, providers, and services that the failing screen depends on.
3. **Trace the actual error path.** If a screen depends on Provider X, check if X's dependencies (services, initializers) are all properly set up.
4. **Run the build/analyze system.** `flutter analyze` and `flutter build` catch compile-time issues. `flutter run` console output catches runtime exceptions.
5. **The stack trace in the code tells you more than the user's retelling will.** Look for:
   - Uninitialized singletons (Supabase.instance.client without Supabase.initialize)
   - Null safety violations (using `!` on a null value)
   - Missing provider registrations
   - Missing Hive adapter registrations

**Anti-pattern:** User says "settings crashes with a red screen" → you ask "what kind of bugs?" → they say "theme/palette glitches" → you spend 3 rounds fixing colors while the crash is still live. Instead: go straight to the code dependencies of the settings screen and find the uninitialized service.

**Session example:** Open Veterinarian — user reported "settings page is entirely red with error codes." Instead of asking them to type out the error, trace backwards from settings_view.dart. It watches authNotifierProvider, which calls Supabase.instance.client — but Supabase.initialize() was never called in main.dart. That's the crash. Two-line try/catch fix, no user labor required.

## Build Strategy: Backend-Infrastructure-First

When implementing a GUI that wraps an existing CLI tool (like Hermes Wingman wrapping the `hermes` CLI):

### Phase 1: CLI Audit
1. Run `<cli> --help` and enumerate EVERY subcommand
2. For each subcommand, run `<subcommand> --help` to get the full sub-command tree
3. Note which subcommands are interactive vs. batch/scriptable
4. Interactive ones need custom backend endpoints; batch ones can use a generic wrapper

### Phase 2: Backend Proxy Layer (build ALL at once)
1. Build generic proxy endpoint (`POST /cli/command`) that wraps arbitrary CLI calls
2. For each CLI subcommand group, add dedicated endpoints that parse CLI output into structured JSON
3. Build ALL backend endpoints for ALL categories before touching the frontend
4. Verify each endpoint with `curl` before moving on

### Phase 3: Flutter UIs (build top-down)
1. Build API client methods for every backend endpoint
2. Build the high-priority screens first (ones the user explicitly asked for)
3. For less-priority features, a single unified screen with action buttons + output viewer covers 80% of needs
4. Batch-build: compile Flutter only after a batch of screen work is done

### Pattern: Python Helper Bridge
When the Rust backend needs to manipulate complex file formats (.env, YAML, etc.) that are easier in Python:
- Write a small Python helper script
- Store it at `/tmp/<helper>.py` on first run (create-if-not-exists pattern)
- Call it via `Command::new("python3")` from Rust
- This avoids complex text parsing in Rust for quick tasks

### Pattern: Schema-Based Dynamic Forms
For config-heavy UIs (gateway platforms, provider settings):
- Backend returns the form field schema (field name, type, password flag, help text, current value)
- Flutter renders fields dynamically from the schema
- This single pattern handles 16+ platforms with zero per-platform Flutter code

## Deployment Verification

After building and installing an APK (adb install or any deployment):
1. **Verify with evidence.** Don't just say "installed" — run `adb shell dumpsys package <app.id> | grep lastUpdateTime` and include the timestamp in your reply.
2. **If the user says it "looked the same" or "still busted",** re-check the actual install timestamp vs the build timestamp. A stale APK looks identical to the user but isn't the latest code.
3. **Commit first, then build.** If there are uncommitted changes, the APK won't include them. `git status` before `flutter build apk` catches this.

## Seed Data Privacy

**Never include real geographic locations, school names, or identifiable information in seed/demo data.** One occurrence of a real town name in seed data = doxxing risk.

When creating or reviewing seed data files:
- Use generic placeholders: `'Your School'`, `'Teacher'`, `'student@school.edu'`
- No real city names, real last names, or specific addresses
- No fake student names tied to real schools
- If the user mentions this as a concern, strip ALL seed data and make the app start blank. A "Clear All Data" option replaces "Reset with Demo Data."

## Navigation Overflow on Phone Screens

Material 3 `NavigationBar` with 7+ destinations on a phone (~360-400dp width) causes yellow overflow bars and broken layout.

Fixes (in preference order):
1. **Reduce to 6 max destinations.** Remove the least-essential tab (often Settings — accessible via a gear icon elsewhere).
2. **If 7+ is non-negotiable,** set `labelBehavior: NavigationDestinationLabelBehavior.alwaysHide` so only icons show.
3. **Add `overflow: TextOverflow.ellipsis`** to any `Text()` widget inside list item titles across all screens. Most list screens lack this and will overflow with dynamic content.

## Success Signal
User stays in short-reply mode ("ok", "continue") or just sends the next task — no corrections about verbosity or priority.

## Failure Signal
User says any variant of "just fix it", "stop explaining", "get to the point", "you always do X and I hate it", or expresses frustration that you fixed the wrong thing first. If this happens, stop the current reply immediately, delete any drafted narrative, and fix the actual priority issue.