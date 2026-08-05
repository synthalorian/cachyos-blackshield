# Secrets Checklist — SECRETS.md

Nothing secret is committed to this repo. After install.sh, fill these in:

## Hermes Agent — `~/.hermes/config.yaml`

The template was seeded from `configs/hermes/config.example.yaml` with
`<FILL_IN>` placeholders (19 of them). Either:

```bash
hermes login nous        # interactive provider auth (recommended)
# or edit ~/.hermes/config.yaml and replace every <FILL_IN>
grep -n FILL_IN ~/.hermes/config.yaml   # find them all
```

Placeholders cover: LLM provider API keys, gateway/messaging tokens
(Telegram/Discord/Slack if enabled), and any webhook secrets.

## GitHub

```bash
gh auth login            # restores git push/pull + project cloning
```

## OpenCode

If `~/.config/opencode/opencode.jsonc` references provider keys, re-auth with:

```bash
opencode auth login
```

## OpenClaw

Gateway config lives in `~/.openclaw/openclaw.json` (NOT in this repo —
contains runtime tokens). Re-run the OpenClaw onboard flow on the new machine.

## After secrets

```bash
systemctl --user start hermes-gateway openclaw-gateway llama-swap
systemctl --user status hermes-gateway
```
