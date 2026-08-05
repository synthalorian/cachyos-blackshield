# ArcheAge Classic Graphics Troubleshooting on Linux

Compiled from:
- ArchRage forum thread: https://na.archerage.to/forums/threads/running-archerage-under-linux.12240/
- User's repo: github.com/synthalorian/ArcheAgeClassic-on-Linux

## Common Issues

### Black Textures / Missing Shading
**Symptom:** Textures appear black, dark, or completely missing shadows
**Root cause:** DXVK shader compilation or AMD HIZ bug

**Fix order:**
1. Use GE-Proton instead of vanilla Wine (newer DXVK)
2. AMD: `RADV_DEBUG=nohiz` environment variable
3. Try native Direct3D mode (bypass DXVK entirely)

### Cutscene Playback Failures
**Symptom:** Cutscenes freeze, stutter, or don't play
**Fix:** Install Media Foundation via winetricks:
```bash
winetricks -q mf
```

### Crash on Launch
**Symptom:** Game crashes immediately or hangs at login
**Causes:**
1. Missing `0` argument on `Launcher.exe`
2. Missing d3dcompiler packages
3. Corrupted reparse point symlink

### Reparse Point Symlink Bug
The client creates a `0` symlink in the Working directory that points to an incorrect path.

**Fix:**
```bash
target=$(xdg-user-dir DOCUMENTS)
find "$WINEPREFIX/drive_c/AAEmu/.REPARSE_POINT/Working" -type l -name "0" -exec ln -sf "$target" {} +
```

## Working Configurations

### Vanilla Wine 11+
- Requires: winetricks corefonts gdiplus vcrun2010 dxvk d3dcompiler_{42,43,46,47}
- Launch: `wine Launcher.exe 0`
- Expected: Playable with possible graphical quirks

### GE-Proton (Recommended for NVIDIA)
- Better DXVK patches
- Better nvapi support
- May resolve shading artifacts

### AMD GPU with HIZ Fix
- Add `RADV_DEBUG=nohiz` to launch script
- May need to force X11 backend
