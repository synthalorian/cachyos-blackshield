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
6. **For lock/login wallpapers AND boot-loader splashes, design around the system UI.** KDE/SDDM-style screens place clock/avatar/password near center; Limine's boot menu also renders dead-center over the wallpaper. Avoid dead-center subjects; put the focal subject lower/right and reserve the upper center and exact center as dark, uncluttered negative space. During visual verification, explicitly ask whether the center and upper-center remain readable for UI text. For boot splashes, sample center pixels with PIL (mean RGB) to prove the menu zone is dark before shipping.

## Hermes/FAL Backend Notes

- Hermes `image_gen` uses FAL when `image_gen.provider: fal`. Secrets belong in `~/.hermes/.env` (`FAL_KEY`), never in memory.
- If `FAL_KEY` is updated mid-session and `image_generate` still fails with stale/invalid credentials, generate immediately via the Hermes venv direct `fal_client` path (`/home/synth/.hermes/hermes-agent/venv/bin/python`) or restart the session. Capture the fix, not "the tool is broken".
- Krea/FAL text-to-image supports `prompt`, `aspect_ratio`, `creativity`, and `seed` for this class of artistic wallpaper/icon generation.
- Krea 2 Large landscape returns only ~1376×768 — plan on a lanczos upscale to the target resolution. For synthwave/outrun art the grain and glow hide upscale softness; verify the result visually.
- synth's wallpaper/boot/login art target: **2560×1440 native** (primary 2K panel). Do NOT default to the ultrawide 2560×1080 — user corrected this (2026-08).

## Post-Processing

Use `scripts/cover_resize.py` to resize/crop a source image to an exact wallpaper size without distorting aspect ratio.

**Icon pitfall — AI renders gibberish alphabet letters despite `no text`.** Prompts with "letters/runes rising from a book" produce legible-but-nonsense Latin text even WITH the standard negatives — the model treats floating letters as decoration, not text. For icon work add explicit `no letters, no alphabet, no Latin characters, no words` alongside the standard negatives, and verify with vision before shipping. (Session-proven 2026-08: first Albion Translator icon had gibberish floating letters; regen with alphabet negatives came out clean.)

**Icon pipeline (Tauri):** square 1024 source → circular alpha mask via PIL (2px inset + ~1.2px GaussianBlur on the mask to kill white fringe) → `npx tauri icon <source.png>` regenerates the ENTIRE cross-platform set (ico/icns/Windows Square logos/Android/iOS) into `src-tauri/icons/`. Commit the whole dir.

## References

- `references/fal-krea-synthwave.md` — session-proven synthwave prompting pattern, direct FAL generation skeleton, and the color-code-bar pitfall.
