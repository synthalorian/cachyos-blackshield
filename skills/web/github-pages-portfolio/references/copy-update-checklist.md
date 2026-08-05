# Copy Update Checklist — Portfolio Site

When updating scope, role, messaging, or project descriptions, verify ALL these locations to prevent stale/inconsistent copy.

## Meta Tags (head)
- [ ] `meta name="description"`
- [ ] `meta property="og:description"`
- [ ] `meta name="twitter:description"`

## Hero Section
- [ ] `.hero-subtitle` — primary tagline, languages, scope
- [ ] `.hero-badge` text (if changing status)

## About Section
- [ ] `.section-desc` under `#about`
- [ ] Stat cards (repo count, project count) — update BOTH HTML and `js/main.js`

## Projects Section
- [ ] `.section-title` — header text
- [ ] `.section-desc` — subheader text
- [ ] Individual `.project-desc` paragraphs (only the ones being changed)
- [ ] `.project-version` spans (if bumping)

## Skills Section
- [ ] `.section-desc` under `#skills`
- [ ] Individual skill names and percentages
- [ ] Category titles (if reorganizing)

## Contact Section
- [ ] `.contact-desc` — role level, scope, call to action

## Footer
- [ ] `.footer-text` — build notes, source link

## Common Patterns

**Adding "open source" messaging:**
- Hero subtitle: append after languages list — "Every project I build is open source. My apps, my tools, my themes — all free to fork, customize, and ship."
- About section: "I build open-source software that spans..." (not "I build software")
- Featured work description: append at end — "Every project is open source."
- Do NOT add to: footer, projects header title, code-across-stack description, meta tags unless explicitly asked
- When user says "remove ALL open source references", they mean from the places they didn't specify (footer, header, code-across-stack) — keep in hero/about/featured work. If they later say "I didn't want to remove ALL of them", they're confirming the original three spots should stay.
- When removing references, always list the locations you're removing from and ask "should I keep it in [hero/about/featured work]?"

**Broadening scope (e.g., adding game engines):**
Add to hero subtitle list, about description, skills section description, contact description. Check if any project cards should mention it too.

**Dropping "Junior" from role:**
Update hero subtitle, contact description. Check about section for any role-level language.

**Project description corrections:**
Update ONLY the specific card's `.project-desc`. Do not touch other cards. Verify the correction is factually accurate before committing.
