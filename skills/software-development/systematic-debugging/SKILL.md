---
name: systematic-debugging
description: "4-phase root cause debugging: understand bugs before fixing."
version: 1.1.0
author: Hermes Agent (adapted from obra/superpowers)
license: MIT
platforms: [linux, macos, windows]
metadata:
  hermes:
    tags: [debugging, troubleshooting, problem-solving, root-cause, investigation]
    related_skills: [test-driven-development, writing-plans, subagent-driven-development]
---

# Systematic Debugging

## Overview

Random fixes waste time and create new bugs. Quick patches mask underlying issues.

**Core principle:** ALWAYS find root cause before attempting fixes. Symptom fixes are failure.

**Violating the letter of this process is violating the spirit of debugging.**

## The Iron Law

```
NO FIXES WITHOUT ROOT CAUSE INVESTIGATION FIRST
```

If you haven't completed Phase 1, you cannot propose fixes.

## When to Use

Use for ANY technical issue:
- Test failures
- Bugs in production
- Unexpected behavior
- Performance problems
- Build failures
- Integration issues

**Use this ESPECIALLY when:**
- Under time pressure (emergencies make guessing tempting)
- "Just one quick fix" seems obvious
- You've already tried multiple fixes
- Previous fix didn't work
- You don't fully understand the issue

**Don't skip when:**
- Issue seems simple (simple bugs have root causes too)
- You're in a hurry (rushing guarantees rework)
- Someone wants it fixed NOW (systematic is faster than thrashing)

## The Four Phases

You MUST complete each phase before proceeding to the next.

---

## Phase 1: Root Cause Investigation

**BEFORE attempting ANY fix:**

### 1. Read Error Messages Carefully

- Don't skip past errors or warnings
- They often contain the exact solution
- Read stack traces completely
- Note line numbers, file paths, error codes

**Action:** Use `read_file` on the relevant source files. Use `search_files` to find the error string in the codebase.

### 2. Reproduce Consistently

- Can you trigger it reliably?
- What are the exact steps?
- Does it happen every time?
- If not reproducible → gather more data, don't guess

**Action:** Use the `terminal` tool to run the failing test or trigger the bug:

```bash
# Run specific failing test
pytest tests/test_module.py::test_name -v

# Run with verbose output
pytest tests/test_module.py -v --tb=long
```

### 3. Check Recent Changes

- What changed that could cause this?
- Git diff, recent commits
- New dependencies, config changes

**Action:**

```bash
# Recent commits
git log --oneline -10

# Uncommitted changes
git diff

# Changes in specific file
git log -p --follow src/problematic_file.py | head -100
```

### 4. Gather Evidence in Multi-Component Systems

**WHEN system has multiple components (API → service → database, CI → build → deploy):**

**BEFORE proposing fixes, add diagnostic instrumentation:**

For EACH component boundary:
- Log what data enters the component
- Log what data exits the component
- Verify environment/config propagation
- Check state at each layer

Run once to gather evidence showing WHERE it breaks.
THEN analyze evidence to identify the failing component.
THEN investigate that specific component.

### 5. Rule Out Compiler/Tool Bugs

**WHEN error messages contradict language specification:**

- The syntax you're using is correct per the language spec
- The compiler rejects it with a nonsensical error
- You've verified the syntax in a minimal isolated test case

This may be a compiler/tool regression, not a code error.

**Actions:**
1. Create a minimal reproduction (smallest possible file that triggers the error)
2. Check the compiler/tool version
3. Search for known issues: `web_search "<error message> <tool> <version>"`
4. Try the same syntax on a different tool version if available
5. If confirmed compiler bug: document it, create a workaround, move on

**Session example:** Dart 3.11.5 rejected valid enum constructor syntax with "Too many positional arguments: 0 expected, but 2 found" — the enum declaration line itself was counted as a zero-arg constructor, overriding the actual constructor. Confirmed via minimal reproduction test.

### 6. Trace Data Flow

**WHEN error is deep in the call stack:**

- Where does the bad value originate?
- What called this function with the bad value?
- Keep tracing upstream until you find the source
- Fix at the source, not at the symptom

**Action:** Use `search_files` to trace references:

```python
# Find where the function is called
search_files("function_name(", path="src/", file_glob="*.py")

# Find where the variable is set
search_files("variable_name\\s*=", path="src/", file_glob="*.py")
```

### Phase 1 Completion Checklist

- [ ] Error messages fully read and understood
- [ ] Compiler/tool bug ruled out (if error contradicts spec)
- [ ] Issue reproduced consistently
- [ ] Recent changes identified and reviewed
- [ ] Evidence gathered (logs, state, data flow)
- [ ] Problem isolated to specific component/code
- [ ] Root cause hypothesis formed

