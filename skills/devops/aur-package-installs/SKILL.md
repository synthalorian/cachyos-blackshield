---
name: aur-package-installs
description: >
  Installing AUR packages with paru/yay on Arch-based systems (CachyOS) from a
  Hermes agent terminal — including the nested-sudo TTY failure and the
  makepkg fallback workflow. Triggers: AUR, paru, yay, install AUR package,
  PKGBUILD, makepkg, unityhub, AUR helper sudo password required.
version: 1.0.0
tags: [arch, cachyos, aur, paru, yay, makepkg, pacman, package-management]
---

# AUR Package Installs from Hermes

How to reliably install AUR packages on synth's CachyOS system when driving pacman/paru/yay from the Hermes agent terminal.

## Setup facts

- paru and yay ship directly in the CachyOS repos (`cachyos/paru`, `cachyos/yay`). Install with `sudo pacman -S paru yay` — no manual AUR bootstrap.
- Check the official repos first (`pacman -Ss <pkg>`) before reaching for the AUR; CachyOS repos carry more than stock Arch.

## Pitfall: AUR helpers can't sudo from a Hermes terminal

paru/yay spawn sudo internally without a TTY, so the password prompt fails:

```
sudo: a terminal is required to read the password
sudo: a password is required
```

This happens even right after an approved `sudo` command in the same session — sudo's credential ticket is per-tty, and the helper's nested sudo runs on a different (non-)tty. `sudo -v` beforehand does NOT fix it.

## The workaround that works every time

Direct sudo invocations as the terminal command ARE approved fine — only the nested sudo inside the helper breaks. So split the install into steps where every sudo is direct:

1. `paru -S --noconfirm <pkg>` and let it run — it resolves deps and downloads the PKGBUILD into `~/.cache/paru/clone/<pkg>/` before dying at the sudo step. The clone is the valuable part.
2. Preinstall the repo deps directly: `sudo pacman -S --noconfirm --needed <deps>` (paru's output lists them under "Repo").
3. Build as the user: `cd ~/.cache/paru/clone/<pkg> && makepkg -f --noconfirm`
4. Install the artifact: `sudo pacman -U --noconfirm <pkg>-<ver>-<rel>-x86_64.pkg.tar.zst`

Every sudo call is top-level, so the approval flow handles each one.

## Pitfall: don't `source PKGBUILD` to extract deps

`bash -c 'source PKGBUILD; echo "${depends[@]}"'` executes an untrusted script and
gets blocked by command approval. Read the PKGBUILD with read_file and copy the
`depends=(...)` / `makedepends=(...)` arrays by hand. Then split repo vs AUR deps
with `pacman -Si <pkg>` per package — `pacman -S` fails the ENTIRE install if any
single target is AUR-only, so the AUR stragglers (e.g. `ruby-wavefile` for
sonic-pi) must go through the makepkg path separately. Their clones usually
already exist under `~/.cache/paru/clone/` after the initial paru run.

## Note: the initial `paru -S` can exceed a 300s timeout

Dep resolution + downloads on a big package (sonic-pi pulled ~30 repo deps) can
blow past a 5-minute foreground timeout. That's fine — the clone into
`~/.cache/paru/clone/<pkg>/` still completes. After a timeout, check for the
clone and continue the manual workflow; don't re-run paru from scratch.

## Pitfall: interrupted download leaves a `.part` file that poisons rebuilds

If a paru/makepkg run is interrupted mid-download (agent terminal timeout on a
big source tarball), the clone dir keeps a `<pkg>-<ver>.tar.gz.part` file. The
next makepkg tries to RESUME it and dies:

```
curl: (33) HTTP server does not seem to support byte ranges. Cannot resume.
==> ERROR: Failure while downloading ...
```

GitHub codeload doesn't support byte ranges, so resume can never succeed. Fix:
`rm` the `.part` file (note the extension — `ls` the clone dir for
`*.tar.gz*` first) from the clone dir, then rerun makepkg for a fresh download.

## Pitfall: downloads keep resetting on flaky links (HTTP/2 resets, SSL EOF)

If fresh downloads ALSO die mid-transfer (`curl: (92) HTTP/2 stream reset`,
`curl: (56) SSL_read: unexpected eof`), makepkg's own fetcher won't recover —
retrying just restarts from byte 0 and dies again at a random offset. Manual
fetch with forced HTTP/1.1 (dodges the HTTP/2 resets) is the fix:

1. `curl -L --http1.1 --retry 8 --retry-all-errors -o <tarball> <source-url-from-PKGBUILD>`
   (run backgrounded with notify_on_complete — at ~200 kB/s a 150 MB tarball
   needs ~15 min of stable link; each retry restarts from byte 0)
2. Verify BEFORE rebuilding: `sha512sum <tarball>` vs the `sha512sums=` array
   in the PKGBUILD. On match, makepkg skips downloading entirely.
3. Don't run network speed tests in parallel — they starve the download.

## Pitfall: Elixir/Hex deps time out mid-build (mix deps.get)

Packages with Elixir components (sonic-pi, livebook, etc.) fail in `build()`
with `(Mix) Package fetch failed and no cached copy available` when
repo.hex.pm is slow. Hex caches already-fetched packages, so a retry resumes
rather than restarting. Re-run with Hex throttled per its own error hint:

`HEX_HTTP_CONCURRENCY=1 HEX_HTTP_TIMEOUT=180 makepkg -f --noconfirm`

(Hex CVE-audit warnings like `plug_cowboy x.y.z VULNERABLE!` in the output are
noise, not the failure — the failure is the `Request failed (:timeout)` line.)

## Pitfall: user denies the sudo install commands

Bulk `sudo pacman -S` (or provider swaps like jack2 → pipewire-jack) can be
denied — user away from keyboard or cautious about a big dep list / a change
touching many packages. Approval prompts ALSO expire fast (timed out 3x in one
session while the user was willing): before issuing a sudo command, tell the
user to watch for the prompt; after 2 missed windows, hand them the manual
command instead of retrying. Do NOT rephrase or split the command to route
around a denial. Stop, state what was denied and why it matters, present the
full remaining install as a numbered copy-paste runbook (repo deps → AUR deps
already cloned in ~/.cache/paru/clone/ → makepkg → pacman -U), and offer to
re-issue on their say-so. Non-sudo work (dep resolution via `pacman -Si`,
reading PKGBUILDs, writing code that doesn't need the package) continues
meanwhile.

## Pitfall: `--noconfirm` answers NO to conflict removal

Replacing a conflicting package (e.g. `jack2` → `pipewire-jack`) fails with
`unresolvable package conflicts detected` because `--noconfirm` takes the
default (N) on the "Remove jack2?" prompt. Use `yes | sudo pacman -S <pkg>`
to auto-yes the removal. First verify the replacement `provides` the old
library ABI (`pipewire-jack` satisfies audacity/ffmpeg/mpv/guitarix libjack
deps, so the swap is safe and reversible).

## Verifying GUI/Electron packages

Don't verify by launching — Electron apps (e.g. `unityhub --version`) hang in a headless terminal trying to spawn a GUI and eat the whole command timeout. Verify with `pacman -Qi <pkg>` and the presence of `/usr/share/applications/<pkg>.desktop` instead.
