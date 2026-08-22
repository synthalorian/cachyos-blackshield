// KWin script: dump every window's caption, resourceClass (app_id), resourceName,
// and resolved desktopFile to the kwin_wayland journal.
// Usage:
//   qdbus6 org.kde.KWin /Scripting org.kde.kwin.Scripting.loadScript kwin-dump-windows.js dump
//   qdbus6 org.kde.KWin /Scripting org.kde.kwin.Scripting.start
//   journalctl -b _COMM=kwin_wayland --no-pager --since "-5s" | grep DUMPWIN
var wins = workspace.windowList();
for (var i = 0; i < wins.length; i++) {
    var w = wins[i];
    print("DUMPWIN | caption=" + w.caption + " | resourceClass=" + w.resourceClass + " | resourceName=" + w.resourceName + " | desktopFile=" + w.desktopFileName);
}