**STOP:** Do not proceed to Phase 2 until you understand WHY it's happening.

---

## Phase 2: Pattern Analysis

**Find the pattern before fixing:**

### 1. Find Working Examples

- Locate similar working code in the same codebase
- What works that's similar to what's broken?

**Action:** Use `search_files` to find comparable patterns:

```python
search_files("similar_pattern", path="src/", file_glob="*.py")
```

### 2. Compare Against References

- If implementing a pattern, read the reference implementation COMPLETELY
- Don't skim — read every line
- Understand the pattern fully before applying

### 3. Identify Differences

- What's different between working and broken?
- List every difference, however small
- Don't assume "that can't matter"

### 4. Understand Dependencies

- What other components does this need?
- What settings, config, environment?
- What assumptions does it make?

---

## Phase 3: Hypothesis and Testing

**Scientific method:**

### 1. Form a Single Hypothesis

- State clearly: "I think X is the root cause because Y"
- Write it down
- Be specific, not vague

### 2. Test Minimally

- Make the SMALLEST possible change to test the hypothesis
- One variable at a time
- Don't fix multiple things at once

### 3. Verify Before Continuing

- Did it work? → Phase 4
- Didn't work? → Form NEW hypothesis
- DON'T add more fixes on top

### 4. When You Don't Know

- Say "I don't understand X"
- Don't pretend to know
- Ask the user for help
- Research more

---

## Phase 4: Implementation

**Fix the root cause, not the symptom:**

### 1. Create Failing Test Case

- Simplest possible reproduction
- Automated test if possible
- MUST have before fixing
- Use the `test-driven-development` skill

### 2. Implement Single Fix

- Address the root cause identified
- ONE change at a time
- No "while I'm here" improvements
- No bundled refactoring

### 3. Verify Fix

```bash
# Run the specific regression test
pytest tests/test_module.py::test_regression -v

# Run full suite — no regressions
pytest tests/ -q
```

### 4. If Fix Doesn't Work — The Rule of Three

- **STOP.**
- Count: How many fixes have you tried?
- If < 3: Return to Phase 1, re-analyze with new information
- **If ≥ 3: STOP and question the architecture (step 5 below)**
- DON'T attempt Fix #4 without architectural discussion

### 5. If 3+ Fixes Failed: Question Architecture

**Pattern indicating an architectural problem:**
- Each fix reveals new shared state/coupling in a different place
- Fixes require "massive refactoring" to implement
- Each fix creates new symptoms elsewhere

**STOP and question fundamentals:**
- Is this pattern fundamentally sound?
- Are we "sticking with it through sheer inertia"?
- Should we refactor the architecture vs. continue fixing symptoms?

**Discuss with the user before attempting more fixes.**

This is NOT a failed hypothesis — this is a wrong architecture.

---

## Red Flags — STOP and Follow Process

If you catch yourself thinking:
- "Quick fix for now, investigate later"
- "Just try changing X and see if it works"
- "Add multiple changes, run tests"
- "Skip the test, I'll manually verify"
- "It's probably X, let me fix that"
- "I don't fully understand but this might work"
- "Pattern says X but I'll adapt it differently"
- "Here are the main problems: [lists fixes without investigation]"
- Proposing solutions before tracing data flow
- **One more fix attempt (when already tried 2+)**
- **Each fix reveals a new problem in a different place**
- **Error message contradicts language spec (compiler bug?)**

**ALL of these mean: STOP. Return to Phase 1.**

**If 3+ fixes failed:** Question the architecture (Phase 4 step 5).

## Common Rationalizations

| Excuse | Reality |
|--------|---------|
| "Issue is simple, don't need process" | Simple issues have root causes too. Process is fast for simple bugs. |
| "Emergency, no time for process" | Systematic debugging is FASTER than guess-and-check thrashing. |
| "Just try this first, then investigate" | First fix sets the pattern. Do it right from the start. |
| "I'll write test after confirming fix works" | Untested fixes don't stick. Test first proves it. |
| "Multiple fixes at once saves time" | Can't isolate what worked. Causes new bugs. |
| "Reference too long, I'll adapt the pattern" | Partial understanding guarantees bugs. Read it completely. |
| "I see the problem, let me fix it" | Seeing symptoms ≠ understanding root cause. |
| "One more fix attempt" (after 2+ failures) | 3+ failures = architectural problem. Question the pattern, don't fix again. |

## Quick Reference

