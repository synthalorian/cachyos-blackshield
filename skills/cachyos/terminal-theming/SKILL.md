---
name: terminal-theming
description: >-
  Linux terminal theming and ricing: font installation (user-local, no sudo),
  fastfetch config (schema pitfalls, custom ASCII logos, color maps),
  Alacritty themes, Ghostty themes, fish shell greetings. synthwave '84 palette
  conventions. Triggers: terminal theme, alacritty, ghostty, kitty, fastfetch,
  nerd font, font install, fish greeting, ricing, terminal colors, ascii logo,
  prompt.
version: 1.0.0
tags: [linux, terminal, theming, fonts, fastfetch, alacritty, fish, synthwave]
---

# Terminal Theming

Class-level playbook for decking out Linux terminals on synth's system (CachyOS/KDE, but patterns are portable). Complements the `cachyos` skill (protected) — KDE/Plasma-level theming lives there; terminal-level lives here.

## Fonts

- Install user fonts to `~/.local/share/fonts/<family>/`, then `fc-cache -f ~/.local/share/fonts`. NO sudo needed — never reach for pacman just for fonts.
- **System default font is 3270 Nerd Font.** synth tried Orbitron as the default on 2026-08-11 and HATED it (especially in Ghostty) — fully reverted the same day. Do not re-suggest Orbitron or proportional/display fonts for terminals. Orbitron files remain at `~/.local/share/fonts/Orbitron/` + Symbols NF at `~/.local/share/fonts/NerdFontsSymbols/` (both unreferenced by any config; fontconfig conf was removed).
- **Lesson: `plasmashell --replace` from an agent terminal can SIGABRT and silently not replace the shell** (running instance keeps its old start time). Restart Plasma via `systemctl --user restart plasma-plasmashell.service` and verify with `ps -o lstart= -p $(pgrep -x plasmashell)`.
- **synth keeps curated font files locally** — e.g. `~/Documents/3270/` holds the full 3270 Nerd Font family (9 faces). CHECK ~/Documents (and ~/Downloads) for local font assets BEFORE installing from pacman/AUR. He prefers his local copies.
- **Full system-wide font swaps touch more stores than obvious** — kdeglobals has font keys in BOTH `[General]` (incl. a legacy `activeFont` straggler) AND `[WM]`, plus GTK3/4, xsettingsd, Trolltech.conf, and dconf via gsettings. Complete checklist + Qt font-string format + verification pitfalls: `references/system-wide-font-swap-checklist.md`.
- After install, verify exact family names with `fc-list | grep -i <name>`. Patched Nerd Font families expose variants like `3270 Nerd Font Mono`, `... Propo`, `... Cond` — the base family + style `Regular` resolves to the standard face.
- Alacritty font block: `[font.normal] family = "3270 Nerd Font Mono", style = "Regular"`.

## 3270 Nerd Font width-metadata bug (fixed 2026-08-11)

Every face in the patched 3270 family — including Condensed and SemiCondensed — reports `width=100` (Normal) in its metadata (verify: `fc-query --format '%{width}' file.ttf`). With widths tied, fontconfig breaks the tie alphabetically and resolves ANY bare "3270 Nerd Font*" request to the **Condensed** face. Symptom: every terminal (Ghostty, kitty, Alacritty) renders squished condensed glyphs despite configs naming the right family; `fc-match '3270 Nerd Font'` returns `3270NerdFont-Condensed.ttf`. Fix deployed: all Cond/SemiCond faces exiled from BOTH `~/.local/share/fonts/3270/` and `/usr/local/share/fonts/3270/` to `~/Documents/3270/unused-widths/` (delete the /usr/local duplicates too — they re-corrupt resolution), `fc-cache -f`, then all terminal configs use **`3270 Nerd Font Mono`** (proper 2-cell nerd glyphs, matches kdeglobals `fixed`). If 3270 ever looks wrong again, first check `fc-match '3270 Nerd Font Mono'` returns the Regular file.

## Ghostty font debugging (the empirical route)

