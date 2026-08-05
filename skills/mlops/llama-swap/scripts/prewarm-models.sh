#!/usr/bin/env bash
# Pre-warm llama-swap models so cold starts happen at boot, not when you type.
# Fires requests in parallel: each model gets a curl backgrounded with --max-time.
set -euo pipefail

LLAMA_SWAP_URL="http://127.0.0.1:8080"
MODELS=("synthclaw-35b-128k" "synthclaw-glm51-128k")
TIMEOUT_SECONDS=300  # 35b can take 3 minutes to load; add margin

# Wait for llama-swap to be healthy
echo "Waiting for llama-swap at $LLAMA_SWAP_URL..."
for i in $(seq 1 30); do
  if curl -sf "$LLAMA_SWAP_URL/health" > /dev/null 2>&1; then
    echo "llama-swap is ready."
    break
  fi
  if [ "$i" -eq 30 ]; then
    echo "ERROR: llama-swap didn't become healthy after 30s"
    exit 1
  fi
  sleep 1
done

# Fire pre-warm requests in parallel so small models don't wait for large ones
echo "Pre-warming: ${MODELS[*]}..."
PIDS=()
for MODEL in "${MODELS[@]}"; do
  (
    RESPONSE=$(curl -s -X POST "$LLAMA_SWAP_URL/v1/chat/completions" \
      -H "Content-Type: application/json" \
      -H "Authorization: Bearer llama-swap-local" \
      -d "{
        \"model\": \"$MODEL\",
        \"messages\": [{\"role\": \"user\", \"content\": \"ping\"}],
        \"max_tokens\": 1,
        \"stream\": false
      }" \
      --max-time $TIMEOUT_SECONDS 2>&1)

    if echo "$RESPONSE" | grep -q '"finish_reason"'; then
      echo "  $MODEL loaded and responding."
    else
      echo "  WARNING: $MODEL pre-warm may have failed: $(echo "$RESPONSE" | head -c 200)"
    fi
  ) &
  PIDS+=($!)
done

# Wait for all parallel pre-warms to finish
for PID in "${PIDS[@]}"; do
  wait "$PID" 2>/dev/null || true
done

echo "Pre-warm complete."
