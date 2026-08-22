#!/usr/bin/env bash
# discord-api.sh — curl wrapper for the Discord bot REST API.
# Usage: discord-api.sh <METHOD> <API_PATH> [JSON_PAYLOAD]
#   ./discord-api.sh GET /users/@me
#   ./discord-api.sh GET /guilds/123/channels
#   ./discord-api.sh PATCH /channels/456 '{"name":"new-name"}'
# Token is read from ~/.hermes/.env (DISCORD_BOT_TOKEN) and never printed.
# curl is REQUIRED — Python urllib/requests get Cloudflare 403 error 1010.
set -euo pipefail

TOKEN=$(python3 -c "
for l in open('/home/synth/.hermes/.env'):
    if l.startswith('DISCORD_BOT_TOKEN='):
        print(l.split('=',1)[1].strip().strip(chr(34)).strip(chr(39)).strip())
        break
")
[ -n "$TOKEN" ] || { echo "DISCORD_BOT_TOKEN not found in ~/.hermes/.env" >&2; exit 1; }

METHOD="$1"; PATH_="$2"; PAYLOAD="${3:-}"
ARGS=(-s -X "$METHOD"
      -H "Authorization: Bot $TOKEN"
      -H 'User-Agent: DiscordBot (https://github.com/synthalorian, 1.0)')
if [ -n "$PAYLOAD" ]; then
  ARGS+=(-H 'Content-Type: application/json' -d "$PAYLOAD")
fi
curl "${ARGS[@]}" "https://discord.com/api/v10${PATH_}"
