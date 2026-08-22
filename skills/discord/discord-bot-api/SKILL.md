---
name: discord-bot-api
description: Use when editing Discord servers via the bot REST API.
---

# Discord Bot API (synthclaw bot)

Drive the Discord REST API directly for server admin work: renames, Unicode restyling, channel/category edits, permission checks.

## Token & identity

- Bot token lives at `~/.hermes/.env` as `DISCORD_BOT_TOKEN` (this is Hermes' own gateway bot — **synthclaw**, already present in synth's servers).
- **Never claim "no Discord tool available" without checking this file first.** A past session refused work that was fully possible via REST. Also check `~/.hermes/config.yaml` for the `discord_admin` toolset.
- Webhook URLs (e.g. `DISCORD_WEBHOOK_*` env vars) can only POST messages — they cannot rename/edit. Use the bot token.
- Never print the token. Load it into a shell var / read it inside a script.

## CRITICAL: curl only — Python HTTP is blocked

Discord's Cloudflare returns **403 "error code: 1010"** for Python `urllib`/`requests` TLS fingerprints. Use `curl` with a DiscordBot User-Agent:

```bash
TOKEN=$(python3 -c "
for l in open('/home/synth/.hermes/.env'):
    if l.startswith('DISCORD_BOT_TOKEN='): print(l.split('=',1)[1].strip().strip(chr(34)).strip(chr(39)))
")
curl -s -H "Authorization: Bot $TOKEN" \
     -H 'User-Agent: DiscordBot (https://github.com/synthalorian, 1.0)' \
     https://discord.com/api/v10/users/@me
```

`scripts/dapi.sh` is a ready helper: `dapi.sh <METHOD> <PATH> [JSON_PAYLOAD]`.

## Core endpoints

| Task | Call |
|---|---|
| Bot identity | `GET /users/@me` |
| Guild info | `GET /guilds/{gid}` |
| List channels/categories | `GET /guilds/{gid}/channels` |
| Rename channel/category | `PATCH /channels/{cid}` `{"name":"..."}` |
| Rename guild | `PATCH /guilds/{gid}` `{"name":"..."}` (needs Manage Guild) |
| Bot's roles/perms | `GET /guilds/{gid}/members/{bot_id}` + `GET /guilds/{gid}/roles`, test `int(perms) & 0x8` for Administrator |

Channel types: 0=text, 2=voice, 4=category, 5=announce, 13=stage, 15=forum.

## Unicode restyling workflow (server theming)

Discord has no server fonts — the lever is Unicode codepoint substitution in names. synth's taste: **medieval but legible** — small caps for channels, mathematical bold serif for categories/guild. **No Fraktur** (𝔅𝔴𝔖𝔥𝔦𝔢𝔩𝔡) — user explicitly rejected it as illegible.

1. Pull the channel list, build a full old→new mapping, keep emojis/hyphens/spacing untouched.
2. **Test ONE channel first** and inspect the response name codepoints before batch-applying. (2026-08-21: an off-by-one base codepoint put `📜 𝐃𝐩𝐨𝐮𝐬𝐛𝐝𝐮𝐭` live instead of `📜 𝐂𝐨𝐧𝐭𝐫𝐚𝐜𝐭𝐬` — the user watched it happen. Math bold serif bases: `A`=U+1D400, `a`=U+1D41A. Sanity-check the transform output before any PATCH.)
3. Apply with ~0.4s spacing; handle 429 by sleeping `retry_after`.
4. Guild rename needs Manage Guild — may fail even with channel perms; report separately.

See `references/unicode-styling.md` for the exact character maps and legibility tiers.

## Pitfalls

- **Rename rate limit: 2 name changes per channel per 10 min.** A wrong batch burns one of two slots — this is why you test one first. A fix pass right after a bad batch still fits, but a third change waits 10 minutes.
- **Text channel names force ASCII lowercase**, but non-ASCII (small caps etc.) survives — so Unicode substitution is the only way to get "caps" in text channel names.
- Small caps channels can't be typed normally for mentions — users pick from autocomplete. Offer to revert channels to plain ASCII while keeping categories styled if synth complains.
- Role hierarchy: even with Administrator, the bot can't manage roles/members above its highest role. Check positioning if member ops 403.
- Privileged intents (Message Content, Server Members) are set in the Developer Portal, not via API.
