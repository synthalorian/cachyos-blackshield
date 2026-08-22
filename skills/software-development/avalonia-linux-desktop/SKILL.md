---
name: avalonia-linux-desktop
description: Use for Avalonia .NET desktop apps on Linux/KDE.
---

# Avalonia Desktop Apps on Linux (KDE/Wayland)

Verified techniques from the AlbionOnline-Companion project (Avalonia 12.1.1, .NET 10, CachyOS/KDE Plasma Wayland). Covers window icons, packet-capture privileges, embedded fonts, launchers, and API pitfalls.

## 1. Window/taskbar icon on Wayland: use the X11 backend

**Root cause (verified against Avalonia 12.1.1 source):** the Wayland backend NEVER calls `xdg_toplevel.set_app_id`. With an empty app_id, KWin cannot match the window to any `.desktop` file → generic "W" Wayland icon in titlebar and taskbar, no matter how well icons are installed. The `AVALONIA_APP_ID` env var is a placebo — it does not exist in the Wayland backend.

**Fix:** force the X11 backend (Xwayland) and set WmClass explicitly:

```csharp
builder = builder.UseX11()
    .With(new Avalonia.X11PlatformOptions { WmClass = "AlbionOnlineCompanion" });
```

X11 `WM_CLASS` defaults to the entry assembly name; KWin matches it via `StartupWMClass=` in the desktop file → `Icon=` resolves. Verify with the KWin scripting dump (see references/kwin-window-inspection.md): you want `resourceClass=<WmClass>` and `desktopFile=<desktop-file-basename>`.

**Full icon chain checklist:**
- PNGs at every size in `~/.local/share/icons/hicolor/<N>x<N>/apps/<icon-name>.png` AND system-wide `/usr/share/icons/hicolor/...` + `/usr/share/pixmaps/` (root/pkexec windows only see `/usr/share`)
- `.desktop` file in both `~/.local/share/applications/` and `/usr/share/applications/`
- `Icon=<icon-name>` (no extension) and `StartupWMClass=<WmClass>` in the desktop file
- `kbuildsycoca6 --noincremental` after installing

## 2. Packet capture without root: setcap + self-healing launcher

Raw-socket/libpcap capture needs privileges. Instead of running the GUI as root (breaks Wayland auth, themes, icon paths):

```bash
sudo setcap 'cap_net_raw,cap_net_admin=eip' /path/to/apphost-binary
```

**Pitfall:** capabilities live on the file inode — `dotnet build` OVERWRITES the binary and wipes them. Use a self-healing launcher (templates/setcap-launcher.sh) that checks `getcap` and re-applies via `pkexec setcap` if missing, then `exec`s the binary.

Running as root on a user Wayland session also fails with "Authorization required, but no authorization protocol specified" (XAUTHORITY mismatch). The user session's XAUTHORITY lives at `/run/user/1000/xauth_*` — grab it from `/proc/$(pgrep plasmashell | head -1)/environ` when launching X11 apps from a non-session shell (e.g. Hermes terminal). `XOpenDisplay failed` from a detached shell = missing XAUTHORITY, not missing DISPLAY.

## 3. Embedded fonts (avares)

- Ship TTFs in `Assets/Fonts/`, ensure `<AvaloniaResource Include="Assets\**" />` in csproj
- Single file: `avares://<AssemblyName>/Assets/Fonts/Font.ttf#FontName` (assembly name = `<AssemblyName>` in csproj, NOT root namespace or csproj filename)
- Folder family with weight variants: `avares://<AssemblyName>/Assets/Fonts/#Family Name` — picks Regular/Bold/Italic automatically
- App-wide default font: set `FontFamily` on a `Style Selector="Window"` (inherits down the visual tree); override with class styles (`TextBlock.header` etc.)
- Font pairing that won user approval: Cinzel (headers, medieval/Roman caps) + EB Garamond (body). Orbitron was rejected — user wants synthwave-medieval, not sci-fi geometric. Get static TTFs from gwfh.mranftl.com API.

## 4. Process management + Avalonia 12 API pitfalls

- `pkill -f <name>` matches YOUR OWN shell's command line if the name appears in the script text → kills your own terminal command. Use `pkill -x <comm>` (note: comm is truncated to 15 chars, e.g. `AlbionOnlineCom`).
- Avalonia 12 clipboard: `Avalonia.Input.Platform.ClipboardExtensions.SetTextAsync(clipboard, text)` — NOT `IClipboard.SetTextAsync` (doesn't exist) and NOT `Avalonia.Input.ClipboardExtensions`.
- Avalonia 12 app entry: `BuildAvaloniaApp().StartWithClassicDesktopLifetime(args, ShutdownMode.OnLastWindowClose)` — there is no `AppBuilder.Start(lifetime)` overload.
- Reflecting on Avalonia DLLs to find APIs: load from the app's bin dir with an `AssemblyLoadContext.Default.Resolving` handler pointing at that dir (nuget DLLs alone fail with dependency load errors). See references/kwin-window-inspection.md for the pattern.

## 5. Free translation via Google gtx endpoint

See references/google-translate-gtx.md — endpoint format, why `sl=auto` beats local detection, response parsing.

## References & templates

- `references/kwin-window-inspection.md` — dump window app_id/class/desktopFile via KWin scripting console + journalctl; DLL reflection pattern
- `references/google-translate-gtx.md` — gtx endpoint details, response parsing, rate-limit notes
- `references/albion-chat-channel-ids.md` — verified Albion Online chat channel IDs (Companion translator)
- `templates/setcap-launcher.sh` — self-healing setcap launcher script
