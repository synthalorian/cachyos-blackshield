# Homebrew on Linux (CachyOS/Arch) — vetted install recipe

Official installer: https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh (~34 KB, single file, no nested curl|bash children).

## What the script does (as of 2026-07)

- Linux prefix is hardcoded: `/home/linuxbrew/.linuxbrew` (repo at `<prefix>/Homebrew`).
- sudo is used ONLY for mkdir/chown/chmod of the prefix and cache dirs — no system file edits, no rm -rf, no crontab/systemctl.
- Network: git fetch from `github.com/Homebrew/brew` (+ homebrew-core only if `HOMEBREW_NO_INSTALL_FROM_API` is set). Also downloads a portable-ruby bottle from ghcr.io if system ruby < 3.4.
- Does NOT edit shell rc files — it prints the shellenv line for you to add yourself.
- Analytics: disabled during the install run; enabled by default afterward (`brew analytics off` to opt out).

## Prereqs on Arch/CachyOS

- git >= 2.7, curl >= 7.41, ruby >= 3.4 (Arch repos satisfy all; otherwise it vendors portable ruby, needs glibc >= 2.13).
- `pacman -Q base-devel bubblewrap` — note: `pacman -Qg base-devel` can return empty even when the `base-devel` meta-package is installed; check the package itself.
- sudo password (installer refuses to run as root).

## Headless run (user provided sudo password)

```bash
curl -fsSL -o /tmp/brew-install.sh https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh
# ... vet the script per the main workflow ...
printf '#!/bin/sh\necho "<password>"\n' > /tmp/.askpass && chmod 700 /tmp/.askpass
env SUDO_ASKPASS=/tmp/.askpass sudo -A -v   # validate
env SUDO_ASKPASS=/tmp/.askpass NONINTERACTIVE=1 bash /tmp/brew-install.sh
rm -f /tmp/.askpass /tmp/brew-install.sh
```

`NONINTERACTIVE=1` skips the ENTER prompt; the script detects `SUDO_ASKPASS` and uses `sudo -A`. Runs fine as a background process (git fetch takes a couple minutes).

## Post-install (fish)

```fish
echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv fish)"' >> ~/.config/fish/config.fish
```

Verify: `/home/linuxbrew/.linuxbrew/bin/brew --version` (full path works before PATH is wired). Then `brew analytics off` unless the user wants stats sent.