### Two-Bug Interaction Pattern

When the first fix fails but the error *changes* (not the same error — a *different* error), the original hypothesis was correct but incomplete. There were two bugs, and you fixed the one that crashed first:

```
Fix #1 applied → Error changes from A to B  →  Fix #1 was correct, keep it
Fix #1 applied → Same error A persists       →  Fix #1 was wrong, revert
```

**Do NOT revert Fix #1 just because the app still crashes.** Check *what* crashed. If it's a different error, Fix #1 worked — you're now fighting Bug #2. This is especially common with:

- **Widget/UI initialization** where one component failing blocks downstream inflation
- **Multiple layer violations** (API removal + layout restriction in the same feature)
- **Chained failures** where step 1 throws before step 2 can even be validated

**Session example:** Android 15 widget crash — first fix (replace removed `PendingIntent` API) produced no new `NoSuchMethodError` but widgets still showed "Problem loading widget". The error *changed* from `NoSuchMethodError` to `InflateException` after the first fix held. Second fix (`<View>` → `<TextView>` in RemoteViews layout) resolved it. If we'd reverted the first fix thinking it didn't work, we'd still be stuck.

| Phase | Key Activities | Success Criteria |
|-------|---------------|------------------|
| **1. Root Cause** | Read errors, reproduce, check changes, gather evidence, trace data flow | Understand WHAT and WHY |
| **2. Pattern** | Find working examples, compare, identify differences | Know what's different |
| **3. Hypothesis** | Form theory, test minimally, one variable at a time | Confirmed or new hypothesis |
| **4. Implementation** | Create regression test, fix root cause, verify | Bug resolved, all tests pass |

## Hermes Agent Integration

### Investigation Tools

Use these Hermes tools during Phase 1:

- **`search_files`** — Find error strings, trace function calls, locate patterns
- **`read_file`** — Read source code with line numbers for precise analysis
- **`terminal`** — Run tests, check git history, reproduce bugs
- **`web_search`/`web_extract`** — Research error messages, library docs

### With delegate_task

For complex multi-component debugging, dispatch investigation subagents:

```python
delegate_task(
    goal="Investigate why [specific test/behavior] fails",
    context="""
    Follow systematic-debugging skill:
    1. Read the error message carefully
    2. Reproduce the issue
    3. Trace the data flow to find root cause
    4. Report findings — do NOT fix yet

    Error: [paste full error]
    File: [path to failing code]
    Test command: [exact command]
    """,
    toolsets=['terminal', 'file']
)
```

### Hermes Tool Pitfalls

#### `execute_code` File Roundtrip Trap

When using `from hermes_tools import read_file, write_file` inside `execute_code` to read, process, and write back a file:

- The `read_file` helper returns its `content` field with **line-number prefixes baked in** (e.g. `     1|import ...`)
- Writing that content back with `write_file` **corrupts the file** — every line gets a duplicated line number prefix

**Fix:** Use the **direct tools** (`read_file` and `write_file` at the top level, or `patch` for targeted edits) when the goal is to rewrite a file. Reserve `execute_code` for:
- Processing data between reads (analysis, filtering, batch transforms)
- Conditional logic that depends on tool outputs
- Tasks requiring 3+ tool calls with processing between them

For file editing inside `execute_code`, the safe approach is:
```python
from hermes_tools import read_file
data = read_file('/path/to/file')['content']
# Process data...
# But NEVER write_file() that content back — use patch() instead
# or return the modified content and use the top-level write_file tool
```

When fixing bugs:
1. Write a test that reproduces the bug (RED)
2. Debug systematically to find root cause
3. Fix the root cause (GREEN)
4. The test proves the fix and prevents regression

## Platform-Specific Debug Patterns

### Flutter/Dart: Uncommitted Working Tree Files Causing Analysis Errors

When returning to a Flutter project after previous sessions:

**Symptom:** `flutter analyze` shows dozens of errors in files that "should work" — undefined methods, missing imports, type mismatches.

**Root cause:** Previous sessions created uncommitted files that reference symbols from OTHER uncommitted files. The committed base doesn't have those symbols. The working tree is a Frankenstein of committed + uncommitted code that was never tested together.

**Check FIRST (before any session_search):**
```bash
git status --short          # Shows untracked (??) and modified (M) files
flutter analyze 2>&1 | grep "error" | wc -l   # Count analysis errors
```

**If you see many `??` files + many analysis errors:**
1. The working tree is broken — don't try to fix individual errors
2. Decide: (a) stash/clean and return to committed state, or (b) commit the working tree and fix from there
3. Session history is secondary — the filesystem state is what matters

