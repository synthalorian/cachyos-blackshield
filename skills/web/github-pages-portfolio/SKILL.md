---
name: github-pages-portfolio
description: "Manage synthalorian.github.io — the synthwave '84 portfolio site. Adding/removing featured project cards, updating skills, stats, meta tags, and hero/contact copy. Triggers: portfolio, github pages, synthalorian.github.io, update portfolio, add project to site, portfolio site, featured projects."
---

# GitHub Pages Portfolio — synthalorian.github.io

The portfolio site lives at `~/Projects/active/synthalorian.github.io/` (moved from `~/synthalorian.github.io/` — old path is gone) and auto-deploys to https://synthalorian.github.io on every push to `main`.

## Site Structure

```
~/synthalorian.github.io/
  index.html   — single-page site (hero, about, projects, skills, contact, footer)
  css/style.css — ⚠️ NOTE: path is css/style.css, NOT styles.css
  js/main.js   — GitHub API live stats, theme toggle, scroll reveal, mobile nav
```

**CRITICAL — CSS file path:** The stylesheet is at `css/style.css`. Do NOT target `styles.css` — patches to the wrong file silently fail. Always verify with `ls` or `grep` before patching CSS.

All content is in `index.html`. No static site generator — just edit and push.

## Adding a Featured Project Card

Insert a new `<article class="project-card" data-reveal data-repo="REPO-NAME">` inside the `.projects-grid` div. Follow this template:

```html
<!-- Project Name -->
<article class="project-card" data-reveal data-repo="repo-name">
  <div class="project-header">
    <div class="project-icon icon-xxx" style="background: rgba(R, G, B, 0.06); color: var(--accent-COLOR-bright);">
      <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round">
        <!-- 24x24 icon paths -->
      </svg>
    </div>
    <div class="project-meta">
      <span class="project-version">v1.0.0</span>
      <span class="project-status stable">Stable</span>
    </div>
  </div>
  <h3 class="project-name">Project Name</h3>
  <p class="project-desc">
    Description. Keep it 2-3 sentences max — concrete, no fluff.
  </p>
  <div class="project-stats" data-repo-stats="repo-name">
    <!-- Copy stats block verbatim from any existing card — identical SVG icons -->
    <span class="repo-stat" data-stat="stars">...</span>
    <span class="repo-stat" data-stat="forks">...</span>
    <span class="repo-stat" data-stat="lang">...</span>
    <span class="repo-stat" data-stat="updated">...</span>
  </div>
  <div class="project-tech">
    <span class="tech-tag rust">Rust</span>
    <span class="tech-tag dart">Dart</span>
    <span class="tech-tag ruby">Ruby</span>
    <span class="tech-tag ts">TypeScript</span>
    <span class="tech-tag">Generic</span>
  </div>
  <div class="project-links">
    <a href="https://github.com/synthalorian/repo-name" target="_blank" rel="noopener" class="link-primary">
      <svg><!-- GitHub icon --></svg> View Source
    </a>
  </div>
</article>
```

### Key attributes

- `data-repo="repo-name"` — must match GitHub repo name exactly for live stats
- `data-repo-stats="repo-name"` — triggers JS to fetch stars/forks/lang/updated from GitHub API
- `data-reveal` — triggers IntersectionObserver scroll-reveal animation
- Icon colors use CSS variables: `--accent-cyan-bright`, `--accent-purple-bright`, `--accent-yellow`, `--accent-pink-bright`
- Tech tag language classes (`rust`, `dart`, `ruby`, `ts`) get colored accents in CSS; no class = white/neutral

### Icon color assignment

- **Purple**: music/creative/synthesis tools
- **Cyan**: system/engine/infrastructure tools, time utilities
- **Yellow/gold**: scripture/faith/knowledge tools
- **Pink**: wellness/mesh/social tools
- **Red**: forge/workshop/toolkit

## Updating the Featured Projects Count

**CRITICAL — update TWO places when adding/removing cards:**

1. **`index.html` stats card** (around line 126): `data-fallback="N"` AND the visible `stat-number` text
2. **`js/main.js`** (around line 243): `case 'projects': value = N; break;`

If you miss #2, the live GitHub API fetch overwrites your HTML count on page load.

## Updating Skills Section

Four categories in `index.html` under `#skills`: Systems & CLI, Web & Backend, Mobile & Desktop, Specialized. Each skill has a name and percentage bar (`style="width: X%"`).

Rules when modifying:
- Map percentages to real usage: 90% = primary language, 65-70% = competent, 55% = exploring
- Keep 4-5 items per category for visual balance
- Update hero subtitle, meta tags, about section, AND contact section to match any language changes