- Ghostty logs the RESOLVED face on startup: launch `ghostty` from a shell and read stderr for `info(font_shared_grid_set): font regular: <face>` — this is ground truth; `+show-config` only proves the config PARSED, and `fc-match` only proves what fontconfig would do, not what Ghostty picked.
- Fallback behavior: if family resolution fails, Ghostty silently renders its bundled **JetBrainsMono Nerd Font** — fastfetch's `TERMFONT` line exposes it instantly (it queries the live terminal).
- Quote digit-leading families in config.ghostty: `font-family = "3270 Nerd Font Mono"`.
- fastfetch TERMFONT probe only works in an interactive window — `ghostty -e sh -c 'fastfetch > file'` breaks detection (tree-walk lands on the launcher, e.g. `timeout`/`hermes_cli.main`).
- Ghostty windows join the running single instance via D-Bus — config edits need a FULL process kill (`pkill -x ghostty`), not just closing windows.
- Agent-side screenshot verification is unavailable on this box: portal Screenshot is disabled (see memory), computer_use capture returns 0x0 on Wayland. Use the Ghostty log line instead.
- **fastfetch TERMFONT lies for Ghostty on this box:** fastfetch 2.67 detects Ghostty's font by parsing `~/.config/ghostty/config` ONLY (proven via `strings /usr/bin/fastfetch | grep ghostty` → `ghostty/config`), while the Arch build reads `config.ghostty`. With no `config` file, fastfetch silently reports the bundled default (**JetBrainsMono Nerd Font 12pt**) even when Ghostty is actually rendering the configured font. Fix: `ln -s config.ghostty ~/.config/ghostty/config` (deployed 2026-08-11). Trust Ghostty's stderr `font_shared_grid_set` line over fastfetch, always.
- fastfetch's termfont module also refuses to run without a real tty — cannot be verified headlessly (env spoofing insufficient); only in an interactive Ghostty window.

## Fastfetch

- Config: `~/.config/fastfetch/config.jsonc`. Validate by simply running `fastfetch` — schema errors exit non-zero (221) with a clear rename message.
- **PITFALL (fastfetch >= 2.66):** `display.bar.charElapsed` / `charTotal` renamed to `display.bar.char.elapsed` / `display.bar.char.total`. Old keys hard-fail. Expect similar renames after upgrades — read the error, it names the new key.
- Custom ASCII logos: `logo.type: "file"`, `logo.source` points to a text file. Prefix each line with `$1`..`$9` to map into `logo.color` entries (hex like `"#FE4450"` accepted). `logo.padding` takes `{top, left, right}`.
- **PITFALL (braille-blank padding):** never pad logo lines with ⠀ (U+2800 braille blank). Its cell width is ambiguous across fastfetch's width math, wcwidth, kitty, and the font (condensed Nerd Fonts especially), so the info column can drift INTO the art — user sees "text interrupting the logo" even though the raw file looks clean. Fix: replace all ⠀ with plain spaces and trim trailing padding (fastfetch auto-pads short lines to the widest line, so no manual ljust needed). Detect: `grep -nP '\x{2800}' logo.txt`.
- **Text column is global:** info starts at `padding.left + widest visible logo line + padding.right` for EVERY row. One wide swoosh row sets the offset for all rows; "text crowds the art" = raise `padding.right` or narrow the widest row.
- **Verify layout deterministically, don't eyeball:** run `scripts/fastfetch-layout-check.py` (runs `fastfetch --pipe false`, strips ANSI, prints per-row art_end/textcol/gap, min gap, longest line; exits 1 if gap < threshold). Use it after any logo/padding edit.
- **Wrap risk:** long module outputs (theme/icons/font list both [Qt] and [GTK] variants; mem/swap/disk with bars + `percent.type: 3`) reach ~100+ cols and soft-wrap into the logo on narrow windows. Terminal copy usually joins soft-wraps, so a pasted transcript looks clean while the user's screen shows collision. Shrink `display.bar.width` first; theme/icons/font duplication is NOT config-trimmable.
- Modules that silently omit when undetectable: `host` (empty on some boards), `terminalfont` (undetectable in nested/headless terms), `battery` (desktops). Don't chase these as bugs.
- Use ▪ (small square) for bar/logo pixel glyphs, NOT █ — ▪ renders with natural gaps; █ blobs into unreadable blocks. Same lesson as OpenShark TUI pixel font.

## Fish function library (versioned)

