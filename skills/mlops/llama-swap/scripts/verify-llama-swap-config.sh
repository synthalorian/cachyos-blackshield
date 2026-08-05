#!/usr/bin/env bash
# Verify llama-swap config has required fields for all models
# Usage: ./scripts/verify-llama-swap-config.sh /path/to/config.yaml

set -euo pipefail

CONFIG="${1:-/home/synth/llama.cpp/llama-swap/config.yaml}"

if [[ ! -f "$CONFIG" ]]; then
  echo "ERROR: Config not found: $CONFIG" >&2
  exit 1
fi

echo "=== llama-swap config validator ==="
echo "Config: $CONFIG"
echo

# Extract model names and check required fields
python3 -c "
import sys, yaml, re

with open(sys.argv[1]) as f:
    cfg = yaml.safe_load(f)

models = cfg.get('models', {})
if not models:
    print('ERROR: No models defined')
    sys.exit(1)

errors = []
warnings = []

for name, model in models.items():
    cmd = model.get('cmd', '')
    proxy = model.get('proxy', '')
    
    # Check cmd contains --port
    port_match = re.search(r'--port\s+(\d+)', cmd)
    if not port_match:
        errors.append(f'{name}: missing --port in cmd')
    else:
        port = port_match.group(1)
        
    # Check proxy exists and matches port
    if not proxy:
        errors.append(f'{name}: missing proxy field')
    else:
        proxy_port_match = re.search(r':(\d+)$', proxy)
        if not proxy_port_match:
            errors.append(f'{name}: proxy malformed (no port): {proxy}')
        elif port_match and proxy_port_match.group(1) != port:
            errors.append(f'{name}: port mismatch (cmd={port}, proxy={proxy_port_match.group(1)})')

if errors:
    print('❌ ERRORS:')
    for e in errors:
        print(f'  - {e}')
    sys.exit(1)
else:
    print(f'✅ All {len(models)} models valid (cmd --port + proxy match)')
    sys.exit(0)
" "$CONFIG"
