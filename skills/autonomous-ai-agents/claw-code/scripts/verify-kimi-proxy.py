#!/usr/bin/env python3
"""Verify Kimi proxy is running, key is valid, and Hermes config points to proxy.

This script avoids shell output masking issues by reading the key directly
from the env file and testing the full chain: key -> proxy -> upstream -> model list.
"""
import json
import os
import sys
import urllib.request

PROXY_URL = "http://127.0.0.1:8699"
HERMES_CONFIG = os.path.expanduser("~/.hermes/config.yaml")


def find_key():
    """Read KIMI_API_KEY from known env files."""
    for path in ["~/.config/claw/kimi.env", "~/.hermes/.env"]:
        full = os.path.expanduser(path)
        if not os.path.exists(full):
            continue
        with open(full, "r") as f:
            for line in f:
                if line.startswith("KIMI_API_KEY="):
                    return line.strip().split("=", 1)[1]
    return None


def check_proxy():
    """Test proxy health by listing models."""
    key = find_key()
    if not key:
        print("FAIL: KIMI_API_KEY not found in ~/.config/claw/kimi.env or ~/.hermes/.env")
        return False

    print(f"Key found: {len(key)} chars, starts with sk-kimi: {key.startswith('sk-kimi')}")

    req = urllib.request.Request(f"{PROXY_URL}/v1/models")
    req.add_header("Authorization", f"Bearer {key}")

    try:
        with urllib.request.urlopen(req, timeout=10) as resp:
            data = json.loads(resp.read())
            models = [m["id"] for m in data.get("data", [])]
            print(f"Proxy OK: status={resp.status}, models={models}")
            return True
    except urllib.error.HTTPError as e:
        print(f"FAIL: Proxy returned {e.code} — {e.reason}")
        if e.code == 401:
            print("  → Key is invalid, expired, or missing")
        return False
    except urllib.error.URLError as e:
        print(f"FAIL: Cannot connect to proxy at {PROXY_URL} — {e.reason}")
        print("  → Proxy is not running. Start it: python3 ~/.local/bin/kimi-proxy &")
        return False


def check_hermes_config():
    """Verify Hermes base_url points to the proxy, not direct Kimi API."""
    if not os.path.exists(HERMES_CONFIG):
        print("WARN: Hermes config not found")
        return False

    with open(HERMES_CONFIG) as f:
        for line in f:
            if "base_url:" in line:
                url = line.split("base_url:", 1)[1].strip()
                if "127.0.0.1:8699" in url:
                    print(f"Hermes config OK: base_url -> proxy ({url})")
                    return True
                elif "api.kimi.com" in url:
                    print(f"FAIL: Hermes base_url points to DIRECT Kimi API ({url})")
                    print("  → Update ~/.hermes/config.yaml: base_url: http://127.0.0.1:8699/v1")
                    return False
                else:
                    print(f"Hermes base_url: {url} (unexpected)")
                    return False
    print("WARN: base_url not found in Hermes config")
    return False


def main():
    print("=" * 50)
    print("Kimi Proxy Verification")
    print("=" * 50)

    proxy_ok = check_proxy()
    print()
    config_ok = check_hermes_config()
    print()

    if proxy_ok and config_ok:
        print("ALL CHECKS PASSED 🎹🦞")
        return 0
    else:
        print("SOME CHECKS FAILED — see above")
        return 1


if __name__ == "__main__":
    sys.exit(main())
