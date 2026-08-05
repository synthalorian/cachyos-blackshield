---
name: svelte-webview-a11y
description: "Fix Svelte a11y warnings in desktop webviews."
tags: ["svelte", "a11y", "tauri", "webview", "accessibility"]
trigger: "svelte a11y warning, noninteractive element tabindex, webview click handler"
---

# Svelte + WebView Accessibility Cleanup

Class-level skill for fixing Svelte accessibility warnings in desktop/webview contexts.

## Core Principle

When Svelte a11y warns on a `<div>` with mouse/keyboard handlers, stop suppressing it and use a semantic interactive element instead.

## Preferred Fixes

### 1. Clickable container → `<button type="button">`
Best when the region’s primary job is “click to focus/activate.”

```svelte
<button
  type="button"
  class="scrollback"
  bind:this={scrollEl}
  aria-label="Shell output"
  onclick={() => inputEl?.focus()}
  onkeydown={(e) => {
    if (e.key === 'Enter' || e.key === ' ') {
      e.preventDefault();
      inputEl?.focus();
    }
  }}
>
```

With a native button, drop `role`, `tabindex`, and suppression comments.

### 2. List row containing a nested button → `<div role="button" tabindex="0">`
A row must stay non-semantic when it contains a real `<button>` child, because `<button>` cannot contain another `<button>`.

```svelte
<div
  class="session {s.id === activeId ? 'active' : ''}"
  role="button"
  tabindex="0"
  onclick={() => selectChat(s)}
  onkeydown={(e) => {
    if (e.key === 'Enter' || e.key === ' ' || e.key === 'Tab') {
      e.preventDefault();
      selectChat(s);
    }
  }}
>
  <div class="session-main">...</div>
  <button class="close-btn" onclick={(e) => closeChat(s, e)}>✕</button>
</div>
```

Use `e.stopPropagation()` in the nested button handler so it doesn’t also activate the row.

### 3. Backdrop / modal overlay → `<div role="button" tabindex="0">`
An overlay that closes on click/Enter/Space/Escape is fine as a div, but wire keyboard support explicitly.

```svelte
<div
  class="backdrop show"
  role="button"
  tabindex="0"
  aria-label="Close dialog"
  onclick={() => (open = false)}
  onkeydown={(e) => {
    if (e.key === 'Enter' || e.key === 'Escape' || e.key === ' ') {
      e.preventDefault();
      open = false;
    }
  }}
></div>
```

## CSS Normalization for Button-Like Containers

When you turn a `<div>` into a `<button>` but want it to look/layout like plain text or a scrollback region:

```css
.your-class {
  min-height: 0;
  text-align: left;
  background: transparent;
  border: none;
  outline: none;
  box-shadow: none;
  cursor: pointer;
}
.your-class:hover {
  background: rgba(255, 255, 255, 0.02);
}
```

- `min-height: 0` prevents flex child growth/scroll issues.
- `text-align: left` avoids browser default button centering.
- Reset visual chrome so it blends into the parent shell/card.

## WebView-Specific Behavior

- `<button>` works reliably inside webkit2gtk-4.1 without CSP surprises.
- If `<div role="region" tabindex="0">` still triggers warnings, make it a native control or accept the semantic trade-off.
- Nested interactive elements (`button` inside `button`) are invalid HTML. Use the row-role pattern instead.

## Verification

```bash
npm run build
```

Confirm these warnings are gone:
- `a11y_click_events_have_key_events`
- `a11y_no_static_element_interactions`
- `a11y_no_noninteractive_element_interactions`
- `a11y_no_noninteractive_tabindex`

Runtime checks:
- Tab order includes the region/row.
- Enter/Space activates it.
- Escape closes it when appropriate.
- Nested controls still fire without double-activating the parent.

**Verify from build output, not just absence of warnings in IDE.** Vite-plugin-svelte reports the file path + column for each rule. After editing, grep the build log for the same warning strings; if they still appear, the fix didn’t actually land.

## Suppression Discipline

`<!-- svelte-ignore ... -->` is acceptable only when the semantic element is genuinely the right structure and the warning is a false positive. Do not use it as a first-pass workaround for “this div has a click handler.” Prefer native controls or explicit ARIA+keyboard wiring first.

## Scrollback / Terminal Region Pattern

In TUI-like webviews, a scrollback output area often needs “click to focus input.” The clean a11y-safe implementation is a native `<button type="button">` with visual chrome reset:

```svelte
<button
  type="button"
  class="scrollback"
  bind:this={scrollEl}
  aria-label="Shell output"
  onclick={() => inputEl?.focus()}
  onkeydown={(e) => {
    if (e.key === 'Enter' || e.key === ' ') {
      e.preventDefault();
      inputEl?.focus();
    }
  }}
>
  <!-- output rows -->
</button>
```

```css
.scrollback {
  flex: 1;
  overflow-y: auto;
  padding: 10px 12px;
  white-space: pre-wrap;
  word-break: break-word;
  min-height: 0;
  text-align: left;
  background: transparent;
  border: none;
  outline: none;
  box-shadow: none;
  cursor: pointer;
}
.scrollback:hover {
  background: rgba(255, 255, 255, 0.02);
}
```

Why this beats `role="region" tabindex="0"`:
- `<button>` is natively focusable and keyboard-activatable.
- No `<!-- svelte-ignore -->` needed.
- One control, no duplicate activation path with nested buttons.

## Pitfalls

- Replacing a row container with `<button>` and nesting another `<button>` inside breaks HTML validity. Use `<div role="button">` for the row instead.
- Native buttons center text in some webviews; reset with `text-align: left;`.
- Removing `tabindex="0"` from a previously-focusable region changes tab order; verify after each change.
- If a `<button>` used as a scrollback area grows unexpectedly, add `min-height: 0;` in flex containers.