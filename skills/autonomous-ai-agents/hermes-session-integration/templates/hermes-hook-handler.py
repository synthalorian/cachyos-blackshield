"""
Starter handler.py for a Hermes native Python hook.

Place in: ~/.hermes/hooks/<hook-name>/handler.py
Alongside: HOOK.yaml manifest

The gateway calls handle(event_type, context) at each lifecycle point
declared in HOOK.yaml. Errors are caught and logged, never block the gateway.
"""

import asyncio
import json
import logging
import subprocess
from typing import Any, Dict

logger = logging.getLogger(f"hermes.hooks.{__name__}")

# ── Configuration ──────────────────────────────────────────────────
# Adjust these for your integration target

TARGET_SCRIPT = "/path/to/your/script.sh"  # or CLI command
TARGET_TIMEOUT = 10  # seconds

# ── Event Mapping ──────────────────────────────────────────────────
# Map Hermes events to whatever your target tool expects.
# Return None to skip firing for that event.

EVENT_MAP = {
    "session:start": "ready",
    "agent:start": "acknowledge",
    "agent:end": "complete",
    "session:end": "done",
}


def _map_event(event_type: str, context: Dict[str, Any]) -> Dict[str, Any] | None:
    """Translate Hermes event + context into target payload."""
    mapped = EVENT_MAP.get(event_type)
    if mapped is None:
        return None  # Skip (e.g. agent:step)

    return {
        "event": mapped,
        "session_id": context.get("session_id", ""),
        "platform": context.get("platform", ""),
        "cwd": context.get("session_key", context.get("cwd", "")),
        # Add more fields your target needs here
    }


def _fire(payload: Dict[str, Any]) -> None:
    """Execute the target script with JSON payload on stdin."""
    try:
        proc = subprocess.run(
            ["bash", TARGET_SCRIPT],
            input=json.dumps(payload),
            capture_output=True,
            text=True,
            timeout=TARGET_TIMEOUT,
        )
        if proc.returncode != 0:
            logger.debug("Target exited %d: %s", proc.returncode, proc.stderr[:200])
    except subprocess.TimeoutExpired:
        logger.debug("Target timed out")
    except Exception as exc:
        logger.debug("Target error: %s", exc)


async def handle(event_type: str, context: Dict[str, Any]) -> None:
    """Entry point called by Hermes HookRegistry."""
    payload = _map_event(event_type, context)
    if payload is None:
        return

    # Run blocking subprocess in thread pool to avoid stalling event loop
    loop = asyncio.get_running_loop()
    await loop.run_in_executor(None, _fire, payload)
