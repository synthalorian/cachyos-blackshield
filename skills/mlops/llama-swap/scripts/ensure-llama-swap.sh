#!/usr/bin/env bash
# ensure-llama-swap — auto-start llama-swap if not running, wait for ready
# Usage: source this script or call directly before making local model requests
# Integrates with claw/hermes wrappers for on-demand llama-swap startup

if ! curl -s --max-time 2 http://127.0.0.1:8080/v1/models >/dev/null 2>&1; then
    echo "🦞 llama-swap not running, starting..." >&2
    systemctl --user start llama-swap.service
    # Wait for it to be ready (up to 30s)
    for i in {1..30}; do
        if curl -s --max-time 2 http://127.0.0.1:8080/v1/models >/dev/null 2>&1; then
            echo "🦞 llama-swap ready" >&2
            exit 0
        fi
        sleep 1
    done
    echo "🦞 ERROR: llama-swap failed to start" >&2
    exit 1
fi
