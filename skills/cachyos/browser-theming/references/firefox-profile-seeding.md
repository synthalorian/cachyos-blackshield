# Firefox Profile Seeding — verified transcript (Firefox 153.0.3, CachyOS, 2026-08)

Goal: deploy userChrome.css/userContent.css/user.js into the profile Firefox will
ACTUALLY use on first GUI launch, on a machine where Firefox has never run.

## Dead ends (all verified on-machine)

| Attempt | Result |
|---|---|
| `firefox --headless --screenshot /tmp/x.png about:blank` | Runs ("You are running in headless mode"), uses a throwaway temp profile, `~/.mozilla` never created |
| `timeout 25 firefox --headless about:blank` | Stays alive (exit 124 on timeout), still never creates `~/.mozilla` |
| `firefox -CreateProfile "default-release"` | exit 0, zero output, creates NOTHING (strace shows no mkdir) |
| Hand-made `profiles.ini` with `[Profile0] Default=1` + dir | On next run Firefox REWRITES profiles.ini, keeps the hand-made stanza as unused Profile0, creates its own `<hash>.default-release-1`, and writes `installs.ini [Install<hash>] Default=<that one>` — the install-hash default WINS over profiles.ini Default=1 |

## What works

```bash
# 1. Force creation of the install-default profile
mkdir -p ~/.mozilla/firefox
timeout 25 firefox --headless -profile ~/.mozilla/firefox/.seed-tmp about:blank || true
rm -rf ~/.mozilla/firefox/.seed-tmp
# -> ~/.mozilla/firefox/installs.ini now exists, e.g.:
#    [Install4F96D1932A9F858E]
#    Default=238t2juz.default-release-1
#    Locked=1
#    and the dir 238t2juz.default-release-1/ exists.

# 2. Resolve the real default (installs.ini first!), then deploy
prof="$HOME/.mozilla/firefox/$(awk -F= '/^Default=/{print $2; exit}' ~/.mozilla/firefox/installs.ini)"
mkdir -p "$prof/chrome"
cp -r /path/to/theme/chrome/* "$prof/chrome/"
grep -q marker "$prof/user.js" 2>/dev/null || cat /path/to/theme/user.js >> "$prof/user.js"
```

Why explicit `-profile` works when plain headless doesn't: pointing at a concrete
path forces profile-manager initialization against the real profile root, which
writes installs.ini + the install-default dir as a side effect. Plain `--headless`
short-circuits to a temp profile and never touches the profile root.

Gotcha observed: the install-default dir was named `*.default-release-1` (with the
`-1` suffix) — don't hardcode `default-release`. Always parse installs.ini.
