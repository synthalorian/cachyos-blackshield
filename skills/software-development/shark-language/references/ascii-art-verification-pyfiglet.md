# ASCII Art Verification with pyfiglet

## Problem

ASCII art in README/TUI was hand-edited and no longer spelled the project name correctly. The art at the top of README.md spelled "Acraskhox" (or similar gibberish) instead of "OpenShark".

## Detection

The user noticed the art looked wrong and asked "why does that say Acraskhox?"

## Root Cause

The ASCII art was either:
1. Copied from a different project and not updated for the new name
2. Hand-edited and letters were mangled during editing
3. Generated for a different font/width and didn't translate

## Fix

Generate fresh ASCII art with pyfiglet and replace the broken art:

```bash
# Install pyfiglet if needed
pip install --user --break-system-packages pyfiglet

# Generate standard font art
python3 -c "import pyfiglet; print(pyfiglet.figlet_format('OpenShark', font='standard'))"
```

Output:
```
  ___                   ____  _                _    
 / _ \ _ __   ___ _ __ / ___|| |__   __ _ _ __| | __
| | | | '_ \ / _ \ '_ \\___ \| '_ \ / _` | '__| |/ /
| |_| | |_) |  __/ | | |___) | | | | (_| | |  |   < 
 \___/| .__/ \___|_| |_|____/|_| |_|\__,_|_|  |_|\_\
      |_|
```

Compare against existing art. If they don't match, replace.

## Prevention

**Before every release:**
1. Generate fresh art with pyfiglet
2. Compare against README/TUI
3. Have a second person verify (or the user)

**Alternative:** Use a banner image instead of ASCII art. Less error-prone.

## When pyfiglet Fails

If pyfiglet isn't installed or the Python path is weird:
```bash
# Find the right Python
python3.14 -m pyfiglet OpenShark 2>/dev/null || \
  /home/synth/.local/bin/python3 -m pyfiglet OpenShark 2>/dev/null || \
  find /home/synth/.local -name pyfiglet -type d 2>/dev/null | head -1
```

Or use an online figlet generator: https://patorjk.com/software/taag/

## Session Reference

- OpenShark v1.0.0 ship session
- Fixed in commit: `a5bd965` — "fix(ascii): correct OpenShark banner text — was gibberish"