## Push to Deploy

```bash
cd ~/synthalorian.github.io
git add -A
git commit -m "feat: description of changes"
git push
```

## Pitfalls

- **Scope creep on small edits**: When the user asks for a small change (e.g., "add a sentence to the hero"), make ONLY that change. Do not rewrite the entire page, strip personal info, or convert it to a generic template unless explicitly asked. Confirm scope if uncertain.
- **Scroll indicator clipping**: The `.scroll-indicator` is `position: absolute` at `bottom: 36px` with `left: 50%`. It can overlap the GitHub Profile button on smaller viewports. **Do NOT shift it horizontally** — the overlap is vertical, not horizontal. Instead, add `margin-bottom: 80px` (or more) to `.hero-cta` to push the button row up, creating a gap between buttons and the scroll indicator below. See `references/css-absolute-overlap-debugging.md` for the full diagnostic.
- **Hero text over sun**: The hero scene has a bright sun element in the background. If the hero text drifts up into it, add `padding-top` to `.hero-content` (start with `60px`) to push the text into the darker sky area above the sun.
- **Stats counter desync**: Updating the HTML stat card but not `js/main.js` means the live counter clobbers your manual update.
- **Wrong repo name in data-repo-stats**: GitHub API fetches by repo name. A typo means dashes forever on the live stats. JS lowercases both sides, so case doesn't matter — but hyphens vs underscores do (`hermes_wingman` silently matched nothing for months; real repo is `hermes-wingman`).
- **data-repo-stats sits ON the .project-stats div**: The attribute is on the same element as `class="project-stats"`, not a parent. In main.js `fetchRepoStats`, use `card.classList.contains('project-stats') ? card : card.querySelector('.project-stats')` — a plain `querySelector('.project-stats')` returns null and every card silently renders dashes forever (this bug shipped live and was fixed 2026-07-25).
- **SVG icon reuse**: Every project card needs a unique, recognizable icon. Never duplicate.
- **Copy consistency across the page**: When updating scope (languages, project types, role level), update ALL these locations together: meta description, OG tags, Twitter tags, hero subtitle, about section, skills section description, contact section, footer. Missing one creates stale copy that contradicts the rest.
- **Open-source messaging placement**: The user wants "open source" mentioned in specific spots only — hero subtitle (after languages), about section ("I build open-source software"), featured work description end ("Every project is open source."). Do NOT add to: footer, projects header title, code-across-stack description unless explicitly asked. When in doubt, ask where to place it.
- **Project description accuracy**: When a user corrects a project description (e.g., "150 Psalms" → "1,189 chapters in the Bible"), update ONLY that card's `<p class="project-desc">`. Do not rewrite other cards. Verify the correction is factually accurate before committing.
- **Adding a new featured project card**: When inserting a new project card, also update the featured projects count in BOTH `index.html` stat card (`data-fallback="N"` and visible text) AND `js/main.js` (`case 'projects': value = N; break;`). If you skip this, the live GitHub API fetch overwrites the count on page load.
- **CSS file path**: The stylesheet is `css/style.css`, NOT `styles.css`. Patching the wrong file silently fails — always verify the path first. Run `ls css/` before any CSS patch. This mistake was made multiple times in one session before being caught.
- **Verify animations actually deployed**: After pushing CSS animation changes, verify with `git diff HEAD~1 -- css/style.css` that the changes are in the commit. If the user says "the animations didn't update" after multiple pushes, the patches were likely targeting the wrong file (`styles.css` instead of `css/style.css`).
- **prefers-reduced-motion hiding elements**: A `prefers-reduced-motion: reduce` media query that sets `display: none` on `.hero-sun::after`, `.hero-grid-floor`, `.hero-scanlines`, `.hero-palm` will make those elements invisible even when the user wants to see them. Use `animation-duration: 0.01ms` instead, or slow the animations — never hide the elements entirely.
- **Git push conflicts**: If push is rejected with "fetch first", the remote has newer commits. Use `git pull origin main --rebase` then resolve conflicts. **DO NOT blindly use `git checkout --theirs`** — this accepts remote versions and may revert changes the user explicitly requested. Instead, inspect the diff (`git diff HEAD~1 HEAD -- <file>`), understand what changed, and apply only the needed fixes. If the conflict is complex, abort and ask the user.
- **Rebase silently reverting user changes**: After `git rebase --continue`, always verify the final state with `git diff HEAD~1 HEAD -- <file>` before pushing. The rebase may have accepted remote versions that overwrite local fixes. If you used `--theirs` during conflict resolution, check EVERY file that had conflicts — the remote version may have reverted user-requested changes (scroll indicators re-appearing, copy changes lost, etc.).
- **User frustration with iterative tweaks**: When a user says "this still isn't perfect" after multiple attempts on the same feature, they want the fully-working version, not another incremental fix. If you've already deployed a version that worked (e.g., "pulse + scroll + glow"), revert to that complete version rather than continuing to tweak the broken subset. Stop explaining what you changed — just push the working state. When the user says "at this point I would rather just take the fully-functional version you put out," that is a clear signal to abandon the current approach and revert to the last known-good state.
- **User specifying animation properties**: When a user says "I want the animation OTHER THAN the one that makes it expand" or "it should stay the same size," remove ONLY the unwanted property (e.g., `scale()`). Do NOT remove all animations and start over. Do NOT add back the unwanted property "because it seems harder to get just the glow/scroll working." The user's preference is the authority — not the difficulty of implementation. If they later change their mind and want all three back, revert to the complete version.
- **Prose style — "too many ands"**: The user prefers concise list prose with minimal conjunctions. Use `&` for compound items ("mobile & desktop apps", "audio DSP & synthesizers"). Avoid chaining "and" repeatedly — use commas and a single terminal `&` or "and". When the user says "there are far too many ands there should only be one 'to' and one 'and'", rewrite the sentence with fewer conjunctions and more comma-separated items. The user specifically wants: `from X, Y, Z to A, B, and C` structure — not `from X and Y to Z and A and B and C`.
- **Repo name variants — underscores vs hyphens**: The user's projects may use `snake_case` (e.g., `open_habit`, `sc_synthesis`) rather than `kebab-case` (e.g., `open-habit`). When a user says "it's my repo" and GitHub API search returns nothing, check `~/projects/` for local directories, and try both `open-habit` and `open_habit` in API calls. Many repos are local-only or use underscore naming. The GitHub repo may be `open-habit` even if the local directory is `open_habit` — always verify the actual GitHub URL before linking.
- **User says "I want the animation OTHER THAN the one that makes it expand"**: When a user specifies they want one animation property but not another (e.g., glow + scroll but NO scale), they mean: keep the properties they like, remove the one they don't. Do NOT remove all animations and start over. Do NOT add back the unwanted property "because it seems harder to get just the glow/scroll working." If the user says "it should stay the same size," remove `scale()` from the keyframe entirely. If they later say "just take the fully-functional version that does all three," revert to the complete version that worked. The user's preference is the authority — not the difficulty of implementation.
- **Repo name variants — underscores vs hyphens**: The user's projects may use `snake_case` (e.g., `open_habit`, `sc_synthesis`) rather than `kebab-case` (e.g., `open-habit`). When a user says "it's my repo" and GitHub API search returns nothing, check `~/projects/` for local directories, and try both `open-habit` and `open_habit` in API calls. Many repos are local-only or use underscore naming.
## Animation Reference

