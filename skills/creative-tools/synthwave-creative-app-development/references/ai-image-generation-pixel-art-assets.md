# AI Image Generation for Pixel Art / Retro Title Screen Assets

When building retro pixel-art title screens, splash screens, or visual identity assets for synthwave-themed projects, **use AI image generation (FAL) rather than coding pixel art with HTML/CSS**.

## Why Code-Based Pixel Art Fails

- CSS box-shadow pixel technique produces diamond/rhombus shapes instead of intended forms (shark fins become geometric diamonds)
- Canvas pixel manipulation requires precise coordinate math that is error-prone and time-consuming
- SVG paths produce smooth vector curves, not authentic hard-pixel edges
- The result is consistently B-tier or C-tier — "decent retro vibe" but lacking the craft of hand-made pixel art

**When the user demands A-tier quality matching reference standards (Hermes, CLAW), do NOT attempt code-based approaches.** Use FAL image generation. If FAL is unavailable, ask the user before proceeding.

## The FAL Approach

Use `fal-ai/krea/v2/large/text-to-image` for photoreal/raw textured retro aesthetic.

**Why Krea v2 large:**
- Photorealism + raw textured looks (motion blur, grain, film aesthetic)
- Produces gritty, retro-analog feel matching synthwave '84 vibe
- Other models are too clean (Flux, Ideogram) or wrong style

**Cost:** ~$0.060/image (text generation)

## Prompt Engineering for A-Tier Results

### Structure
1. **Era/style anchor**: "Retro 1980s DOS game title screen"
2. **Background**: "Deep dark purple (#240037) background with subtle horizontal CRT scanlines"
3. **Title specs**: Massive, chunky pixel-art letters, two-tone fill, thick white outline, 3D extrusion shadow
4. **Central graphic**: Detailed pixel-art with specific anatomical features (not "a fin" but "curved trailing edge, notches at base, center ridge")
5. **Environment**: Layered waves with foam, specific colors, organic variation
6. **Negative constraints**: "No smooth gradients, no anti-aliasing, hard pixel edges only"

### Iteration Pattern
1. Generate initial version
2. Use vision model for brutal tier assessment (A/B/C against reference standards)
3. Identify specific flaws (font too thin, fin too generic, waves too repetitive)
4. Refine prompt with specific fixes
5. Re-generate and re-assess
6. Typically reaches A-tier in 2-3 iterations

## Vision Model Quality Assessment

Use `vision_analyze` with explicit reference standards for iterative refinement:

```
HERMES standard: Pixel art with 3D drop-shadow on header, detailed symbol (caduceus),
consistent retro-terminal aesthetic, color hierarchy, header text dominates with visual weight

CLAW standard: Big blocky DOS font with thick stroke and bevel/outline effect, high contrast,
bold presence, the word DOMINATES the frame, high visibility
```

Ask for **brutal honesty** and specific tier judgment (A/B/C). Use the feedback to refine the prompt.

## Quality Reference Standards

| Tier | Description | Example |
|------|-------------|---------|
| A | Text dominates frame, thick bevel/stroke, detailed symbol, cohesive palette, intentional pixel craft | Hermes Agent, CLAW game |
| B | Good vibe, cohesive colors, but text lacks weight or symbol is generic | Most AI-first attempts |
| C | Muddy contrast, unreadable text, abstract shapes, amateur execution | CSS box-shadow attempts |

## Color Constraints — Validate With User

The synthwave palette has default associations that may not match user intent:
- **Yellow for water**: User explicitly rejected — "swimming in piss". Use cyan/blue for waves.
- Always confirm color choices for primary visual elements before locking them in.

## Applying Assets Across the Project

Once the A-tier image is generated, apply it systematically:

1. **Download and save:** `curl -L -o assets/title_screen.png <fal_url>`
2. **Replace repo banner:** Copy to project root (e.g., `openshark.png`)
3. **Update README:** Reference the new banner, update tagline if changed
4. **Create ASCII fallback:** For TUI splash screens, generate matching ASCII art (see `rust-cli-ascii-art-pitfalls.md`)
5. **Rebuild and install:** `cargo build --release && cp target/release/binary ~/.local/bin/`
6. **Commit and push:** Single commit with all asset + code changes

**PITFALL:** Don't forget to rebuild the binary after asset changes. The image file is loaded at runtime, but if the TUI code changed (new splash screen logic), the binary must be rebuilt.

## OpenShark Visual Identity (Locked Decisions)

- **Title**: "OPENSHARK" in chunky pixel-art, two-tone purple fill, white outline, 3D shadow
- **Tagline**: "Fast. Precise. Hungry." in hot pink pixel font
- **Fin**: Hot pink (#FF7EDB) with white highlight, curved trailing edge, notches at base, center ridge
- **Waves**: Cyan/blue (#00ffff, #0080FF) — **NEVER yellow**
- **Background**: Deep purple (#240037) with CRT scanlines
- **No bottom status bar**: Clean edge with just waves
- **Palette**: #240037 (bg), #8F00FF (title), #FF7EDB (fin), #00ffff (waves), #F3E70F (accents only, not water)
- **Splash screen:** Full-screen overlay on TUI launch, any key to dismiss — NOT a chat message
