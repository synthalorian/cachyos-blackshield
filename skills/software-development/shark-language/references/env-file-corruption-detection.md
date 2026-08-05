# Env-File Corruption Detection Pattern

Session: 2026-05-30 — OpenShark kimi.env corrupted with `***`

## The Problem

API key env files get corrupted when written through tool outputs that mask secrets. The file ends up with literal `***` instead of the actual key:

```bash
$ cat ~/.config/openshark/kimi.env
KIMI_API_KEY="***"
```

This happens because:
1. Tool output masking replaces all API keys with `***` in responses
2. If a tool writes to an env file, the masked output gets written literally
3. The file looks valid (proper format) but contains no actual key

## Detection

Check key length to detect corruption:

```bash
# Check if key is actually present (should be ~70+ chars for Kimi)
cat ~/.config/openshark/kimi.env | cut -d= -f2 | wc -c
# If result is ~4, the file only has `***` + newline — it's corrupted

# Quick check: is the key longer than 10 chars?
key_len=$(cat ~/.config/openshark/kimi.env | cut -d= -f2 | tr -d '"' | wc -c)
if [ "$key_len" -lt 10 ]; then
    echo "Env file corrupted — key too short ($key_len chars)"
fi
```

## Recovery

Copy from a known-good source:

```bash
# Option 1: Copy from another tool's env file (if valid)
cp ~/.config/claw/kimi.env ~/.config/openshark/kimi.env

# Option 2: Copy from OpenClaw workspace
# (OpenClaw stores keys in its own format)

# Option 3: Re-enter the key manually
read -s -p "Enter API key: " key
echo "KIMI_API_KEY=\"$key\" > ~/.config/openshark/kimi.env
chmod 600 ~/.config/openshark/kimi.env
```

## Prevention

1. **Never write env files through tools** — tools mask output, so writes get corrupted
2. **Create env files manually** or via setup wizard (interactive, not through tool output)
3. **Verify after creation** — always check key length
4. **Keep a backup** in a password manager or secure store

## Applies To

Any tool that uses env-file key management:
- OpenShark (`~/.config/openshark/*.env`)
- claw-code (`~/.config/claw/*.env`)
- OpenClaw (`~/.openclaw/*.env`)
- Any tool using `dotenvy` + `shellexpand` pattern
