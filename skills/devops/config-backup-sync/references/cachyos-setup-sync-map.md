# cachyos-setup Sync Map

Repo: `~/Projects/active/cachyos-setup` (private, `synthalorian/cachyos-setup`).
Pairwise repo↔live mapping. Byte-compare each pair; sync only semantic diffs.

## Terminals & Shell

| Repo path | Live source |
|---|---|
| configs/fish/config.fish | ~/.config/fish/config.fish |
| configs/alacritty/alacritty.toml | ~/.config/alacritty/alacritty.toml |
| configs/kitty/kitty.conf | ~/.config/kitty/kitty.conf |
| configs/fastfetch/{config.jsonc,cross.txt,sun.txt,synth-arrow.txt} | ~/.config/fastfetch/ (same names) |
| configs/git/gitconfig | ~/.gitconfig |

## KDE

| Repo path | Live source |
|---|---|
| configs/kde/kdeglobals | ~/.config/kdeglobals |
| configs/kde/kwinrc | ~/.config/kwinrc |
| configs/kde/kwinrulesrc | ~/.config/kwinrulesrc |
| configs/kde/plasmarc | ~/.config/plasmarc |
| configs/kde/kglobalshortcutsrc | ~/.config/kglobalshortcutsrc |
| configs/kde/dolphinrc | ~/.config/dolphinrc |
| configs/kde/kcminputrc | ~/.config/kcminputrc |
| configs/kde/plasma-org.kde.plasma.desktop-appletsrc | ~/.config/plasma-org.kde.plasma.desktop-appletsrc |
| configs/kde/kactivitymanagerdrc | ~/.config/kactivitymanagerdrc |
| configs/kde/baloofilerc | ~/.config/baloofilerc |
| configs/kde/kscreenlockerrc | ~/.config/kscreenlockerrc (lock screen wallpaper; added Jul 2026) |
| configs/system/plasmalogin.conf | /etc/plasmalogin.conf (world-readable root file, plain cp works; added Jul 2026. Login wallpaper PNG lives at /var/lib/plasmalogin/wallpapers/ — repo copy is under wallpapers/synthwave84-lock-login/) |
| configs/limine/limine.conf | /boot/limine.conf (needs sudo to read; includes drm.edid_firmware cmdline) |
| configs/limine/edid/*.bin | /usr/lib/firmware/edid/ (EDID firmware override, SKG 2560x1080; deployed by handoff script; added Aug 2026) |
| handoff-post-reboot.sh | ~/Projects/active/handoff-post-reboot.sh (post-reboot finisher; tracked in repo since Aug 2026) |
| configs/kde/gtkrc | ~/.config/gtkrc (SKIP: timestamp churn) |
| configs/kde/gtkrc-2.0 | ~/.config/gtkrc-2.0 (SKIP: timestamp churn) |
| configs/kde/gtkrc-2.0-home | ~/.gtkrc-2.0 |
| configs/kde/gtk-3.0-settings.ini | ~/.config/gtk-3.0/settings.ini |
| configs/kde/gtk-4.0-settings.ini | ~/.config/gtk-4.0/settings.ini |
| configs/kde/color-schemes/*.colors | ~/.local/share/color-schemes/ (same names) |
| configs/kde/desktoptheme/, configs/plasmoids/ | vendor trees — only re-copy on theme/plasmoid upgrade |

## AI Stack

| Repo path | Live source |
|---|---|
| configs/hermes/SOUL.md | ~/.hermes/SOUL.md |
| configs/hermes/memories/{MEMORY.md,USER.md} | ~/.hermes/memories/ (same names) |
| configs/hermes/cron-jobs.json | ~/.hermes/cron/jobs.json (SKIP counters; sync only on job-definition change) |
| configs/hermes/scripts/*.sh | ~/.hermes/scripts/ (same names) |
| configs/hermes/config.example.yaml | ~/.hermes/config.yaml — SANITIZE keys to `<FILL_IN:*>` before committing |
| configs/llama-swap/* | ~/.config/llama-swap/ (config.yaml + template-qwen36-synthclaw.jinja; moved from ~/llama.cpp/llama-swap/ in Jul 2026; install.sh already targets new path; skip live-only config.yaml.bak*) |
| configs/opencode/* | ~/.config/opencode/ (opencode.jsonc, oh-my-openagent.json, tui.json, AGENTS.md, agents/, themes/) |
| configs/systemd/user/*.service | ~/.config/systemd/user/ (same names) |
| configs/nvim/ | ~/.config/nvim/ — use `diff -rq` for the whole tree |

## Manifests

```bash
# packages (explicit installs)
pacman -Qeq > manifest/packages.txt

# projects coverage check (cachyos-setup itself legitimately absent)
comm -13 <(cut -f2 manifest/projects.tsv | sort) \
         <(ls -d ~/Projects/*/*/ | xargs -n1 basename | sort)
```

## Notes

- The repo also tracks `skills/` (mirror of ~/.hermes/skills) and `wallpapers/` — re-sync on skill changes or new wallpaper drops.
- Homebrew (`/home/linuxbrew/.linuxbrew`) and kimi-code (`~/.kimi-code/bin`) are manual extras — documented in README, not scripted.
- Never commit: ~/.hermes/auth.json, OAuth state, GGUF weights, session DBs.
