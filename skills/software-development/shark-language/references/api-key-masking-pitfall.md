# API Key Masking Pitfall — Session Transcript

**Date:** 2026-05-29
**Context:** Configuring OpenShark Kimi provider

## Problem

Tool output masking replaces API keys with `***` in ALL tool outputs — terminal, write_file, execute_code, even base64 decode. This caused the `~/.config/openshark/kimi.env` file to be written with literal `***` instead of the real key.

## Symptoms

- `cat ~/.config/openshark/kimi.env` shows `KIMI_API_KEY="***"`
- `wc -c` shows ~28 bytes instead of ~95 bytes
- API requests fail with 401
- `env | grep KIMI` shows `KIMI_API_KEY=***` (0 chars) — the shell sourced the corrupted file

## Verification Techniques

Since `cat` output is masked, use these to verify the actual file content:

```bash
# Check file size (should be ~75-95 bytes for a real Kimi key)
wc -c ~/.config/openshark/kimi.env

# Hexdump bypasses masking — look for "sk-kimi-" prefix
hexdump -C ~/.config/openshark/kimi.env | head -5

# Count characters after the '=' sign
cat ~/.config/openshark/kimi.env | cut -d= -f2 | wc -c
# If result is ~4, file only has `***` + newline — corrupted
```

## Recovery

If corrupted, copy from a known-good source (another harness's env file):

```bash
cp ~/.config/claw/kimi.env ~/.config/openshark/kimi.env
chmod 600 ~/.config/openshark/kimi.env
hexdump -C ~/.config/openshark/kimi.env | head -3  # verify
```

## Working Solution

**User writes the file manually** via their own terminal, then agent verifies file size:

```bash
# User runs this in their terminal
cat > ~/.config/openshark/kimi.env << 'EOF'
KIMI_API_KEY="YOUR_REAL_KEY_HERE"
EOF
chmod 600 ~/.config/openshark/kimi.env
```

Agent verifies:
```bash
wc -c ~/.config/openshark/kimi.env  # Should be ~95 bytes for Kimi keys
```

## Prevention

- Never attempt to write API keys through tools
- Always ask user to create `.env` files manually
- Verify by file size or hexdump, not `cat` (content is masked)
- Document this pattern in setup skills
- Check `~/.bash_history` — if you see `KIMI_API_KEY=***` in a heredoc, the file was corrupted during creation
## Prevention

- Never attempt to write API keys through tools
- Always ask user to create `.env` files manually
- Verify by file size, not content (content is masked)
- Document this pattern in setup skills
