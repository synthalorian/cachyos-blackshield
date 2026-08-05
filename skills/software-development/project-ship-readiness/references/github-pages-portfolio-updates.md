# GitHub Pages Portfolio Site Updates

Workflow for updating the synthalorian.github.io portfolio site.

## Location
- Repo: `~/synthalorian.github.io/`
- Live: https://synthalorian.github.io/

## Adding a Featured Project

1. Insert card before closing `</div>` of `.projects-grid`
2. Add CSS animation for new `.icon-NAME` in `css/style.css`
3. Update featured count in HTML (`data-fallback`) and JS (`case 'projects'`)
4. Commit and push

## Pitfalls
- Don't forget CSS animation for new icons
- Use evergreen counts ("dozens of") in About, not exact numbers
- Update meta tags when hero changes
- Test grid layout — odd card counts may leave gaps