**Session example:** OpenSynth project had 25 untracked files from May 30-31 sample engine integration (`lib/ffi/sample_engine.dart`, `lib/providers/sample_engine_provider.dart`, retro UI widgets, etc.) but the committed base was from an earlier "Grid Expansion" reversion. `flutter analyze` showed 48 errors — mostly `sampleEngineCreate` etc. undefined in `OpenAmpSynthBindings`. The fix was NOT to patch individual files but to recognize the working tree was inconsistent and present the user with a choice: restore committed state or commit-and-fix.

**Rule: ALWAYS check the console output first.** A gray/blank screen is almost never a theme or color issue — it's almost always a thrown exception during build that Flutter catches silently.

**Steps:**
1. Run `flutter run -d linux` (or appropriate device) and capture the full console output
2. Look for `EXCEPTION CAUGHT BY WIDGETS LIBRARY` or `Unhandled Exception` blocks
3. Read the stack trace to find the failing widget and line number
4. Fix the root cause — do NOT guess at theme/color/layout issues

**Common Flutter crashes that produce gray screens:**
- `Cannot modify an unmodifiable list` — calling `.sort()`, `.add()`, etc. on a `const` list. Fix: `List.from(constList)` before mutating.
- `Null check operator used on a null value` — accessing `!` on null. Fix: null-safe access.
- `RangeError` — accessing empty list by index. Fix: guard with `.isEmpty` check.
- **Provider debugCheckInvalidValueType** — Using `Provider<T>.value()` where `T` is implemented by a `ChangeNotifier` subclass. The debug check throws during `main()`, preventing the entire Provider tree from initializing. Visual result: app uses default Material theme, no custom theming, looks "the same as before." Fix: `Provider.debugCheckInvalidValueType = null` at the top of `main()`.
- **BackdropFilter + Missing Material ancestor** — Any `InkWell`/`Material` widget inside a `BackdropFilter` subtree crashes at runtime because `BackdropFilter` doesn't propagate Material theme. Error: "InkResponseStatWidget widgets require a Material widget ancestor." Fix: wrap BackdropFilter's child with `Material(type: MaterialType.transparency)`.
- **Subprocess PATH** — Starting a Rust/CLI backend via `Process.start()` with minimal env means CLI tools (`hermes`, etc.) aren't on PATH. The health endpoint returns `hermes_installed: false` even though the tool is available in the user's shell. Fix: pass `'PATH': Platform.environment['PATH']` in the process environment.

### Flutter Mobile: Black Screen via ADB (NOT a Crash)

When testing a Flutter app on Android via `adb` and screenshots show completely black:

**DO NOT immediately assume:**
- Flutter engine bug
- Graphics driver issue (gralloc5, Vulkan, Impeller)
- Widget tree problem
- Need to disable Impeller or change surface formats

**ALWAYS check these FIRST (in order):**

1. **Is the device locked?** `adb shell dumpsys window displays | grep isKeyguardShowing`
   - `isKeyguardShowing=true` → the device is locked. Unlock it first.
   - A locked device stops the activity — Flutter never gets `onResume`, viewport metrics never sent.

2. **Is the activity stopped?** `adb shell dumpsys activity <package> | grep mResumed`
   - `mResumed=false mStopped=true` → activity is stopped (device dozing, keyguard active, or another app has focus)
   - Wake device: `adb shell input keyevent KEYCODE_WAKEUP && adb shell input keyevent KEYCODE_MENU`

3. **Is the notification shade open?** `adb shell dumpsys window displays | grep mFocusedWindow`
   - `mFocusedWindow=NotificationShade` → shade is covering the app
   - Dismiss: `adb shell cmd statusbar collapse`

4. **Check Flutter viewport metrics:** `adb logcat -d | grep "FlutterRenderer\|Sending viewport metrics"`
   - `Width is zero. 0,0` with NO `Sending viewport metrics to the engine` → surface created but never sized (activity stopped/locked)
   - If you see `Sending viewport metrics` and THEN black → investigate widget tree

5. **Only after ruling out 1-4:** investigate widget tree, Impeller, or engine issues.

**Session lesson:** Spent 20+ minutes disabling Impeller, changing window backgrounds, checking Vulkan layers, and blaming Android 16 gralloc5 — the actual issue was the device was locked (`isKeyguardShowing=true`) and the activity was stopped. The user had to say "that's absolute fucking nonsense" before I checked basic device state. **Always verify device state before blaming the framework.**