**Source of truth:** `~/Projects/active/cachyos-synthwave84/configs/fish/functions/`  
**Live target:** `~/.config/fish/functions/`  
**Sync:** `handoff-post-reboot.sh` copies every `.fish` file from source → target on each reboot/polish run.

Rule: one function per file, flat filenames only (no subdirs). Each file must be independently sourceable.

### Owned function inventory

| File | Function | Purpose |
|---|---|---|
| `conflicts.fish` | `conflicts` | Wayland env fixes for kitty/ghostty/kwin; runs on shell startup |
| `aliases.fish` | aliases block | 30+ synth-aligned shortcuts: git, nav, Arch, Flutter, monitoring. `alias ~='cd ~'` removed — fish expands `~` natively, so defining it causes startup errors. |
| `activate.fish` | `activate` | Auto-activate nearest stagehand/venv cwd→parents; `--conda`, `--check` |
| `ginit.fish` | `ginit` | `ginit [--rust\|--node\|--flutter\|--unity\|--python\|--all] [--remote <url>]` + smart commit/push |
| `this-is-the-wave.fish` | `this-is-the-wave` + `track` | 5-track Sonic Pi EP launcher — numeric or fuzzy name. Dispatches to `sonic-pi-tui`, `sonic-pi-remote-cli`, or `sonic-pi` in that priority order. |
| `ls.fish` | `ls` | wraps `eza` with git/icon awareness; falls back to `/bin/ls` |
| `top.fish` | `top` | Picks `bottom` → `btop` → `htop` → `top`; `--btop`/`--bottom`/`--htop` overrides |
| `tmux-launch.fish` | `tmux-launch` | Attach/create named session; `--here` = cwd, `--kill` |
| `yt.fish` | `yt` | yt-dlp wrapper: `--audio`/`--playlist`/`--subs`/`--4k`/`--live`/`--list`; saved to `~/Videos/yt` |
| `zoxide.fish` | `z` | smart jump via zoxide; fallback autojump |

### Fish shell syntax pitfalls

- **`__fish_config_dir` is read-only** in modern fish. Conditionally setting it throws `set: Tried to change the read-only variable '__fish_config_dir'`. Fix: set `XDG_CONFIG_HOME` instead.
- **No `do` keyword** in fish for-loops. Use `for x in ...; ...; end`.
- **No `${var}` interpolation** — use `"$var"` inside strings. `${arg}` causes parser errors.
- **Function name restrictions:** paths containing `/` or names like `~` are rejected. Only source files from inside `~/.config/fish/functions/` so `functions <name>` can find them.
- **Aliases can’t shadow paths with `/`.** Defining `alias ~='cd ~'` throws `Invalid function name` even though `cd ~` works natively. Remove such aliases.
- **`sudo install` clobbers ownership.** When a root script deploys into `~/.config/fish/functions/`, `ls -la` shows `root root` — that blocks non-root sourcing. Run `sudo chown -R synth:synth ~/.config/fish/functions` after any handoff that uses `sudo install -m 644` into the user's home.
- **Bad fish files poison session startup.** Syntax errors at source time surface in `fish_greeting` and `functions <name>` output. Verify new functions with `fish -l -c 'source <file>'` before committing. When debugging across multiple files: `for f in ~/.config/fish/functions/*.fish; fish -l -c "source $f" 2>&1 | head -2; end`.

## Fish greeting

```fish
function fish_greeting
    if status is-interactive
        fastfetch
    end
end
```
Put in `~/.config/fish/config.fish`. CachyOS sources `/usr/share/cachyos-fish-config/cachyos-config.fish` first — a local `fish_greeting` override wins.

**PITFALL — duplicate PATH entries:** `/usr/share/cachyos-fish-config/cachyos-config.fish` already adds `~/.local/bin`, `~/.cargo/bin`, and common paths via `fish_add_path`. Before appending the same directories in `config.fish`, audit what’s already exported. Duplicates bloat `fish_user_paths` and make PATH audits noisy. Unique additions like `kimi-code`, `opencode`, Homebrew, or OpenClaw completion belong in `config.fish`; common ones do not.

## synthwave '84 palette (terminal)

bg `#240037`, fg `#FF7EDB`, cursor `#F3E70F`, selection `#8F00FF`, magenta `#FF00FF`. For the 16-color set, green `#72F1B8` and cyan `#03EDF9` come from the actual Synthwave '84 VSCode theme — more authentic than generic neon. Red `#FE4450` doubles as the Templar-cross red.

