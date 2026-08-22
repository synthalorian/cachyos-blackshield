---
name: cachyos-site-config
description: Site-specific config patterns for synth's CachyOS machine.
version: 1.0.0
tags: [linux, cachyos, limine, fish, boot]
---

# CachyOS Site Config Patterns

Patterns encoded from real debugging sessions on this machine.

## Limine Bootloader Theming

Canonical config: `cachyos-blackshield/configs/limine/limine.conf`. Deployed to `/boot/` via handoff script.

### Pitfalls
1. **Malformed hex kills readability:** stray prefix on `term_*` hex values (e.g. `E6240037` instead of `240037`) causes invalid-color overlay crowding branding text. Always validate 6 hex chars exactly.
2. **Splash + terminal overlay:** when `wallpaper` is set, Limine still renders terminal overlay on top. Pick `term_foreground` carefully: cyan `#03EDF9` or white `#FFFFFF` work on dark art; hot pink `#FF7EDB` usually fails.
3. **Canonical source is cachyos-blackshield:** editing `/boot/limine.conf` directly won't survive reboot. Use handoff.

### Verified Synthwave '84 Config
```
term_palette: 240037;FE4450;72F1B8;F3E70F;8F00FF;FF00FF;03EDF9;FF7EDB
term_background: 240037
term_foreground: 03EDF9
interface_branding_colour: FFFFFF
interface_help_colour: B084EB
wallpaper: boot():/limine-splash-synthwave.png
```

## Fish Function Library

Single-file-per-function in `~/.config/fish/functions/`. Handoff syncs from `cachyos-blackshield/configs/fish/functions/`.

**Edit workflow:** edit `.fish` in cachyos-blackshield, run handoff script. Never edit only in `~/.config/fish/functions/` — reboot clobbers it.

### Fish Quirks (this machine)
1. `alias ~='cd ~'` crashes on source — `~` conflicts with expansion token. Remove it.
2. `__fish_config_dir` is read-only in modern fish; use `XDG_CONFIG_HOME` instead.
3. Function names must be valid identifier tokens. `function ~` fails at source.
4. functions must be self-contained; don't assume another function file was sourced first.

## Handoff Script

Path: `~/Projects/active/handoff-post-reboot.sh`
Run: `sudo -E bash ~/Projects/active/handoff-post-reboot.sh` (`-E` preserves `$HOME=/home/synth`; plain `sudo bash` expands `~` to `/root`)

Sections: CPU governor, zram, Limine, Plymouth+plasmalogin, Fish functions, user services.