**Another session lesson:** Even a brand new `flutter create` app rendering black does NOT prove an engine bug — it proves the testing environment is wrong. The `gralloc5` error in logcat is a red herring when the device is locked. **Check `mWakefulness` (`adb shell dumpsys power | grep mWakefulness`) — `Dozing` means the screen is off and no app can render.**

### Flutter/Dart: Const List Mutation Trap

Dart const lists are deeply immutable. These patterns crash at runtime:

```dart
// CRASH: sampleGearItems is a const list, .sort() mutates in-place
var items = sampleGearItems;  // same const reference
items.sort(...);              // UnsupportedError

// FIX: create a mutable copy
var items = List.from(sampleGearItems);
items.sort(...);
```

Even `var items = constList;` is just a reference to the const list — not a copy. Always use `List.from()` before any mutation.

### Elixir: `:crypto.crypto_one_time_aead` Return Tuple Order

The Erlang `:crypto.crypto_one_time_aead/6` for AES-GCM returns `{ciphertext, tag}` on encrypt (encrypt=true), but the documentation and intuition often suggest `{tag, ciphertext}`. Getting this wrong means:
- Encrypt appends tag+ciphertext instead of ciphertext+tag
- Decrypt extracts the wrong 16 bytes as the auth tag
- Result: `:error` from the decrypt NIF (not `{:error, reason}` — just bare `:error`)

**Verify before shipping crypto code:**
```elixir
{ciphertext, tag} = :crypto.crypto_one_time_aead(:aes_256_gcm, key, nonce, plaintext, "", true)
assert byte_size(tag) == 16   # tag is ALWAYS 16 bytes for GCM
assert byte_size(ciphertext) == byte_size(plaintext)  # ciphertext same size as plaintext
```

If your `tag` is 5 bytes and `ciphertext` is 16 bytes, you have the tuple order backwards.

### Elixir: Dialyzer `with` Block Success Inference

Dialyzer infers that a `with` block always succeeds unless an explicit `else` clause is present. If your function returns `{:error, reason}` in a `with` clause but Dialyzer reports "pattern can never match the type", add `else error -> error`:

```elixir
# BAD — Dialyzer infers this always returns {:ok, _}
defp generate_identity() do
  with {:ok, a} <- f1(),
       {:ok, b} <- f2() do
    {:ok, %{a: a, b: b}}
  end
end

# GOOD — Dialyzer sees the error path
defp generate_identity() do
  with {:ok, a} <- f1(),
       {:ok, b} <- f2() do
    {:ok, %{a: a, b: b}}
  else
    error -> error
  end
end
```

**Pitfall:** Removing the `else` clause to "simplify" code breaks Dialyzer. The `else` is not dead code — it's a type-system signal.

### Data Collection: Fandom Wiki Through Cloudflare

Fandom wikis with Cloudflare bot protection block `browser_navigate` to rendered pages. **Use the MediaWiki API instead** — it's accessible without passing JS challenges:

```
# Get full page wikitext:
curl "https://PROJECT.fandom.com/api.php?action=parse&page=PAGE_NAME&prop=wikitext&format=json"

# Get page content as revision:
curl "https://PROJECT.fandom.com/api.php?action=query&titles=PAGE_NAME&prop=revisions&rvprop=content&format=json"
```

Parse the wikitext in Python — tables use `{|...|}` format with `|-` row separators and `|cell` content. This bypasses Cloudflare entirely.

## Reference Cases

The skill's `references/` directory contains detailed debugging session write-ups
with reproduction steps, analysis techniques, and fix patterns:

- `references/poisoned-external-files-pattern.md` — External files containing HTTP error responses (404, etc.) causing cryptic parse failures. Detection via `od -c` / `cat -A`, fix by removal.
- `references/visual-bug-report-protocol.md` — When user reports visual issue with screenshot but no specifics: ask first, investigate second. Vision model may miss the issue. Trust user's eyes.
- `references/reticulum-protocol-constants.md` — Reticulum mesh networking protocol
  reference: packet types, header format, destination hash algorithm, context bytes,
  TCP/KISS framing, and Python RNS interop extraction commands.

## Real-World Impact

From debugging sessions:
- Systematic approach: 15-30 minutes to fix
- Random fixes approach: 2-3 hours of thrashing
- First-time fix rate: 95% vs 40%
- New bugs introduced: Near zero vs common

**Session lesson this time:** Spent multiple rounds patching UI colors, empty state text, and theme widgets for "gray screens" — the actual root cause was a Dart `const` list mutation crash that would've been visible in `flutter run` console output in 30 seconds. **Always run the failing code and read the stack trace BEFORE touching UI code.**

**No shortcuts. No guessing. Systematic always wins.**
