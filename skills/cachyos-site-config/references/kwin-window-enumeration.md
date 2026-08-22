# KWin Window Enumeration via qdbus6 (verified CachyOS, Plasma 6/Wayland, 2026-08)

Use when cua-driver can't see a window (multi-monitor blind spot: it only
enumerates primary-display windows) and you need ground truth about what
exists, where it is, and on which output.

## Enumerate all windows

```bash
cat > /tmp/listwins.js <<'EOF'
const wins = workspace.windowList();
for (const w of wins) {
  const g = w.frameGeometry;
  print(w.resourceClass + " | " + w.caption + " | " + g.x + "," + g.y + " " +
        g.width + "x" + g.height + " | output=" + w.output.name +
        " | min=" + w.minimized + " | active=" + (workspace.activeWindow === w));
}
EOF
qdbus6 org.kde.KWin /Scripting org.kde.kwin.Scripting.loadScript /tmp/listwins.js
qdbus6 org.kde.KWin /Scripting org.kde.kwin.Scripting.start
sleep 1
journalctl --user -u plasma-kwin_wayland --since '-10 seconds' --no-pager | grep '|'
```

Script `print()` output goes to the kwin journal, NOT stdout — always read it
back via journalctl. `loadScript` prints a numeric script id to stdout; `start`
runs the most recently loaded script.

## Gotchas (verified)

- `workspace.sendWindowToOutput(w, "HDMI-A-1")` — **not a function** in this
  KWin's scripting wrapper ("Property 'sendWindowToOutput' ... is not a function").
- kdotool / xdotool: not installed; xdotool wouldn't work on Wayland anyway.
- `qdbus6 org.kde.KWin /KWin org.kde.KWin.queryWindowInfo` only describes the
  ACTIVE window — useless for finding hidden/secondary-monitor windows.
- `w.output.name` gives the connector (HDMI-A-1 / HDMI-A-2). On this box,
  HDMI-A-1 = primary, HDMI-A-2 = secondary.
- Verified window properties: `resourceClass`, `caption`, `frameGeometry`
  (x/y/width/height), `desktops` (array), `minimized`, `output`,
  `workspace.activeWindow`, `workspace.outputs` (with `.geometry`).

## Session evidence (2026-08)

Chromium ran with 19 processes, KWin showed its window alive on HDMI-A-2
("Gmail - Chromium", 0,0 1920x1034, not minimized), while cua-driver's
list_windows returned only the two primary-display windows (Albion, OpenClaw).
Diagnosis confirmed via the script above; the cross-monitor window MOVE was
not completed in-session, so no verified recipe for that yet.
