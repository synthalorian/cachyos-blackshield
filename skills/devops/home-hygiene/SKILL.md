---
name: home-hygiene
description: >
  Home cleanup: repo org, cache prune, appdata trim.
version: 1.0.0
tags: [linux, arch, cachyos, cleanup, cache, repos, hygiene]
---

# Home Hygiene

Safe, repeatable cleanup for an Arch/CachyOS workstation. Skip system zones
(`/usr/`, `/etc/`) unless explicitly approved.

## Repo-move audit

Moving a repo directory under `~/Projects` commonly breaks hardcoded absolute
paths outside the repo. After any move, scan and fix:
- `~/.local/share/applications/*.desktop` — `Exec=` and `TryExec=`
- `~/.config/systemd/user/*.service` — `ExecStart=`, `WorkingDirectory=`
- `~/.config/fish/*` — wrappers/functions that cd or invoke the moved path

Use targeted sed/patch on the specific moved path. Do NOT grep the moved repo
itself for the old path: that reports every internal file as a false positive.

## Zones

- `~/Projects/{active,archived,backburner,finished,forks,faith}` — repo home
- `~/Projects/` root — usually stale logs/clutter
- `~/.config/` — user app config
- `~/.local/share/` — app data
- `~/.cache/` — build/cache artifacts

## Repo triage

1. Identify strays under `~/Projects`, duplicate lineages, and stale root files.
2. Move active forks/branches into category folders.
3. Detect duplicates with directory content `diff -qr`, not only filenames or git log.
4. Purge clone logs, dead placeholder repos, and dead-certain duplicates.

## Cache prune targets (safe by default)

- `~/.cache/paru/clone/` and `~/.cache/paru/packages.aur/`
- `~/.cache/mozilla`, `~/.cache/chromium`, `~/.cache/pnpm`, `~/.cache/electron`
- `~/.cache/pip`, `~/.cache/winetricks`, `~/.cache/wine`

Measure before and after with `du -sh`.

## Appdata targets

### Chromium
Safe to prune:
- `~/.config/chromium/Default/Cache`
- `~/.config/chromium/GPUCache`
- `~/.cache/chromium`

Keep: `Bookmarks`, `Login Data*`, `Preferences`, `History`, `Secure Preferences`.

### Discord
Safe to prune:
- `logs`, `Cache`, `Code Cache`, `Service Worker`, `Shared Dictionary`, `VideoDecodeStats`

Keep: `settings.json`, `Cookies`, `Trust Tokens`, `app-<ver>`.

### Lutris
- `runtime/` is usually safe
- `runners/wine/` requires explicit approval
- Keep `games/`, config, banners, coverart

### Steam
- Do not touch without explicit go-ahead
- Typical cache: `~/.local/share/Steam/`

## Sequencing

1. Repo org + dedupe first.
2. Cache prune.
3. Browser/app cache prune.
4. Heavy runtime dirs (Lutris `runners/wine`, Steam, Discord `app-<ver>`) only after approval.

## Pitfalls

- Do not bulk-delete non-build files in a short window without approval; security tools can
  flag mass deletions.
- Paru caches live under `~/.cache/paru/clone/`, not `/var/cache/pacman/pkg/`.
- Duplicate repo check must include content diff, not filenames or git log only.
- Steam/Lutris runtimes can exceed 100GB combined; default to leave untouched.
