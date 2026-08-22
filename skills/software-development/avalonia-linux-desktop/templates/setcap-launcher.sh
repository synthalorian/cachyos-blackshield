#!/bin/bash
# Self-healing setcap launcher for apps needing raw-socket capture.
# Rebuilds overwrite the binary and wipe file capabilities — this re-applies
# them via pkexec (one GUI prompt) only when missing, then execs the app.
#
# Install: ~/.local/bin/<AppName>, referenced by Exec= in the .desktop file.
# Customize BIN and nothing else.

BIN=/home/synth/Projects/active/AlbionOnline-Companion/StatisticsAnalysisTool/bin/Release/net10.0/AlbionOnlineCompanion

if ! getcap "$BIN" 2>/dev/null | grep -q cap_net_raw; then
  pkexec setcap 'cap_net_raw,cap_net_admin=eip' "$BIN"
fi
exec "$BIN" "$@"
