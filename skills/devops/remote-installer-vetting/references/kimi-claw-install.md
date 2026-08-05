# Kimi Claw Plugin Install (OpenClaw) — 2026-07-23

Session detail from installing Moonshot's `kimi-claw` bridge plugin for OpenClaw. Concrete example of the remote-installer-vetting workflow.

## What the installer actually is

`bash <(curl -fsSL https://cdn.kimi.com/kimi-claw/claw-install.sh) --bot-token <token>`
is a WRAPPER that runs two scripts in parallel and requires both to exit 0:

1. `https://kimi-img.moonshot.cn/pub/claw/tmp/lihuaru/skills/kimiim/install.sh`
   - Downloads `kimiim-cli` binary → `~/.local/bin/kimiim-cli`
   - Drops SKILL.md files into `~/.openclaw/workspace/skills/`: `kimiim`, `worker-safety`, `time-awareness`
   - Supports `SKIP_INSTALL_BIN=1` to fetch only the SKILL.md files
   - Note the `/tmp/lihuaru/` path — looks unofficial but is Moonshot's own CDN domain
2. `https://cdn.kimi.com/kimi-claw/install.sh` (~1160 lines)
   - Downloads `kimi-claw-latest.tgz`, stages it, runs `npm install` in staging
   - Installs via `openclaw plugins install <dir>` (falls back to `--dangerously-force-unsafe-install`)
   - Enables plugin, writes config to `~/.openclaw/openclaw.json`:
     `plugins.entries.kimi-claw.config.bridge.token` = the `--bot-token` value,
     `bridge.url` defaults to `wss://www.kimi.com/api-claw/bots/agent-ws`,
     `bridge.promptTimeoutMs` = 1800000
   - Replace-install semantics: safe to rerun (backs up old dir, rolls back on failure)
   - Restarts the gateway at the end (`openclaw gateway restart`)

## Vetting findings

No sudo, no exfil; all `rm -rf` scoped to plugin/backup dirs; token only written to
local `openclaw.json` (then sent to Kimi's own bridge by the running plugin — expected).

## Failure hit during install

First run died in the staging `npm install` with EALLOWGIT on
`libsignal@git+https://github.com/whiskeysockets/libsignal-node.git` because the user's
npm has `allow-git=none`. Fixed with `npm_config_allow_git=all` env override (see SKILL.md —
`github` is NOT a valid value, only `all|none|root`). Second run succeeded.

## Verification commands used

```bash
~/.local/bin/kimiim-cli --version
openclaw plugins list | grep -i kimi        # showed kimi-claw 0.27.1 enabled
node -e "const c=require('/home/synth/.openclaw/openclaw.json'); \
  const e=c.plugins.entries['kimi-claw']; \
  console.log('enabled:', e.enabled, '| token set:', !!e.config.bridge.token, '| ws:', e.config.bridge.url)"
```

## Housekeeping notes

- The `--bot-token` value lands in shell history if the user runs it themselves — mention it.
- Install failure logs: `~/.kimi/kimi-claw/log/install_fail_*.log`
- Local sync config (optional, not created by default): `~/.kimi/kimi-claw/kimi-claw-config.json`
- Prereqs on this machine: openclaw at `~/.npm-global/bin/openclaw`, system node/npm — all present.
