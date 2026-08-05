---
name: synthalorian-portfolio
description: "Manage the synthalorian.github.io portfolio site — add featured projects, update skills, maintain consistency across HTML/CSS/JS. Use when: adding/removing/editing portfolio projects, updating skills section, changing hero or contact copy, or any edit to /home/synth/synthalorian.github.io/."
---

# synthalorian-portfolio

> *"The grid shows what you've built. Keep it current."*

## Quick Reference

| File | Purpose |
|------|---------|
| `index.html` | Single-page portfolio (hero, about, projects, skills, contact, footer) |
| `css/style.css` | All styles including per-icon CSS animations |
| `js/main.js` | Theme toggle, GitHub stats fetch (global + per-repo), scroll reveal, skill bars, mobile nav |

**Repo:** `https://github.com/synthalorian/synthalorian.github.io`
**Live:** `https://synthalorian.github.io/`

## Support files
- `templates/project-card.html` — copy-paste template for new cards
- `references/count-update-locations.md` — all three count sync points
- `references/converting-to-theme.md` — how to strip personal identity and repurpose as a generic open-source theme

## Adding a Featured Project

This is a 5-step coordinated change across three files. **Every step is required.**

### Step 1: Choose the Icon & Color

Pick a color accent from the synthwave '84 palette:
- Purple: `var(--accent-purple-bright)` — general, systems
- Cyan: `var(--accent-cyan-bright)` — networking, time, data
- Yellow: `var(--accent-yellow)` — scripture, gold, highlights
- Pink: `var(--accent-pink-bright)` — audio, music, heart
- Red: `var(--accent-red)` — tools, forge

Choose an SVG icon (Feather-style, 24x24 viewBox, `stroke-width="1.5"`). The icon's class name becomes `icon-<name>` and MUST have a matching CSS animation.

### Step 2: Add CSS Animation

Insert animation CSS between the last existing icon animation and the `/* Hover boost */` comment in `css/style.css`. Every icon class needs:

```css
/* <Name> <description> */
.icon-<name> svg {
  animation: <name>Anim <duration>s <easing> infinite;
  transform-origin: <origin>;
}

@keyframes <name>Anim {
  0%, 100% { ... }
  50% { ... }
}
```

**PITFALL:** If you add a card WITHOUT a CSS animation, the icon will be static while all others animate. User will notice and call it out. Always pair card + animation in the same commit.

For icons with multiple animateable children (bars, circles, paths), use `:nth-child()` with staggered `animation-delay` values.

**Existing animations (as of May 2026):**
- `.icon-synth` — waveform barBounce (1.6s, staggered delays)
- `.icon-wing` — wingFlutter rotate (2.5s)
- `.icon-janus` — maskTilt rotate (3s)
- `.icon-forge` — forgeStrike rotate (2.8s)
- `.icon-bible` — pageTurn scaleX (3.5s)
- `.icon-rocket` — rocketThrust translateY (2s)
- `.icon-heart` — heartbeat scale (1.8s)
- `.icon-beacon` — beaconSpin rotate (6s linear)
- `.icon-mesh` — nodePulse circles (2s, staggered delays)
- `.icon-sword` — swordShimmer opacity (2.4s)
- `.icon-clock` — clockTick rotate wobble (3s)
- `.icon-psalm` — psalmOpen scaleX (3.2s)
- `.icon-amp` — wavePulse path opacity (1.4s, staggered delays)

All icons speed up on hover (`animation-duration: 0.6s !important`) and respect `prefers-reduced-motion: reduce`.

### Step 3: Insert the HTML Card

Insert before the closing `</div>` of `.projects-grid`. Template:

```html
<!-- Project Name -->
<article class="project-card" data-reveal data-repo="repo-name-exactly-as-on-github">
  <div class="project-header">
    <div class="project-icon icon-<name>" style="background: rgba(R, G, B, 0.06); color: var(--accent-<color>-bright);">
      <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"><!-- SVG paths --></svg>
    </div>
    <div class="project-meta">
      <span class="project-version">vX.Y.Z</span><!-- optional, omit if no version -->
      <span class="project-status stable|beta">Status Label</span>
    </div>
  </div>
  <h3 class="project-name">Project Name</h3>
  <p class="project-desc">
    One-paragraph description. Be specific about what it does, key features, and tech highlights.
  </p>
  <div class="project-stats" data-repo-stats="repo-name-exactly-as-on-github">
    <!-- Copy the standard 4-stat block: stars, forks, lang, updated -->
  </div>
  <div class="project-tech">
    <span class="tech-tag rust|dart|ts|ruby">Lang</span>
    <span class="tech-tag">Framework</span>
  </div>
  <div class="project-links">
    <a href="https://github.com/synthalorian/repo-name" target="_blank" rel="noopener" class="link-primary">
      <!-- GitHub SVG icon -->
      View Source
    </a>
  </div>
</article>
```

**Rules:**
- `data-repo` and `data-repo-stats` must match the GitHub repo name EXACTLY (case-sensitive) for live stats to work
- `data-reveal` triggers scroll-reveal animation
- Tech tags: use language-specific classes (`rust`, `dart`, `ts`, `ruby`) for colored labels
- `project-status`: use `stable` (green) or `beta` (yellow). If the project isn't fully tested, use `beta`
- Copy the stats block from any existing card — it's identical across all projects

### Step 4: Update Featured Project Count

This is a **THREE-PLACE** change. Missing any one causes inconsistency:

1. **HTML fallback** — `data-fallback="N"` in the stats-grid section
2. **HTML display** — `data-live="true">N<` in the same stat-number
3. **JS counter** — `case 'projects': value = N; break;` in `js/main.js`

All three must match. Count = total number of `<article class="project-card">` elements.

### Step 5: Commit & Push

```bash
cd /home/synth/synthalorian.github.io
git add -A
git commit -m "feat: add <Project Name> to featured projects (N total)"
git push
```

GitHub Pages auto-deploys from `main` branch within ~1 minute.

## Updating Skills Section

The skills section (id="skills") has four categories. When repos add new languages/tools:

1. **Systems & CLI** — Rust, C++, CLI Design, Tokio, Shell
2. **Web & Backend** — TypeScript, React, Node.js, Rails, Elixir/BEAM
3. **Mobile & Desktop** — Dart/Flutter, Riverpod, Tauri 2, Native FFI
4. **Specialized** — 3D/Bevy, Audio DSP, TUI/Terminal, Mesh, Game Dev

Keep 4-5 items per category. Drop items that are only in 1-2 repos. Percentages are approximate — don't overthink them.

## Updating Hero/About/Contact Copy

When languages change, these sections need updating:
- **Meta tags** (line ~7): `<meta name="description">`, `og:description`, `twitter:description`
- **Hero subtitle** (line ~78): the `highlight` spans listing languages
- **About section** (line ~108): the paragraph listing domains
- **Contact section** (line ~710): the "ship across the stack" line

All should list the same languages in consistent order: Rust, Dart, TypeScript, C++, Ruby, Elixir.

## Site Architecture Notes

- **Single-page, no framework** — pure HTML + CSS + vanilla JS
- **Picnic CSS** loaded from CDN for base grid (barely used, mostly custom CSS)
- **GitHub API** fetches stats client-side (unauthenticated, 60 req/hr limit)
- **Two themes** — synthwave84 (default, dark) and cyberlight (toggle)
- **Stats are double-layered** — HTML fallback values shown immediately, JS replaces with live API data
- **No build step** — edit files directly, push to deploy