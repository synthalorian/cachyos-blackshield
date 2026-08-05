---
name: ai-image-generation
description: "Generate AI images (wallpapers/icons/art) with reliable prompting, backend handling, and post-processing. Triggers: image generation, text-to-image, FAL, Krea, wallpaper, icon, synthwave art, upscale, cover-crop."
version: 1.0.0
tags: [image-generation, fal, krea, wallpapers, icons, synthwave, post-processing]
---

# AI Image Generation

Use this when generating or editing images with AI backends (Hermes `image_gen`, FAL/Krea, local SD/ComfyUI, etc.), especially desktop wallpapers and icons.

## Workflow

1. **Pin the deliverable before prompting:** subject, use (wallpaper vs icon), aspect ratio, final pixel size, and "must not have" elements.
2. **Prompt with color names, not literal hex codes.** Literal hex values can be rendered as visible color-code bars/swatches. Use descriptive color language ("deep midnight purple", "hot pink", "neon yellow") and put exact palette in the user's brief, not the image prompt.
3. **Always add negative constraints for clean art:** `no text, no logos, no color palette bars, no color swatches, no hex codes, no UI overlays, no bottom banner, no watermark`.
4. **Generate at the native aspect ratio**, then post-process to the exact target size. For wallpapers use cover-crop/resize to the monitor resolution (e.g. 2560x1440); for icons export a small canonical size (e.g. 256x256) and keep the 1024 source.
5. **Verify the artifact:** dimensions, file exists, and visually inspect when vision tooling is available. If the user complains about an artifact, regenerate with the offending element removed from the prompt and explicit negative constraints — don't just re-roll the same prompt.
6. **For lock/login wallpapers, design around the system UI.** KDE/SDDM-style screens usually place the clock, avatar, and password prompt near the center. Avoid dead-center subjects; put the focal subject lower/right and reserve the upper center and exact center as dark, uncluttered negative space. During visual verification, explicitly ask whether the center and upper-center remain readable for login UI.

## Hermes/FAL Backend Notes

- Hermes `image_gen` uses FAL when `image_gen.provider: fal`. Secrets belong in `~/.hermes/.env` (`FAL_KEY`), never in memory.
- If `FAL_KEY` is updated mid-session and `image_generate` still fails with stale/invalid credentials, generate immediately via the Hermes venv direct `fal_client` path (`/home/synth/.hermes/hermes-agent/venv/bin/python`) or restart the session. Capture the fix, not "the tool is broken".
- Krea/FAL text-to-image supports `prompt`, `aspect_ratio`, `creativity`, and `seed` for this class of artistic wallpaper/icon generation.

## Post-Processing

Use `scripts/cover_resize.py` to resize/crop a source image to an exact wallpaper size without distorting aspect ratio.

## References

- `references/fal-krea-synthwave.md` — session-proven synthwave prompting pattern, direct FAL generation skeleton, and the color-code-bar pitfall.