See `references/animation-patterns.md` for all CSS animation patterns used on the site — hero scene (sun, grid, palms, scanlines), content (badge float, gradient shift, label glow), and hover effects (icon bounce, number pulse, tag lift).

**Critical animation technique — fluid stripe scroll:** For seamless scrolling stripes inside a masked element (sun, CRT scanlines, grid floor), use `background-position` animation on an oversized pseudo-element (`inset: -50%; width: 200%; height: 200%`). NEVER use `transform: translateY()` — it causes subpixel jitter/shaking when the parent has `overflow: hidden` + `border-radius`. The `background-position` shift distance must exactly match the `repeating-linear-gradient` repeat cycle. See `references/fluid-stripe-scroll.md` for the complete pattern, anti-pattern, and applied examples.

See `references/git-rebase-conflict-resolution.md` for how to handle push conflicts without reverting user-requested changes.

## Copy Consistency

See `references/copy-update-checklist.md` for the full list of locations to update when changing scope, role, messaging, or project descriptions. Missing even one creates stale copy that contradicts the rest of the page.

## References

- `references/animation-patterns.md` — CSS animation patterns and the fluid stripe scroll technique
- `references/git-rebase-conflict-resolution.md` — safe conflict resolution without reverting user changes
- `references/copy-update-checklist.md` — all locations to update for copy consistency
- `references/fluid-stripe-scroll.md` — pixel-perfect scrolling stripes inside masked elements (sun, CRT). Use `background-position` NOT `transform`.
- `references/prefers-reduced-motion-pitfall.md` — NEVER use `display: none` in reduced-motion queries. Slow animations instead.
- `references/css-absolute-overlap-debugging.md` — fixing absolute-positioned element overlap