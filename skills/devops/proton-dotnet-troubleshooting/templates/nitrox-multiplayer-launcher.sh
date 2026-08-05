#!/bin/bash
# Nitrox Multiplayer Launcher for Subnautica on Linux
# Ensures server starts BEFORE game to avoid race condition
#
# USAGE: ./nitrox-multiplayer-launcher.sh [save_name]
#   Default save: test

SAVE_NAME="${1:-test}"
NITROX_PATH="/opt/nitrox"
STEAM_GAME_ID=264710
SUBNAUTICA_PATH="$HOME/.local/share/Steam/steamapps/common/Subnautica"

# ── Clean slate ───────────────────────────────────────────────────────────────
killall -9 Nitrox.Server.Subnautica 2>/dev/null
killall -9 Nitrox.Launcher 2>/dev/null
pkill -f "Subnautica.exe" 2>/dev/null
sleep 1

# ── Start Nitrox server ──────────────────────────────────────────────────────
echo "[$(date '+%H:%M:%S')] Starting Nitrox server (save: $SAVE_NAME)..."
"$NITROX_PATH/Nitrox.Server.Subnautica" --save "$SAVE_NAME" --embedded &
SERVER_PID=$!

# ── Wait for server to bind to UDP 11000 ─────────────────────────────────────
echo "[$(date '+%H:%M:%S')] Waiting for server to initialize..."
READY=0
for i in $(seq 1 30); do
    # Check via log file
    LOG_FILE="$HOME/.config/Nitrox/logs/server[${SAVE_NAME}]-$(date '+%Y%m%d').log"
    if [[ -f "$LOG_FILE" ]] && grep -q "Server started" "$LOG_FILE" 2>/dev/null && grep -q "listening on port 11000" "$LOG_FILE" 2>/dev/null; then
        READY=1
        break
    fi
    # Also check socket state
    if ss -lnup 2>/dev/null | grep -q ':11000'; then
        READY=1
        break
    fi
    sleep 1
    echo -n "."
done
echo ""

if [[ $READY -ne 1 ]]; then
    echo "[$(date '+%H:%M:%S')] ERROR: Server failed to start on port 11000 within 30s"
    kill $SERVER_PID 2>/dev/null
    exit 1
fi

echo "[$(date '+%H:%M:%S')] Server ready on UDP 11000"

# ── Launch Subnautica ────────────────────────────────────────────────────────
echo "[$(date '+%H:%M:%S')] Launching Subnautica..."
steam steam://rungameid/$STEAM_GAME_ID --nitrox "$NITROX_PATH" &

# ── Cleanup trap ─────────────────────────────────────────────────────────────
trap "echo 'Cleaning up Nitrox server...'; kill $SERVER_PID 2>/dev/null; exit" EXIT INT TERM

# ── Monitor ──────────────────────────────────────────────────────────────────
echo "[$(date '+%H:%M:%S')] Game launched. Server will remain active."
echo "Press Ctrl+C to stop both server and game."
echo ""

# Keep script alive while server runs
while kill -0 $SERVER_PID 2>/dev/null; do
    sleep 5
done
