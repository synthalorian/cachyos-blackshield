# AI Image Generation for Project Branding

Workflow for generating high-quality branded assets (logos, title screens, banners) using FAL AI image generation.

## When to Use

- Project needs a logo, title screen, or banner
- Retro/pixel-art aesthetic desired
- Quality must match reference standards (Hermes Agent, CLAW game tier)

## Quality Standards

| Tier | Description | Examples |
|------|-------------|----------|
| **A** | Polished pixel art, intentional design, dominates frame | Hermes Agent header, CLAW title |
| **B** | Decent retro aesthetic, cohesive but not iconic | Generic synthwave UI |
| **C** | Amateur, placeholder quality, unreadable | Truncated text, abstract shapes |

Target: **A-tier** for production assets.

## Model Selection (FAL)

| Model | Speed | Best For | Cost |
|-------|-------|----------|------|
| `fal-ai/krea/v2/large` | ~25-60s | Photorealism, raw textured looks, retro aesthetics | $0.060/image |
| `fal-ai/flux-2/klein/4b` | <1s | Fast, crisp text | $0.006/MP |
| `fal-ai/flux-2-pro` | ~6s | Studio photorealism | $0.03/MP |
| `fal-ai/ideogram/v3` | ~5s | Best typography | $0.03-0.04/image |

**Pick for retro/pixel branding:** `fal-ai/krea/v2/large` — photorealism + raw texture gives gritty retro-analog feel.

## Prompt Engineering

Structure prompts in layers:

```
[ERA] + [MEDIUM] + [SUBJECT] + [STYLE DETAILS] + [COLOR PALETTE] + [COMPOSITION] + [QUALITY FLAGS]
```

Example (OpenShark title screen):
```
Retro 1980s DOS game title screen for "OPENSHARK".

MASSIVE TITLE: "OPENSHARK" in huge chunky pixel-art letters.
Two-tone purple fill, thick white outline, deep 3D extrusion shadow.
Letters HEAVY, BOLD, dominating top half.

CENTER: Detailed pixel-art shark dorsal fin in hot pink with white highlight.
Curve on trailing edge, notches at base, center ridge line.

BOTTOM: Three layers of pixel-art ocean waves in bright cyan.
White foam crests, sea spray dots.

Authentic 8-bit/16-bit pixel art. No smooth gradients. Hard pixel edges only.
```

## Iteration Workflow

1. **Generate v1** — broad prompt, see what the model produces
2. **Vision analyze** — critical assessment against A-tier standards
3. **Refine prompt** — add specific details the model missed
4. **Repeat** — until vision analysis confirms A-tier

Common fixes:
- Text too thin → "thick stroke", "heavy bevel", "3D extrusion"
- Colors wrong → specify hex codes: `#8F00FF`, `#FF7EDB`, `#F3E70F`
- Abstract shapes → "immediately recognizable", "not a simple triangle"
- Waves look bad → "organic variation", "not perfectly repeating"

## Color Palette Lock

For synthwave '84 projects, always specify:
- Background: `#240037` (deep purple)
- Primary: `#8F00FF` (electric purple)
- Accent: `#FF7EDB` (hot pink)
- Highlight: `#F3E70F` (neon yellow)
- Secondary: `#00ffff` (cyan)

## Applying to Project

1. Download PNG: `curl -L -o asset.png <fal_url>`
2. Copy to repo: `cp asset.png project/openshark.png`
3. Add to `assets/` for reference: `mkdir -p assets && cp asset.png assets/`
4. Update README.md banner reference
5. Commit: `git add -A && git commit -m "feat: A-tier title screen asset"`

## Pitfalls

- **Don't trust first generation** — always iterate
- **Vision model assessment is critical** — it catches issues you miss
- **Specify "NO [color]" explicitly** if the model keeps using wrong colors
- **Remove UI chrome** — "NO status bar", "NO text at bottom" for clean assets
- **Test in actual context** — a great standalone image may not work as a README banner
