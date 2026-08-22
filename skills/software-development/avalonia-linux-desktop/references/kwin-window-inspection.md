# KWin Window Inspection (app_id / class / desktop file)

When a Wayland/X11 window won't get the right icon, theme, or window-rule match, inspect what KWin actually sees. `supportInformation` does NOT list windows — use the scripting console.

## Dump all windows

```bash
cat > /tmp/dumpwindows.js <<'EOF'
var wins = workspace.windowList();
for (var i = 0; i < wins.length; i++) {
    var w = wins[i];
    print("DUMPWIN | caption=" + w.caption + " | resourceClass=" + w.resourceClass +
          " | resourceName=" + w.resourceName + " | desktopFile=" + w.desktopFileName);
}
EOF
export DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus
qdbus6 org.kde.KWin /Scripting org.kde.kwin.Scripting.loadScript /tmp/dumpwindows.js dumpwin
qdbus6 org.kde.KWin /Scripting org.kde.kwin.Scripting.start
sleep 2
journalctl -b _COMM=kwin_wayland --no-pager --since "-10s" | grep DUMPWIN
```

Interpretation:
- `resourceClass` empty on Wayland → app never called `set_app_id` → icon matching impossible (Avalonia Wayland backend does this; use its X11 backend instead).
- `resourceClass=Foo` + `desktopFile=` empty → KWin found no desktop file whose name or `StartupWMClass` matches `Foo`.
- `desktopFile=<name>` filled → icon chain works; icon comes from `Icon=` in `<name>.desktop`.

## Activate/raise a window by caption

```js
var wins = workspace.windowList();
for (var i = 0; i < wins.length; i++)
    if (wins[i].caption === "My App") workspace.activeWindow = wins[i];
```
Load/run the same way. Useful for screenshots of background windows (`spectacle -b -n -a` = active window).

## Reflecting on Avalonia/dotnet DLLs (API discovery)

NuGet DLLs fail `Assembly.LoadFrom` with dependency errors. Run from the app's own bin dir with a resolver:

```csharp
var appDir = "/path/to/app/bin/Release/net10.0/";
AssemblyLoadContext.Default.Resolving += (ctx, name) => {
    var p = Path.Combine(appDir, name.Name + ".dll");
    return File.Exists(p) ? ctx.LoadFromAssemblyPath(p) : null;
};
var asm = Assembly.LoadFrom(Path.Combine(appDir, "Avalonia.Wayland.dll"));
```

Cheap pre-check: `strings <dll> | grep -i appid` — `AVALONIA_APP_ID` was ruled out this way in seconds before touching source.
