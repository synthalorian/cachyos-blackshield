---
name: svelte-5-reactivity
description: Svelte 5 onchange handlers silently fail — desktop apps.
version: 1.0.0
author: Hermes Agent
license: MIT
metadata:
  hermes:
    tags: [svelte, svelte-5, $state, onchange]
    related_skills: [tauri-desktop-development]
---

# Svelte 5 Reactivity in Desktop App Frontends

## Overview

Svelte 5's `$state` rune replaces `let` + reactive declarations with explicit reactive state. For desktop apps (Tauri, Electron) where the frontend wraps a Rust/C# backend, the pattern is: `$state` for UI state, `invoke()` for backend commands, `listen()` for event streams.

This skill captures the two reactivity bugs that surface when wiring new features into an existing Svelte 5 desktop app: `$state` fighting its own setter and passing undefined as an event handler.

## When to Use

- Adding a new UI feature to an existing Svelte 5 + Tauri/Electron app
- Wiring a new `#[tauri::command]` to a frontend `invoke()` call
- Debugging a UI element that snaps back after user interaction
- Debugging a settings panel where slider/checkbox changes don't persist

## Don't Use For

- Svelte 4 projects (different reactivity model)
- Pure web projects without a backend bridge
- Debugging build failures (use tauri-desktop-development)

## The Two Bug Patterns

### Bug 1: `$state` variable fights its own setter in `onchange`

**Symptom:** User picks a new value from a `<select>`, but it immediately snaps back. Or typing in an input works but the state never updates.

**Root cause:** The `onchange` handler reads from a *different source* than the one the user is editing, and overwrites the state variable. Common when there are two copies of the same state — one in `$state` and one in a settings object.

**Broken pattern:**
```svelte
<select bind:value={userLang}
  onchange={() => { userLang = settings.userLang; saveSettings(settings); }}>
```
The `bind:value` already updates `userLang` on every change. The `onchange` then re-reads `settings.userLang` (stale) and overwrites the user's choice.

**Fix — push state TO settings, not pull FROM settings:**
```svelte
<select bind:value={userLang}
  onchange={() => { settings.userLang = userLang; saveSettings(settings); }}>
```
One direction of data flow: `bind:value` updates the variable → `onchange` persists it. Never read settings back into the bound variable in the same handler.

**Rule:** When `bind:value` is on an element, the `onchange` should only *write out* to persistence. It should never *write back* into the bound variable from a secondary source.

### Bug 2: `onchange={saveSettings(settings)}` passes undefined as the handler

**Symptom:** Slider or checkbox in a settings panel moves visually but the change is never saved. No console errors. Settings are silently lost on reload.

**Root cause:** `saveSettings(settings)` is a function *call* — it executes immediately during render and returns `undefined`. Writing `onchange={saveSettings(settings)}` is equivalent to `onchange={undefined}`. The browser silently accepts `undefined` as a no-op handler.

**Broken pattern (common across many elements):**
```svelte
<input type="range" bind:value={settings.opacity}
  onchange={saveSettings(settings)} />

<input type="checkbox" bind:checked={settings.showTimestamps}
  onchange={saveSettings(settings)} />
```

**Fix — wrap in an arrow:**
```svelte
<input type="range" bind:value={settings.opacity}
  onchange={() => saveSettings(settings)} />

<input type="checkbox" bind:checked={settings.showTimestamps}
  onchange={() => saveSettings(settings)} />
```

**Why it's hard to spot:** The broken form looks correct when scanning. `saveSettings(settings)` is a familiar call. The difference between passing the *result* of calling it (undefined) vs passing a function that calls it later is one set of parentheses.

**Rule:** Every `onchange`, `oninput`, `onkeydown`, `onsubmit` attribute value must be either:
- A function reference: `onchange={handler}` (no parens)
- An arrow function: `onchange={() => sideEffect()}` (parens wrap a function, not a call)
- Never: `onchange={sideEffect()}` (calls it now, passes undefined)

## Verification Checklist

- [ ] Every `onchange`/`oninput`/`onkeydown` attribute is a function ref or arrow — never a direct call with `()`
- [ ] `bind:value` elements do not re-read from a settings object in their `onchange` — they only write out
- [ ] After changing a dropdown, the value stays at the user's choice (no snap-back)
- [ ] After moving a slider or toggling a checkbox in settings, the change persists across reload
- [ ] Settings defaults loaded once at mount via `$state(loadSettings())` — not re-read on every interaction

## Svelte 5 Specific Notes

- `$state` creates a deeply reactive proxy. Reading `$state.x` in a template subscribes to changes. Writing `$state.x = v` triggers updates.
- `bind:value` on a `<select>` or `<input>` is two-way: the element updates the variable on user input, and the variable updates the element if changed programmatically. This is why Bug 1 happens — the binding already handles the UI update.
- `$state` variables are not the same as plain `let` variables. Plain `let` variables do not trigger template updates. Use `$state` for anything the template reads.
- Event handlers in Svelte 5 templates attach via `onclick`, `onchange`, etc. — same syntax as Svelte 4, but the handler must be a function, not the result of calling one.

## Session: Albion Translator — Translator Box (2026-08-12)

### What was built

New user-facing translator box in `src/routes/+page.svelte`:
- Text input + 19-language dropdown + Translate button (disabled while loading/empty, Enter-to-translate)
- Result displayed inline below the box
- Rust backend command `translate_user_text` already registered in `lib.rs` — takes `text` + optional `source_lang`, calls `TranslationEngine::translate()`, returns translated string or error
- `TranslationEngine::translate()` pipeline: lingua detection → CTranslate2 local → Google API → `[lang_tag] fallback`
- Settings default `userTranslateTarget: 'en'` added to `src/lib/settings.js`

### Bugs found during review (not yet fixed — documenting for next session)

**Bug A (line 335): user language dropdown fights itself**

The `onchange` reads from `settings.userTranslateTarget` and overwrites `userTranslateTarget` — but `settings.userTranslateTarget` is only loaded from localStorage at mount, so picking a new language immediately snaps back.

```svelte
<!-- BROKEN — pulls FROM settings, overwriting the user's choice -->
<select bind:value={userTranslateTarget}
  onchange={() => { userTranslateTarget = settings.userTranslateTarget; saveSettings(settings); }}>
```

Fix: push state TO settings instead:
```svelte
<select bind:value={userTranslateTarget}
  onchange={() => { settings.userTranslateTarget = userTranslateTarget; saveSettings(settings); }}>
```

**Bug B (lines 216, 226, 234, 241, 248, 255, 262, 272): settings panel changes don't persist**

Every `onchange={saveSettings(settings)}` in the settings panel passes the *result* of calling `saveSettings` (which is `undefined`) as the handler, not a function. None of the sliders/checkboxes actually save.

Fix: wrap each in an arrow — `onchange={() => saveSettings(settings)}`. That's 8 occurrences.

**Bug C (line 335, same fix as Bug A): user lang select uses wrong direction**

Same pattern as Bug A — the onchange reads from settings and overwrites the bound variable. Fix is the same push-direction change.

## Cross-Reference

- **tauri-desktop-development** — covers the Rust command side (`#[tauri::command]`, `invoke()` wiring, build pipeline). Use this skill for the Rust side, svelte-5-reactivity for the frontend wiring.
