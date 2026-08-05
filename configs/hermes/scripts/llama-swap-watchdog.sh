#!/usr/bin/env bash
# llama-swap watchdog — checks for failed-state models and auto-recovers
set -euo pipefail

LLAMA_SWAP_URL="http://127.0.0.1:8080"
CONFIG="/home/synth/llama.cpp/llama-swap/config.yaml"
LOG_TAG="llama-swap-watchdog"

log() {
  echo "[$LOG_TAG] $(date '+%H:%M:%S') $*"
}

# Check 1: Is llama-swap itself alive?
if ! curl -sf -m 5 "$LLAMA_SWAP_URL/v1/models" > /dev/null 2>&1; then
  log "llama-swap is not responding — attempting restart"
  systemctl --user restart llama-swap
  log "llama-swap restarted"
  exit 0
fi

# Check 2: Any models in error/failed state?
# llama-swap returns models with "error" key if they're in failed state
MODELS_JSON=$(curl -sf -m 10 "$LLAMA_SWAP_URL/v1/models" 2>/dev/null || echo "")
if [ -z "$MODELS_JSON" ]; then
  log "empty /v1/models response — may be transient"
  exit 0
fi

# Look for indicators of failed state in the response
if echo "$MODELS_JSON" | grep -qi "error\|failed\|unavailable"; then
  log "FAILED STATE detected in models — cleaning up"

  # Kill any orphan llama-server processes that may be lingering
  ORPHAN_PIDS=$(ps aux | grep '[l]lama-server' | awk '{print $2}' 2>/dev/null || true)
  if [ -n "$ORPHAN_PIDS" ]; then
    log "killing orphan llama-server PIDs: $ORPHAN_PIDS"
    kill $ORPHAN_PIDS 2>/dev/null || true
    sleep 2
  fi

  # Restart llama-swap to clear the failure cache
  systemctl --user restart llama-swap
  log "llama-swap restarted — failure cache cleared"

  # Verify recovery
  sleep 3
  if curl -sf -m 5 "$LLAMA_SWAP_URL/v1/models" > /dev/null 2>&1; then
    log "llama-swap recovered successfully"
  else
    log "CRITICAL: llama-swap still not responding after restart"
  fi
  exit 0
fi

# Check 3: Key models actually proxying? (deeper health check)
# Only run this check every other cycle to reduce load
CHECK_COUNTER_FILE="/tmp/llama-swap-watchdog-counter"
CHECK_COUNTER=$(cat "$CHECK_COUNTER_FILE" 2>/dev/null || echo 0)
CHECK_COUNTER=$(( (CHECK_COUNTER + 1) % 6 ))  # Deep check every 6th run (~30 min at 5-min intervals)
echo "$CHECK_COUNTER" > "$CHECK_COUNTER_FILE"

if [ "$CHECK_COUNTER" -eq 0 ]; then
  # Check if 35bkimi responds (spawns it if not loaded)
  log "deep check: testing 35bkimi model..."
  RESULT=$(curl -sf -m 120 -X POST "$LLAMA_SWAP_URL/v1/chat/completions" \
    -H "Content-Type: application/json" \
    -d '{"model":"synthclaw-35bkimi-128k","messages":[{"role":"user","content":"ping"}],"max_tokens":1}' 2>/dev/null || echo "FAILED")

  if echo "$RESULT" | grep -qi "failed\|error\|unable"; then
    log "35bkimi deep check failed: $RESULT"
    log "performance: 35bkimi is in failed state - manual intervention may be needed"
  else
    log "35bkimi is healthy ✓"
  fi
fi

# Check 4: OpenClaw gateway alive?
if ! systemctl --user is-active openclaw-gateway.service > /dev/null 2>&1; then
  log "REVIVING: openclaw-gateway is down — attempting restart"
  systemctl --user reset-failed openclaw-gateway.service 2>/dev/null || true
  systemctl --user restart openclaw-gateway.service 2>/dev/null || true
  sleep 3
  if systemctl --user is-active openclaw-gateway.service > /dev/null 2>&1; then
    log "openclaw-gateway restarted successfully ✓"
  else
    log "CRITICAL: openclaw-gateway still down after restart"
  fi
fi

log "all services healthy"
exit 0
