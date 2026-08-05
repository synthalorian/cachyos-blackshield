---
name: proton-dotnet-troubleshooting
description: Diagnose and fix Proton/Wine .NET assembly load failures (missing System.*.dll) that cause silent crashes in Windows .NET applications running on Linux
category: devops
triggers:
  - proton/wine .NET assembly load failures
  - missing System.*.dll in game Managed folder
  - server process crashes silently without binding ports
  - multiplayer launcher race conditions
---

# Proton/Wine .NET Dependency Troubleshooting

## Problem Pattern
Applications running under Proton/Wine (via Steam on Linux) crash on startup with `FileNotFoundException` for .NET assemblies like `System.Security.Permissions.dll`, `System.Windows.Controls.Ribbon.dll`, etc. The failure is often silent — the launcher falls back to singleplayer mode or the app exits without clear error messages.

Secondary pattern: Server starts successfully but the game still launches in singleplayer because the launcher race-conditions the game start before the server is ready.

## Diagnostic Flow

1. **Check logs first** — Most .NET errors appear in:
   - `~/.config/<AppName>/logs/` (Nitrox: `~/.config/Nitrox/logs/`)
   - Steam console output
   - `~/.steam/steam/logs/` if using Steam Runtime

2. **Look for specific error pattern:**
   ```
   System.IO.FileNotFoundException: Could not load file or assembly 'X'
   Failed to load DLL 'X.dll' at: <path>/Managed/
   ```

3. **Verify the DLL is actually missing:**
   ```bash
   ls "<game_path>/<Game>_Data/Managed/X.dll"
   ```

## Fix: Copy Missing .NET Assemblies

### Step 1: Locate a source for the missing DLL
Sources in order of preference:
- **Unity Editor installation** (most reliable for Unity games):
  `/opt/Unity/Hub/Editor/<version>/Editor/Data/NetStandard/EditorExtensions/`
- **Mono/.NET on Linux**:
  `/usr/lib/mono/<version>/` (e.g., `/usr/lib/mono/4.5/`)
- **Dotnet SDK**:
  `/opt/dotnet/shared/Microsoft.NETCore.App/<version>/`
- **Windows System32** (copy from a Windows install if accessible):
  `C:\Windows\Microsoft.NET\Framework\v4.0.30319\`

### Step 2: Copy to game's Managed folder
```bash
cp <source_dll> "<game_path>/<Game>_Data/Managed/"
```

### Step 3: Set permissions if needed
```bash
chmod 644 "<game_path>/<Game>_Data/Managed/X.dll"
```

## Pitfall: Launcher Race Condition

Even with the DLL fixed, some launchers (Nitrox Launcher, etc.) start the game **before** the server finishes initializing. The game detects no server and locks to singleplayer.

**Symptoms:**
- Server logs show "Server started" and "listening on port"
- Game still launches in singleplayer mode
- Server shuts down after ~30 seconds due to no connections

**Workaround:** Start the server manually first, wait for it to bind, then launch the game.

### Manual sequence:
```bash
# Terminal 1: Start server
/opt/nitrox/Nitrox.Server.Subnautica --save test --embedded
# Wait until log shows: "Server started" and "listening on port"

# Terminal 2: Launch game
steam steam://rungameid/264710 --nitrox /opt/nitrox
```

### Automated wrapper (preferred):
Use a script that:
1. Kills any existing server/game processes
2. Starts the server in background
3. Polls for port 11000 UDP to be bound OR waits for log message
4. Launches the game with correct arguments
5. Traps exit to clean up server

See `templates/nitrox-multiplayer-launcher.sh` for a working example.

## Common Missing DLLs (Known Issues)

| Missing DLL | Source | Notes |
|-------------|--------|-------|
| `System.Security.Permissions.dll` | Unity Editor `EditorExtensions/` | Required by Nitrox server |
| `System.Windows.Controls.Ribbon.dll` | .NET Framework / Windows | Nitrox launcher UI component |
| `System.Configuration.Install.dll` | Mono / .NET | Sometimes needed for installers |

## Verification Checklist

- [ ] Server logs show no `FileNotFoundException` errors
- [ ] Server prints "listening on port <N> UDP" and "Server started"
- [ ] Port is bound: `ss -lnup | grep <port>` (may only show in UDP state)
- [ ] Game launches and connects to server (server console shows player join)
- [ ] No silent fallback to singleplayer

## References
- Session: 2026-05-14 Subnautica Nitrox multiplayer fix
- Root cause: `System.Security.Permissions.dll` missing from Subnautica/Managed
- Fix: Copied from Unity Hub 6000.4.6f1 EditorExtensions to game Managed folder
- Secondary fix: Manual server-first launch to avoid race condition
