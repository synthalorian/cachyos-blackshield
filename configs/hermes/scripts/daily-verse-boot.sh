#!/usr/bin/env bash
# Daily Verse Boot Trigger
# Checks if today's verse already ran. If not, fires it.
set -euo pipefail

JOB_ID="d85b3beba408"
OUTPUT_DIR="/home/synth/.hermes/cron/output/${JOB_ID}"
TODAY="$(date +%Y-%m-%d)"

# Check if any output file exists for today
if ls "${OUTPUT_DIR}/${TODAY}"*.md 2>/dev/null | head -1 | grep -q .; then
    echo "Today's verse already delivered — skipping boot trigger."
    exit 0
fi

echo "No verse for ${TODAY} — triggering now..."
exec hermes cron run "${JOB_ID}" --accept-hooks
