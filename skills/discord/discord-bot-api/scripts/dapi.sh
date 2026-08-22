#!/usr/bin/env bash
# Discord REST helper for the synthclaw bot token.
# Usage: dapi.sh <METHOD> <PATH> [JSON_PAYLOAD]
#   dapi.sh GET /users/@me
#   dapi.sh PATCH /channels/123 '{"name":"new-name"}'
# Reads DISCORD_BOT_TOKEN from ~/.hermes/.env; never echoes it.
TOKEN=$(python3 -c "
for l in open('/home/synth/.hermes/.env'):
    if l.startswith('DISCORD_BOT_TOKEN='): print(l.split('=',1)[1].strip().strip(chr(34)).strip(chr(39)))
")
METHOD="$1"; PATH_="$2"; PAYLOAD="${3:-}"
ARGS=(-s -X "$METHOD" -H "Authorization: Bot $TOKEN" -H 'User-Agent: DiscordBot (https://github.com/synthalorian, 1.0)')
if [ -n "$PAYLOAD" ]; then
  ARGS+=(-H 'Content-Type: application/json' -d "$PAYLOAD")
fi
curl "${ARGS[@]}" "https://discord.com/api/v10${PATH_}"