## Kitty

- Config: `~/.config/kitty/kitty.conf`. Alacritty→kitty mapping: `window_padding_width 12`, `background_opacity 0.92`, `hide_window_decorations yes`, `scrollback_lines 10000`, `wheel_scroll_multiplier 3.0`. Font sizing binds: `map ctrl+equal change_font_size all +1.0` / `minus -1.0` / `0 all 0`, `map f11 toggle_fullscreen`.
- kitty has NO separate dim-palette, vi-mode cursor, or "start maximized" option (use `remember_window_size yes` or a KDE window rule for maximized).
- Verify config WITHOUT opening a window: `kitty +runpy` with `from kitty.config import load_config; opts = load_config(config_dir + '/kitty.conf', accumulate_bad_lines=bad)`. `load_config` takes PATHS (not StringIO), `defaults` is an Options OBJECT (not callable, and can't be deepcopied — SingleKey isn't picklable), and there is no `opts.keymap` attr. `--debug-config` does not exist as a flag.
- Extras kitty gets over alacritty: powerline tab bar (`tab_bar_style powerline`, `tab_powerline_style slanted`), split border colors, `cursor_blink_interval`, `url_color`. synthwave tab chrome: active fg #240037 / bg #FF7EDB, inactive fg #FF7EDB / bg #4B0080.

## KDE default terminal

After installing/configuring Ghostty, set it as the default handler so Konsole/Yakuake/etc. defer to it:
```bash
kwriteconfig6 --file ~/.config/kdeglobals --group General --key TerminalApplication com.mitchellh.ghostty.desktop
```
This is a per-user setting; no root required.

## KDE terminal ref migration

When switching default terminals, also fix app-specific launcher refs:
- Kate external tools: edit `~/.config/kate/externaltools/*.ini` and change `executable=konsole` → `executable=ghostty`.
- Desktop files under `~/.local/share/applications/`: search for stale `Exec=` lines pointing to old terminals if needed.

## KDE palette polish (match Ghostty)

To make Plasma visually match Ghostty exactly, edit `~/.config/kdeglobals` directly:
- `[Colors:Button|Selection|Tooltip|View|Window]` → set `BackgroundNormal`/`BackgroundAlternate` to Ghostty bg, `ForegroundNormal` to Ghostty fg, `DecorationFocus/Hover` to Ghostty accent.
- `[WM]` → `activeBackground`/`inactiveBackground`, `activeForeground`, `inactiveBlend`.

`plasmarc` holds the LookAndFeel name; it does not carry the live color values. Don’t conflate them.

For deeper reuse, create a matching local scheme file under `~/.local/share/color-schemes/<name>.colors` with the same RGB groups, then it shows up in System Settings → Colors.

When changing Alacritty background, remember to update every dependent slot as documented below.

## Synthwave '84 deep-purple sync: Ghostty → KDE

If the user says Ghostty/KDE “doesn’t look quite like kitty,” align everything to the deep-purple baseline `#240037`.

1. Ghostty `~/.config/ghostty/config.ghostty`:
   - `background = #240037`
   - `selection-foreground = #240037`
2. KDE `kwinrc` window borders:
   - `ActiveBackground=#240037`
   - `ActiveForeground=#FF7EDB`
   - `InactiveBackground=#140535`
   - `InactiveForeground=#B57EDB`
3. KDE `kdeglobals` baseline:
   - `[Colors:*] BackgroundNormal=#240037`
   - `[General] background=#240037`, `foreground=#FF7EDB`
   - `accentColor=#8F00FF`, `SelectionBackground=#8F00FF`, `SelectionForeground=#240037`
4. Local scheme file `~/.local/share/color-schemes/SweetAmbarBlue.colors`: set `BackgroundNormal` to RGB `36,0,55` / `#240037`. Keep `Colors:Selection BackgroundNormal=143,0,255` / `#8F00FF`.
5. Refresh: `qdbus org.kde.ScreenScanner /Scanner org.kde.ScreenScanner.refresh`
6. To restart the shell from an agent terminal, use `systemctl --user restart plasma-plasmashell.service`. Do NOT use `plasmashell --replace` from a non-session shell — observed SIGABRT (exit -6) mid-handshake where the old PID kept running and NOTHING was replaced. Always verify the restart actually happened: `ps -o lstart= -p $(pgrep -x plasmashell)` and compare the start time against your config edits — `pgrep` alone proves nothing. Full logout/login is the last resort.

