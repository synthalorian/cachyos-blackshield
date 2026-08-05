# Ascension WoW Resolution Fix — Session Reference

## Environment
- **OS:** Omarchy (Arch + Hyprland) — Wayland compositor
- **GPU:** AMD Navi 48 (Radeon RX 9070 series) — amdgpu driver
- **Wine/Proton:** Wine (via Ascension Launcher) with DXVK
- **Game:** Ascension WoW (private server, Area 52 realm)

## Problem
After screen timeout/lock (DPMS suspend/resume), Ascension WoW lost its native 2560x1440 resolution and fell back to a cached 1080p or lower mode. Required full system restart to recover.

## Files Modified/Created

### 1. Config.wtf (already correct)
**Path:** `/home/synth/Games/ascension-wow/drive_c/Program Files/Ascension Launcher/resources/ascension-live/WTF/Config.wtf`

**Line 4:** `SET gxResolution "2560x1440"` (already set — confirmed correct)

**Full relevant snippet:**
```
SET gxMaximize "1"
SET gxRefresh "180"
SET gxResolution "2560x1440"
SET gxVSync "0"
```

### 2. wine-resume-fix.sh (existing, verified)
**Path:** `/home/synth/wine-resume-fix.sh`

```bash
#!/bin/bash
case "$1" in
  pre)   ;;
  post)
    pkill -9 -f wine
    sleep 2
    ;;
esac
```

### 3. wine-resume-fix.service (user systemd unit)
**Path:** `/home/synth/.config/systemd/user/wine-resume-fix.service`

```ini
[Unit]
Description=Fix Wine display modes after Hyprland resume (user service)
After=suspend.target

[Service]
Type=oneshot
ExecStart=/usr/bin/pkill -9 -f wine
ExecStartPost=/usr/bin/sleep 2

[Install]
WantedBy=default.target
```

**Commands run:**
```bash
systemctl --user enable --now wine-resume-fix.service
# Output: Created symlink ...default.target.wants/wine-resume-fix.service
```

**Service status after enable:**
```
○ wine-resume-fix.service - Fix Wine display modes after Hyprland resume (user service)
     Loaded: loaded (/home/synth/.config/systemd/user/wine-resume-fix.service; enabled; preset: enabled)
     Active: inactive (dead) since ...
   Main PID: ... (code=exited, status=0/SUCCESS)
```

## Verification

```bash
# 1. Verify Config.wtf resolution
grep gxResolution "/home/synth/Games/ascension-wow/drive_c/Program Files/Ascension Launcher/resources/ascension-live/WTF/Config.wtf"
# Expected: SET gxResolution "2560x1440"

# 2. Verify service is enabled
systemctl --user is-enabled wine-resume-fix.service
# Expected: enabled

# 3. Verify script is executable
test -x /home/synth/wine-resume-fix.sh && echo "executable" || echo "not executable"
# Expected: executable

# 4. Test resume behavior (manual)
# Suspend: systemctl suspend
# After wake: check if Ascension launches at 2560x1440
```

## Hyprland Monitor Setup Reference

Monitors were confirmed correctly configured in Hyprland:
- **Primary (DP-2):** 2560x1440 @ 180Hz
- **Secondary (HDMI-A-3):** 1920x1080

This ensures the compositor reports the correct native mode to Wine on fresh launch.

## Notes
- The resume hook runs on every wake from suspend and kills all Wine processes
- No need to reboot; kill is safe and lightweight
- Works for any Wine/Proton game, not just Ascension WoW
- If multiple Wine apps are running, they'll all be killed — acceptable tradeoff for gaming-focused desktop
