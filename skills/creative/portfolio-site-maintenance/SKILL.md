---
name: portfolio-site-maintenance
description: Maintain and update synth's GitHub Pages portfolio site at synthalorian.github.io — add featured project cards, update stats, keep content evergreen.
---

# Portfolio Site Maintenance

The portfolio site lives at `/home/synth/synthalorian.github.io/` — a single-page synthwave '84 themed site with:
- `index.html` — all content (hero, about, projects grid, skills, contact, footer)
- `css/style.css` — all styling including per-icon CSS animations
- `js/main.js` — theme toggle, live GitHub stats, scroll reveal, mobile nav

## Adding a Featured Project Card

When adding a new project to the featured grid, follow this checklist:

### 0. Survey the Repo First

Before writing any HTML, check the actual repo to get accurate numbers:

```bash
# Count presets, categories, or other quantifiable data
grep -c "id: 'factory-" ~/projects/open-synth/lib/data/factory_presets.dart

# Count categories
grep "category:" ~/projects/open-synth/lib/data/factory_presets.dart | sed 's/.*category: //' | sed 's/,.*//' | sort | uniq -c | sort -rn

# Check repo status for version/tag
curl -s "https://api.github.com/repos/synthalorian/REPO_NAME" | jq -r '.description, .language'
```

**Never guess numbers.** The card for Open Synth originally said "377 presets / 15 categories" when the actual count was 1,415 presets / 24 categories. Always verify against the source.

### 1. HTML Card Structure

Insert the `<article class="project-card">` block into the `projects-grid` div. Pick a position that makes sense (newest at bottom, or grouped by domain). Use the exact structure below, customizing only the project-specific fields:

```html
<!-- Project Name -->
<article class="project-card" data-reveal data-repo="repo-name">
  <div class="project-header">
    <div class="project-icon icon-XXXX" style="background: rgba(R, G, B, 0.06); color: var(--accent-XXXX-bright);">
      <svg>...</svg>
    </div>
    <div class="project-meta">
      <span class="project-version">v1.0.0</span>  <!-- optional, omit if no version -->
      <span class="project-status stable">Stable</span>  <!-- or beta, or omit -->
    </div>
  </div>
  <h3 class="project-name">Project Name</h3>
  <p class="project-desc">...</p>
  <div class="project-stats" data-repo-stats="repo-name">
    <!-- Standard stats block — copy from any existing card -->
  </div>
  <div class="project-tech">
    <span class="tech-tag rust">Rust</span>
    <!-- etc -->
  </div>
  <div class="project-links">
    <a href="https://github.com/synthalorian/repo-name" ...>View Source</a>
  </div>
</article>
```

### Status Badge Guidelines

| Status | When to use |
|--------|-------------|
| `stable` | Fully working, tested, no known blockers |
| `beta` | Functional but not fully tested, may have rough edges |
| `active dev` | Currently being built, API may change |
| `released` | Shipped to users (apps on store, binaries published) |

**Be honest.** If a project like Open-Amp isn't fully tested, mark it `beta`. Don't oversell.

### 2. Icon Animation (REQUIRED)

Every `icon-XXXX` class MUST have a corresponding CSS animation in `css/style.css`. Add it after the last icon animation block (before the `/* Hover boost */` comment). See `references/icon-animation-template.md` for patterns and reusable keyframe templates.

**New icons added this session that need animations:**
- `.icon-clock` — clock tick (gentle wobble)
- `.icon-psalm` — page reveal (scaleX book opening)
- `.icon-amp` — sound wave pulse (opacity on wave paths)

See `references/icon-animation-template.md` for full patterns including the clock tick and page reveal animations.

### 3. Update Featured Count

After adding a card, update the count in THREE places:
- **`index.html`**: `data-fallback="N"` and `<div class="stat-number" data-live="true">N</div>` in the stats grid
- **`js/main.js`**: `case 'projects': value = N;` in `fetchGitHubStats()`

### 4. Commit & Push

```bash
cd /home/synth/synthalorian.github.io
git add -A
git commit -m "feat: descriptive message"
git push
```

Site deploys automatically via GitHub Pages from the `main` branch.

## Evergreen Language

- **Repo count in about**: Use "dozens of public repositories and growing" — never a hardcoded number. The live stat counter pulls from GitHub API.
- **Skills section**: Should reflect ALL public repos. When a new language/framework appears across repos, add it to the appropriate skills category.
- **Hero intro**: Should mention the breadth — CLI, mobile, desktop, audio DSP, web, 3D, mesh, TUI.
- **Contact/outro**: Should hit the key domains: "Rust CLIs, C++ terminal tools, Flutter apps, Rails dashboards, Elixir mesh relays, real-time audio DSP"

## Site Conventions

- **Palette**: Exact Omarchy Synthwave '84 colors — `#8f00ff` purple primary, `#ffff66` yellow, `#ff007f` pink, `#03edf9` cyan, `#ff00ff` magenta
- **Status badges**: `stable` (green), `beta` (yellow/cyan), `active dev` (cyan), `released` (green). Use `project-status` class.
- **Tech tags**: Use language-specific classes for color: `rust`, `dart`, `ts`, `ruby`
- **All icons animated**: Every `.icon-XXXX` class needs a CSS animation. No static icons.
- **Hover boost**: All icons speed up on card hover (0.6s) and respect `prefers-reduced-motion`
- **Project descriptions**: Lead with what it IS, then what it DOES. Example: "Cross-platform guitar amplifier and effects processor with real-time DSP. Native audio engine for Linux, Android, and iOS. Effects chain routing, cabinet simulation..."
- **Open-source commitment**: Mentioned explicitly in about section — "every project free and open-source"