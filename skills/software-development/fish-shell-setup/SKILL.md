---
name: fish-shell-setup
description: 'Fish shell setup on CachyOS.'
tags: [linux, cachyos, fish, shell, dotfiles]
---

# Fish Shell Setup

## Architecture

Preferred layout for a first-class fish setup:

```
~/.config/fish/functions/
├── conflicts.fish       # env/Wayland/terminal conflict resolution
├── aliases.fish         # user aliases
├── <tool>.fish          # one function per file
cachyos-blackshield repo/
└── configs/fish/functions/
    ├── conflicts.fish    # canonical copy, versioned
    ├── aliases.fish
    └── <tool>.fish
handoff-post-reboot.sh    # install -m 644 repo → ~/.config/fish/functions
```

Rule: do NOT put function definitions in `config.fish`. Each function lives in its own file under `functions/`.
The canonical copies are versioned in `cachyos-blackshield`; `handoff-post-reboot.sh` redeploys them after every reboot.

### Versioning function files

```bash
cp ~/.config/fish/functions/<name>.fish ~/Projects/active/cachyos-blackshield/configs/fish/functions/
cd ~/Projects/active/cachyos-blackshield && git add configs/fish/functions/<name>.fish && git commit && git push
```

Update the handoff loop when adding new files:

```bash
for f in conflicts aliases activate ginit this-is-the-wave ls top yt tmux-launch zoxide llama-toggle; do
```

## Fish-specific gotchas

- `__fish_config_dir` is **read-only** in modern fish. Use `XDG_CONFIG_HOME` instead: `set -q XDG_CONFIG_HOME; or set -gx XDG_CONFIG_HOME ~/.config`.
- `alias ~='cd ~'` is unnecessary and breaks sourcing — fish expands `~` natively.
- Don't rely on functions from one file being visible inside another without sourcing. In non-login shells, function files load on demand; cross-sourcing creates ordering bugs.
- In `for tok in (...)`, use `string split` on explicit delimiters instead of bare `echo`:
  ```fish
  for tok in (string split ' ' "$cmdline")
  ```
  Without this, a multi-token cmdline collapses to one element and breaks flag parsing.

## Verification pattern

After editing any fish function, reload and verify in a non-login shell:

```bash
fish -c 'functions foo'              # should say DEFINED
fish -c 'foo --list'                 # run its self-check path in isolation
```

Use `fish -l` for login-shell flavor tests; `fish` alone is non-login and reflects production sourcing behavior.

## Common function class: process toggle

Pattern used by `llama-toggle`:

- enum all known PIDs by matching process name
- parse flags: `--suspend` / `--resume` / `--kill` / `--list` / `--stop-model <name>`
- `string split + for tok` walk to pull `--port` and `--model` from `/proc/$pid/cmdline`
- `kill -STOP` / `kill -CONT` for suspend/resume without killing
- `--stop-model` does substring match against cmdline, then `kill`

## Common function class: yt-dlp wrapper

Pattern used by `yt`:

- fixed output dir (`$HOME/Videos/yt`)
- mode enum: video, audio, playlist, subs, 4k, live, list
- unknown flags pass through via `extra`
- exits 0 with usage text when no URL given

## Common function class: interactive launcher

Pattern used by `tmux-launch`:

- default target (`main`) and default dir (`$HOME`)
- `--here` to flip to cwd; `--kill` to short-circuit to `tmux kill-session`
- if already inside tmux: `switch-client` or `new-session -d`
- else: `attach` with fallback `new-session`

## Pitfalls

- `sudo -E bash handoff-post-reboot.sh` keeps `$HOME`, but bare `~` under `sudo` resolves to `/root`.
  Always use `$HOME` or fully-qualified paths inside handoff scripts.
- `install -m 644` under `sudo` writes root-owned files into user config dirs.
  Fix: `sudo chown -R synth:synth ~/.config/fish/functions` or drop to user before the fish sync step.
- Avoid `set list ($pid\$t$cmd)`: tab-separated content can be misparsed as commands. Prefer `string split` for safe parsing.
- `pushd`/`popd` in handoff scripts can inherit caller `$HOME` state oddly; prefer
  explicit `src_dir="$(cd ... && pwd)"` instead.
