---
name: remote-installer-vetting
description: "Safely vet and run curl|bash remote installers — inspect before executing, trace nested scripts, fix npm git-dep (EALLOWGIT) failures."
version: 1.0.0
author: synthclaw
metadata:
  hermes:
    tags: [security, installers, curl-bash, npm, troubleshooting]
---

# Remote Installer Vetting (curl | bash)

How to handle `bash <(curl -fsSL ...)` install requests without blindly executing remote code, plus the common failure modes that follow.

## The Vetting Workflow

Never run a remote installer blind. Even for legitimate vendors, inspect first — it takes 2 minutes and tells the user exactly what will change on their machine.

1. **Download, don't pipe.** `curl -fsSL -o /tmp/install.sh -w "HTTP %{http_code} | %{size_download} bytes\n" <url>`
2. **Read it.** `read_file` the whole thing. Small scripts are often wrappers.
3. **Trace nested downloads recursively.** Wrappers commonly `bash <(curl ...) &` several child scripts in parallel. Download and read EACH child before running anything.
4. **Grep for the danger surface:**
   - Where do secrets/tokens get written? (local config = fine; POSTed to unexpected hosts = red flag)
   - `rm -rf` scope (should be limited to the tool's own dirs/backups)
   - `sudo`, crontab, systemctl/launchctl writes, PATH/shell-rc edits
   - Unexpected hosts beyond the vendor's own domains
5. **Check prereqs** (`command -v` for each required binary) before running.
6. **Then run the user's original command** (with any needed env overrides), and verify the result with real checks — version output, plugin listing, config keys present.

## Handling Secrets in Install Commands

- Users paste live tokens into chat constantly. Flag it ONCE, recommend rotation after setup, don't lecture.
- Remind them the token also lands in their shell history if they run the command themselves.
- Tokens written to a local config file by the installer are expected; tokens sent to the vendor's own endpoint by the running service are expected (that's usually the point). Anything else is a finding.

## Sudo-Prompting Installers: Run Headless via SUDO_ASKPASS

When the user pastes their sudo password so you can run an installer end-to-end, do NOT `echo "$PW" | sudo -S` (password lands in shell history and ps). Instead:

```bash
printf '#!/bin/sh\necho "<password>"\n' > /tmp/.askpass && chmod 700 /tmp/.askpass
env SUDO_ASKPASS=/tmp/.askpass sudo -A -v        # validate once before the real run
env SUDO_ASKPASS=/tmp/.askpass <install command> # sudo inside script picks up -A
rm -f /tmp/.askpass                              # the moment the install finishes
```

- Validate with `sudo -A -v` FIRST — a typo'd password discovered mid-install is a mess.
- Many official installers honor `SUDO_ASKPASS` and a non-interactive flag. Homebrew: `env SUDO_ASKPASS=... NONINTERACTIVE=1 bash install.sh` runs fully headless (skips the ENTER prompt, uses `sudo -A`). Check the script for `SUDO_ASKPASS`/`NONINTERACTIVE` handling during the read-through step — it tells you whether you need a PTY or not.
- If the installer hard-requires a TTY, run it via terminal with pty=true in background and `process submit` the password at the prompt.
- Prefer the `env VAR=... command` form over a `VAR=... command` prefix if the first attempt prints sudo's usage text inexplicably.

## npm EALLOWGIT (git dependencies blocked)

Installers that run `npm install` can die with:

```
npm error code EALLOWGIT
npm error Fetching packages of type "git" have been disabled
npm error Refusing to fetch "<pkg>@git+https://github.com/..."
```

**Root cause:** `npm config get allow-git` → `none` (deliberate user hardening; blocks all git+https deps).

**Fix — env-scoped override, do NOT edit the user's npmrc:**

```bash
npm_config_allow_git=all <install command>
```

**Pitfall:** `allow-git` accepts ONLY `all`, `none`, `root` on current npm. Per-host values like `npm_config_allow_git=github` are REJECTED (`invalid config ... Must be one of: all, none, root`). Don't waste a run on it.

If `allow-git=none` was set deliberately (it usually is), say so and keep the override scoped to the single run.

## Verifying the Install Actually Worked

Don't trust "done" output alone. Verify with the tool's own surface:

- Binary: `<installed-binary> --version`
- Plugin systems: list command (e.g. `openclaw plugins list`)
- Config: parse the config file and assert the expected keys exist (enabled flag, token present, endpoint URL)

## Reporting Back

Give the user a vetting summary even when clean: what the script chain does, where files land, what config gets written, and anything eyebrow-raising (e.g. unofficial-looking CDN tmp paths on the vendor's own domain — note it, don't panic).

## References

- `references/kimi-claw-install.md` — full anatomy of Moonshot's kimi-claw OpenClaw plugin installer (wrapper → two parallel children), its config writes, and verification commands. Good concrete example of this workflow applied end-to-end.
- `references/homebrew-linux-install.md` — vetted Homebrew-on-Linux recipe for Arch/CachyOS: what the official installer touches, prereqs, the headless SUDO_ASKPASS + NONINTERACTIVE run, fish shellenv setup.
