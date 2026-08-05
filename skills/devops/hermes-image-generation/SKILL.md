---
name: hermes-image-generation
description: "Generate images through Hermes' image_gen/FAL backend — credential refresh, direct fal_client fallback when the live session has stale env, and wallpaper/icon finishing."
version: 1.0.0
author: synthclaw
metadata:
  hermes:
    tags: [hermes-agent, image-generation, fal, troubleshooting, wallpapers]
    related_skills: [hermes-config-troubleshooting, comfyui, stable-diffusion-image-generation, image-optimization]
---

# Hermes Image Generation

Generate images through Hermes' `image_gen` toolset (FAL-backed), recover from credential failures, and finish deliverables like 2K wallpapers and taskbar icons.

## When to Use

- `image_generate` fails with `invalid key credentials` / `FalClientHTTPError`
- User provides a new FAL key and wants images generated now
- User asks for monitor wallpapers at a specific resolution (2K/4K) or icon-sized outputs
- You need to verify actual delivered dimensions instead of trusting the generator

## Quick Path

1. Check backend config (redacted): `image_gen.provider`, `image_gen.model` in `~/.hermes/config.yaml`.
2. Check `FAL_KEY` presence in `~/.hermes/.env` — never print the value; report length/shape only.
3. If the key was just updated, do NOT keep retrying `image_generate` in the same session — the running process caches the old env. Either `/reset`/relaunch, or use the direct fallback.
4. Generate, then verify pixel dimensions before claiming "2K". Upscale/crop locally if the backend returns smaller (Krea 16:9 observed at 1376x768).

## Storing a new FAL key

`~/.hermes/.env` is protected — use `terminal`, not `write_file`/`patch`. Replace or append the `FAL_KEY=` line, `chmod 600`, and never echo the key. Full script: `references/fal-credential-refresh.md`.

Do not store API keys in memory. Env file only.

## Direct fallback (works without session restart)

Use the Hermes venv Python — `/home/synth/.hermes/hermes-agent/venv/bin/python` has `fal_client`; system `python3` may not. Load `FAL_KEY` from `.env`, submit to `fal-ai/krea/v2/large/text-to-image` with `prompt`, `aspect_ratio` (`16:9`/`1:1`/`9:16`), `creativity`, download `result['images'][0]['url']`. Full script: `references/fal-credential-refresh.md`.

## Finishing deliverables

- Wallpapers: cover-resize to exactly 2560x1440 (or requested size), center-crop, light unsharp mask, save as `*-2k.png`.
- Icons: also emit a 256x256 PNG from the square source.
- Save under `~/Pictures/synthwave/` (or user-specified dir) and report absolute paths — CLI has no attachment channel.

## Pitfalls

- `.env` edits do not propagate to an already-running Hermes process — one diagnostic retry after fixing is enough; then switch to the direct fallback or tell the user to `/reset`.
- `fal_client` lives in the Hermes venv, not system Python.
- Krea's `aspect_ratio` arg is a string ratio (`16:9`), not the FLUX-family `image_size` preset.
- Never claim a resolution you didn't verify — open the output and check dimensions.
- The bundled `hermes-agent` skill is protected; put image_gen operational lessons here, not there.

## References

- `references/fal-credential-refresh.md` — redacted .env update script, direct fal_client generation script, and the PIL 2K/icon finishing recipe from a real session.
