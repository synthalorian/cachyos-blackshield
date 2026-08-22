# cachyos-synthwave84 🎹🦞

![Status](https://img.shields.io/badge/status-active-brightgreen)
![CachyOS](https://img.shields.io/badge/distro-CachyOS_Arch-yellow)
![License](https://img.shields.io/badge/license-MIT-green)

**Fresh CachyOS install → the full synthclaw grid, one script.**
**Theme: BLACKSHIELD MERCENARY** — black steel, blood-red cross potent,
EB Garamond type. The wave went to war.

Made by synth with synthclaw.

Captures everything: KDE Plasma desktop, terminals, fish shell, neovim
(blackshield colorscheme, lazy.nvim), the entire 111-repo ~/Projects library,
Hermes Agent + synthclaw identity + 240 skills, llama-swap local model stack,
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
| 2 configs | fish, alacritty, kitty, fastfetch, nvim, KDE (kwinrc/kdeglobals/plasma/panels/themes), Obsidian-Red icon theme + Vimix-cursors, EB Garamond + Symbols Nerd Font, plasmoids, wallpapers, git, chsh→fish, Ghostty + Fish wrappers + KWin effects |
| 2a browsers | Firefox userChrome/userContent BLACKSHIELD theme per profile (+ headless profile seed), Chromium unpacked theme staged at ~/.config/chromium-themes (one manual load step — docs/BROWSERS.md) |
| 2b system | (sudo) Plymouth blackshield boot splash + initramfs rebuild, Plasma Login Manager: config, greeter kdeglobals (EB Garamond), login wallpaper |
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
- **Medieval cursor alternates** — `configs/icons/candidates/hand-of-evil` ships prebuilt (Dungeon Keeper II set); switch via System Settings → Cursors. Skyrim-style cursors available from AUR as `xcursor-skyrim`.

## Repo map

```
configs/          fish, alacritty, kitty, fastfetch, nvim, kde, git,
                  browsers (firefox userChrome/userContent + chromium theme,
                            blackshield NTP art),
                  system (plasmalogin.conf, greeter kdeglobals, plymouthd.conf,
                          zram-2x.conf, tmpfiles.d-cpu-governor.conf),
                  limine (boot menu branding + splash text + edid/ SKG 2560x1080 override),
                  plymouth (blackshield boot splash theme),
                  llama-swap, hermes (SOUL/memories/scripts/cron), opencode, systemd,
                  icons (Obsidian-Red icon theme + Vimix-cursors),
                  fonts (EB Garamond + Symbols Nerd Font),
                  plasmoids (AndromedaLauncher, KdeControlStation)
wallpapers/       ~/Pictures/blackshield (kiteshield + cross potent set)
                  + blackshield-lock-login (lock/login screen set, incl. taskbar icon)
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

## The Blackshield conversion

- Palette: VOID `#070709` / IRON `#101014` / STEEL `#26262E` blacks, BLOOD `#C1121F` + EMBER `#E5383B` reds, PARCHMENT `#D8D3C8` text, BRASS/OLIVE/STEELBLUE/PLUM/VERDIGRIS accents
- Limine: menu branding = `==[ BLACKSHIELD // THE SHIELD HOLDS ]==`; splash burn-in on the kiteshield art
- Plymouth blackshield retained; login greeter uses EB Garamond + blackshield lock/login wallpaper
- CPU governor pinned to `performance` via `/etc/tmpfiles.d/cpu-governor.conf`
- zram 2x swap in `/etc/systemd/zram-generator.conf.d/99-synthswap.conf`
- Ghostty synced to void-black `#070709` + full Blackshield palette
- Cursor: Synthwave set hue-shifted purple→blood (`#C1121F` family), renamed Blackshield
- KWin effects: wobbly windows, Flip Switch tab switcher, Explode on close

The shield holds. 🎹🦞🌆

---

## ☕ Support the Developer

If this project saved you time, solved a problem, or just made your day a little more neon, you can fuel the next one:

[![Buy Me A Coffee](https://cdn.buymeacoffee.com/buttons/v2/default-yellow.png)](https://buymeacoffee.com/synthalorian)
