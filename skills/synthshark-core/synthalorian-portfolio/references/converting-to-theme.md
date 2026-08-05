# Converting Personal Portfolio to Generic Open-Source Theme

**Pattern:** When the user wants to strip personal identity from their portfolio repo and repurpose it as a reusable theme.

## Steps

1. **Audit for PII** — search `index.html` for:
   - Real name, email, phone, location
   - Personal bio details (age, job history, specific companies)
   - Real project descriptions with proprietary or personal data
   - Social links beyond GitHub
   - Profile photos or personal images

2. **Replace hero content** — convert from "I am X, I do Y" to "This is a theme for Z"
   - Change title from personal name to theme name
   - Replace personal subtitle with theme description
   - Update badge from "Available for opportunities" to "Open Source & Free to Use"
   - Change CTAs from "Contact me" / "View my work" to "View Demo" / "Fork on GitHub"

3. **Replace real projects with demo placeholders** — 3 generic cards showing:
   - "Your Project Here" (featured card with glow)
   - "Another Project" (standard card)
   - "Third Example" (standard card)
   - Each explains a feature of the theme (featured cards, stats integration, responsive grid)
   - Remove all `data-repo` attributes (no live GitHub stats for demos)
   - Keep `data-reveal` for scroll animations

4. **Replace About section** — convert from personal story to theme features:
   - "Code across the stack" → "Built for builders"
   - Personal bio → theme description (zero dependencies, CSS-driven, etc.)
   - Personal stats (repos, followers) → theme stats (0 deps, 2 themes, ~50KB, 100% open source)

5. **Replace Skills section** with Features section:
   - Rename "Tech Stack" → "What's included"
   - Replace language skill bars with feature checklists (all at 100%)
   - Group by: Visual, Components, Integrations, Performance

6. **Replace Contact section** with Usage section:
   - "Let's build something" → "Use this theme"
   - Personal pitch → fork/push/deploy instructions
   - Remove email, LinkedIn, etc.
   - Single CTA: "Fork on GitHub"

7. **Update footer** — remove personal copyright, keep theme attribution

8. **Update README** — convert from project description to theme documentation:
   - Features list
   - Quick start (fork → rename → replace → push)
   - Customization guide (CSS custom properties)
   - File structure
   - License (MIT)

9. **Update meta tags** — all OG/Twitter/meta descriptions should describe the theme, not a person

10. **Commit message pattern:**
    ```
    refactor: convert personal portfolio to open-source theme
    
    - Remove all personal identity info
    - Replace with generic demo content
    - Add open-source messaging
    - Update README with theme docs
    ```

## Open-Source Messaging Placement

The user's preference: mention open-source commitment prominently in the hero intro. Example:

> "Every project I build is open source. This theme, my apps, my tools — all free to fork, customize, and ship. The code is the canvas."

Place this in the hero subtitle, near the end, in `<strong>` tags for emphasis.
