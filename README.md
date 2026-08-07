# cachyos-synthwave84 🎹🦞

![Status](https://img.shields.io/badge/status-active-brightgreen)
![CachyOS](https://img.shields.io/badge/distro-CachyOS_Arch-yellow)
![License](https://img.shields.io/badge/license-MIT-green)

**Fresh CachyOS install → the full synthclaw grid, one script.**

Made by synth with synthclaw.

Captures everything: KDE Plasma desktop, terminals, fish shell, neovim
(synthwave '84, lazy.nvim), the entire 111-repo ~/Projects library, Hermes
Agent + synthclaw identity + 240 skills, llama-swap local model stack,
OpenCode config, and systemd user services.

## One-liner (fresh CachyOS box)

```bash
sudo pacman -S --needed --noconfirm git github-cli && gh auth login \
  && gh repo clone synthalorian/cachyos-synthwave84 \
  && cd cachyos-synthwave84 && ./install.sh
```

## What install.sh does

| Phase | What happens |
|---|---|
| 1 packages | Full `pacman -Syu`, then every explicit package from `manifest/packages.txt` |
| 2 configs | fish, alacritty, kitty, fastfetch, nvim, KDE (kwinrc/kdeglobals/plasma/panels/themes), Synthwave cursor + candy-icons, 3270 Nerd Font, plasmoids, wallpapers, git, chsh→fish, Ghostty + Fish wrappers + KWin effects |
| 2a browsers | Firefox userChrome/userContent synthwave '84 theme per profile (+ headless profile seed), Chromium unpacked theme staged at ~/.config/chromium-themes (one manual load step — docs/BROWSERS.md) |
| 2b system | (sudo) Plymouth synthwave84 boot splash + initramfs rebuild, Plasma Login Manager: config, greeter kdeglobals (3270 Nerd Font), login wallpaper |
| 2c tuning | CPU governor → performance on boot, zram 2x swap, Limine boot menu branding + boot splash text overlay, Ghostty theme sync |
| 3 projects | Clones all 111 repos into `~/Projects/{active,archived,backburner,finished,forks,faith}` (8 parallel, skips existing) |
| 4 ai | Hermes Agent install + SOUL.md + memories + skills + config template, llama-swap binary + config, OpenCode config |
| 5 services | systemd user units: llama-swap, hermes-gateway, openclaw-gateway (enabled, not started) |
| 6 nvim | Headless `Lazy! sync` — all plugins + treesitter parsers |

Run a single phase: `./install.sh configs` (or packages/system/projects/ai/services/nvim).

## After the script

1. **Secrets** — `docs/SECRETS.md` (`hermes login nous`, `gh auth login`, `<FILL_IN>` placeholders)
2. **Models** — `docs/MODELS.md` (~19GB GGUFs via `hf download`)
3. Log out/in (fish + KDE), then `systemctl --user start llama-swap hermes-gateway openclaw-gateway`
4. After first reboot: `sudo -E bash handoff-post-reboot.sh` from the repo dir (boot/login/shell finisher)

## Manual extras (not scripted)

- **Homebrew** — installed at `/home/linuxbrew/.linuxbrew` (fish shellenv line already in `configs/fish/config.fish`). Install: `/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"`. No formulae currently.
- **kimi-code CLI** — `~/.kimi-code/bin` (PATH line in fish config). Reinstall from vendor installer.

## Repo map

```
configs/          fish, alacritty, kitty, fastfetch, nvim, kde, git,
                  browsers (firefox userChrome/userContent + chromium theme,
                            striped-sun NTP art),
                  system (plasmalogin.conf, greeter kdeglobals, plymouthd.conf,
                          zram-2x.conf, tmpfiles.d-cpu-governor.conf),
                  limine (boot menu branding + splash text + edid/ SKG 2560x1080 override),
                  plymouth (synthwave84 boot splash theme),
                  llama-swap, hermes (SOUL/memories/scripts/cron), opencode, systemd,
                  icons (Synthwave cursor, candy-icons), fonts (3270 Nerd Font),
                  plasmoids (AndromedaLauncher, KdeControlStation)
wallpapers/       ~/Pictures/synthwave + synth.png (Testarossa/DeLorean set)
                  + synthwave84-lock-login (lock/login screen set, incl. taskbar icons)
skills/           all 240 Hermes skills (~/.hermes/skills)
manifest/         packages.txt (292 pacman-explicit), projects.tsv (111 repos)
docs/             MODELS.md (weights), SECRETS.md (what to fill in), BROWSERS.md (browser themes)
install.sh        the bootstrap
handoff-post-reboot.sh  post-reboot finisher (limine+EDID, plymouth, plasmalogin, fish, services)
```

## Updating this backup

Scan → copy → commit in one flow (don't let live configs drift):

```bash
# example: nvim config changed
cp -r ~/.config/nvim/. configs/nvim/
git add -A && git commit -m "update nvim config" && git push
```

Never commit: API keys, `~/.hermes/auth.json`, `~/.openclaw/openclaw.json`,
GGUF weights, session DBs. See `docs/SECRETS.md`.

## Tonight's additions

- Limine: menu branding = `This is the wave. synthwave '84`; boot splash burn-in adds readable `THIS IS THE WAVE.` line
- Plymouth synthwave84 retained; login greeter uses 3270 Nerd Font + synthwave84 v2 wallpaper
- CPU governor pinned to `performance` via `/etc/tmpfiles.d/cpu-governor.conf`
- zram 2x swap in `/etc/systemd/zram-generator.conf.d/99-synthswap.conf`
- Ghostty synced to deep purple `#240037` + full synthwave palette
- Fish wrappers: `openamp`, `open-psalm`, `voidengine` + build aliases
- KWin effects: wobbly windows, Flip Switch tab switcher, Explode on close

This is the wave. 🎹🦞🌆
