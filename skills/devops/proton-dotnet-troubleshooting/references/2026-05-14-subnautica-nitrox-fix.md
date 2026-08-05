# Session: 2026-05-14 Subnautica Nitrox Multiplayer Fix

## Error Transcript

### Server crash log (before fix)
```
Unhandled exception. System.IO.FileNotFoundException: Could not load file or assembly 'System.Security.Permissions, Version=0.0.0.0, Culture=neutral, PublicKeyToken=cc7b13ffcd2ddd51'. The system cannot find the file specified.

File name: 'System.Security.Permissions, Version=0.0.0.0, Culture=neutral, PublicKeyToken=cc7b13ffcd2ddd51'
 ---> System.IO.FileNotFoundException: Could not load file or assembly 'System.Security.Permissions, Version=0.0.0.0, Culture=neutral, PublicKeyToken=cc7b13ffcd2ddd51'. The system cannot find the file specified.

File name: 'System.Security.Permissions, Version=0.0.0.0, Culture=neutral, PublicKeyToken=cc7b13ffcd2ddd51'
 ---> System.IO.FileNotFoundException: Failed to load DLL 'System.Security.Permissions.dll' at: /home/synth/.local/share/Steam/steamapps/common/Subnautica/Subnautica_Data/Managed/System.Security.Permissions.dll
```

### Launcher log showing race condition
```
[15:07:24.235] [INF] Launching Subnautica in singleplayer mode   ← First launch, no server yet
[15:07:53.254] [INF] Starting server:                           ← Server starts 30s later
[15:07:59.085] [INF] Launching Subnautica in multiplayer mode    ← Second launch, but game instance already running in SP
[15:08:32.797] [INF] [BROADCAST] Server is shutting down...      ← Server quits after no connections
```

## Proven Fix Steps

1. **Copy missing DLL** from Unity installation to game Managed folder:
   ```bash
   cp /home/synth/Unity/Hub/Editor/6000.4.6f1/Editor/Data/NetStandard/EditorExtensions/System.Security.Permissions.dll \
      /home/synth/.local/share/Steam/steamapps/common/Subnautica/Subnautica_Data/Managed/
   ```

2. **Start server manually BEFORE launching game:**
   ```bash
   /opt/nitrox/Nitrox.Server.Subnautica --save test --embedded
   # Wait for: "Server started" and "listening on port 11000 UDP"
   # Then launch game via Steam
   ```

3. **Or use wrapper script** that sequences start → wait → launch (see template).

## Key Learnings

- Proton's Wine environment does NOT include full .NET Framework; Unity games ship only game-specific assemblies.
- Nitrox server depends on `System.Security.Permissions.dll` which is NOT in Subnautica's Managed folder by default.
- Unity Hub installations contain the required DLLs in `EditorExtensions/` — compatible for copying.
- Launcher race condition: Nitrox Launcher tries to launch game before server ready → SP fallback lock.
- Port 11000 UDP may not show in `ss -tlnp` (TCP-only flag); use `ss -lnup` or rely on server log confirmation.
- `killall -9 Nitrox.Server.Subnautica; killall -9 Nitrox.Launcher; pkill -f Subnautica.exe` cleans stuck processes.

## Environment Details

- **OS:** Omarchy (Arch + Hyprland)
- **Steam:** ~/.local/share/Steam
- **Subnautica path:** ~/.local/share/Steam/steamapps/common/Subnautica
- **Nitrox:** AUR install at /opt/nitrox (Nitrox 1.8.1.0)
- **Unity source:** /home/synth/Unity/Hub/Editor/6000.4.6f1/
- **Proton:** Experimental (via Steam Runtime pressure-vessel sandbox)
