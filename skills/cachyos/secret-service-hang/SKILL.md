---
name: secret-service-hang
description: Diagnose and fix GUI apps (ProtonVPN, etc.) that launch but never show a window — usually a Secret Service keyring deadlock. Covers faulthandler stack dumps on live Python apps, KWin window enumeration on Wayland, and the gnome-keyring default-collection SetAlias fix.
---

# Secret Service Hang — Silent GUI App Deadlock

## Trigger

App process starts and stays alive but **no window ever appears**, zero stdout/stderr. Classic on KDE Plasma (CachyOS) with gnome-keyring: ProtonVPN, and any Electron/Python app that reads credentials from Secret Service at startup. User re-clicks → multiple stacked dead processes.

## Root Cause (most common)

App calls Secret Service `get_default_collection` at startup. If no default keyring collection exists (fresh system, autologin, or keyring never created), the daemon tries `CreateCollection` → spawns a `gcr-prompter` password dialog (blank title, often hidden behind other windows) → app blocks on the prompt forever. App is the victim, keyring is the culprit.

## Diagnostic Chain (in order)

1. **Confirm no window exists** (Wayland — wmctrl/xdotool DON'T work). Inject a KWin script:
   ```bash
   # /tmp/listwin.js:
   # var w = workspace.windowList();
   # for (var i=0;i<w.length;i++) print("WINLIST: "+w[i].caption+" || class="+w[i].resourceClass+" || pid="+w[i].pid);
   qdbus6 org.kde.KWin /Scripting org.kde.kwin.Scripting.loadScript /tmp/listwin.js listwin
   sleep 1; qdbus6 org.kde.KWin /Scripting org.kde.kwin.Scripting.start
   sleep 2; journalctl --user -b --no-pager | grep WINLIST | tail -20
   ```
   (Service is `org.kde.KWin`, object `/Scripting` — NOT `org.kde.kwin.Scripting` as the service name.)

2. **Stack-dump the hung Python app** without killing it prematurely:
   ```bash
   PYTHONFAULTHANDLER=1 <app-binary> > /tmp/app.log 2>&1 &   # relaunch
   PID=$(pgrep -f 'python /usr/bin/<app-binar[y]' | head -1) # the PYTHON child, not wrapper
   kill -ABRT $PID   # dumps ALL thread stacks to stderr, then aborts
   ```
   If the stack shows `secretstorage/util.py exec_prompt` / `create_collection` / `keyring/backends/SecretService.py` → confirmed keyring deadlock.

3. **Confirm independently** (this hangs = guilty):
   ```bash
   timeout 12 python3 -c "
   from secretstorage import get_default_collection
   import jeepney.io.blocking
   c = get_default_collection(jeepney.io.blocking.open_dbus_connection())
   print(c.get_label(), 'locked=', c.is_locked())"
   # exit=124 (timeout) => Secret Service is the problem
   ```

4. **Inspect keyring state:**
   ```bash
   busctl --user list | grep -i secret          # who owns org.freedesktop.secrets
   busctl --user tree org.freedesktop.secrets   # collections present
   ```
   Only `.../collection/session` and no `login` collection = missing default keyring.

## Fix (gnome-keyring on KDE)

1. Kill dead app instances: `pkill -f 'protonvpn-a[p]p'` (bracket trick — see pitfalls).
2. Create the keyring interactively — a gcr-prompter dialog appears (blank title, may be behind windows); user sets their LOGIN password (auto-unlock at boot):
   ```bash
   python3 -c "
   from secretstorage import create_collection
   import jeepney.io.blocking
   create_collection(jeepney.io.blocking.open_dbus_connection(), 'login')"
   ```
3. **Critical:** creating does NOT set the default alias — step 2 alone leaves the hang. Point the alias:
   ```bash
   gdbus call --session --dest org.freedesktop.secrets \
     --object-path /org/freedesktop/secrets \
     --method org.freedesktop.Secret.Service.SetAlias \
     default /org/freedesktop/secrets/collection/login_5f1
   ```
   (Object path from `busctl --user tree` — suffix varies, e.g. `login_5f1`.)
4. Re-run the step-3 diagnostic — should return instantly with `locked= False`. Relaunch app, verify window via KWin script.

## Pitfalls

- **pkill suicide**: `pkill -f protonvpn-app` inside a shell command matches the shell's OWN command line → SIGTERM -15 to yourself, empty output, confusing exit. Always use a non-self-matching regex: `pkill -f 'protonvpn-a[p]p'`.
- **ABRT the right PID**: app launchers are often shell wrappers — pgrep for the `python /usr/bin/...` child.
- **ksecretd vs gnome-keyring**: Plasma 6.4+ runs ksecretd; both compete for org.freedesktop.secrets (first wins). Check `busctl --user list | grep secret` before assuming which backend you're fixing.
- **Password change later**: keyring keeps the OLD password after a login-password change → one unlock prompt per session. Resync via seahorse (Passwords and Keys).
- proton-vpn-gtk-app logs nothing to stdout when hung; after fix, logs flow and `CONN:STATE_CHANGED | Connected` + `proton0` interface + changed exit IP confirm a real tunnel.
- Hermes sandbox may block `sudo pacman -S py-spy` (user denial) — faulthandler+SIGABRT needs no installs, prefer it.

## Verification checklist

- [ ] `get_default_collection` returns instantly, unlocked
- [ ] KWin WINLIST shows the app's window (e.g. `class=proton.vpn.app.gtk`)
- [ ] For VPNs: `ip -brief link` shows tunnel iface + `curl ipinfo.io` shows exit-node IP