## Ghostty

- Config path: `~/.config/ghostty/config.ghostty`. File must be named `config.ghostty`; Ghostty 1.3+ ignores `config`.
- Verified synthwave mapping against Alacritty/Kitty: `font-family = "3270 Nerd Font Mono"` (quoted — digit-leading family), `font-size = 11` (user-confirmed 2026-08-11; 12pt looked chunky with the Regular-width face vs the Condensed he'd been on), `window-padding-x/y = 12`, `background-opacity = 0.92`, `window-decoration = false`, `confirm-close-surface = false`, `scrollback-limit = 10000`, `mouse-scroll-multiplier = 3`, `cursor-color = #F3E70F`, `cursor-text = #0D0221`, `cursor-style = block`, `cursor-style-blink = true`, `selection-background = #8F00FF`, `selection-foreground = #0D0221`, `background = #0D0221`, `foreground = #FF7EDB`.
- Synthwave '84 baseline is anchored to deep purple `#240037`. If `background` drifts to `#0D0221`, it breaks palette unity with Kitty/OpenShark/KDE. Re-sync with `references/synthwave84-deep-purple-drift.md`.
- Default keybinds already cover `ctrl+==increase_font_size:1`, `ctrl+-=decrease_font_size:1`, `ctrl+0=reset_font_size`. If custom binds are added, omit spaces around `=` in `keybind = ...` lines or they validate as `InvalidFormat`.
- Validation: `ghostty +validate-config`. Unrecognized keys are ignored at runtime, but `+validate-config` reports them. `ghostty +show-config --default --docs` is the authoritative key reference; `src/config/Config.zig` is the source of truth for typos/renames.
- PITFALL: Ghostty does not support separate bold/italic font family keys (`bold-font-family`, etc.). Use `font-style-bold = false` if you need to disable synthetic bold/italic; otherwise Ghostty falls back to the regular font family automatically.
- PITFALL: `selection-color` is not a valid Ghostty key; use `selection-foreground` and `selection-background`.
- PITFALL: `cursor-color` takes one value only; cursor text color is `cursor-text`, not a second argument.
- PITFALL: `hide-window-decorations`, `confirm-close`, `scrollback-lines`, `remember-window-size`, `link-color`, `cursor-blink-interval`, and `cursor-text-color` are all invalid in Ghostty 1.3.x. Use `window-decoration`, `confirm-close-surface`, `scrollback-limit`, `cursor-style-blink`, and `cursor-text` instead.

## Templates (verified 2026-07-22, CachyOS + fastfetch 2.66)

- `templates/alacritty-synthwave84.toml` — complete Alacritty theme on the palette below, 3270 Nerd Font, borderless/padded, font-size bindings.
- `templates/ghostty-synthwave84.ghostty` — complete Ghostty theme mirrored from Alacritty/Kitty.

## Alacritty pitfall: palette drift

When changing Alacritty background color, update every background-referencing color slot: `colors.primary.background`, `colors.cursor.text`, `colors.vi_mode_cursor.text`, `colors.selection.text`, `colors.search.matches.foreground`, `colors.search.focused_match.foreground`, `colors.footer_bar.foreground`, `colors.normal.black`, and `colors.dim.black`. Changing only `primary.background` leaves vi/search/selection contrast broken. Verify by actually using selection, search (`/`), and vi-mode cursor, not just passive viewing.

## Scripts

- `scripts/fastfetch-layout-check.py` — runs fastfetch headless, strips ANSI, prints per-row art/text columns + min gap + longest line; exits 1 if the logo moat is below threshold. Run after any logo or padding change.
- `scripts/font-specimen.py` — renders a specimen PNG (title/pangram/bold/nerd-glyph row + resolved file paths) from the ACTUAL installed fonts via fc-match. Use for visual proof after font installs/swaps when desktop screenshots aren't reachable (Wayland). `--family`, `--symbols-family`, `--out` args.
