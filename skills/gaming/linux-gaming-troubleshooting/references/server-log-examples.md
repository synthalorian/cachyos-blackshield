# Nitrox Server Log Patterns — What Success and Failure Look Like

All logs stored in: `~/.config/Nitrox/logs/server[<save>]-<YYYYMMDD>.log`

## Successful Startup (What You Want to See)

```
[10:15:23 INFO] Nitrox Server version 2024.10.0 starting...
[10:15:23 INFO] Configuration loaded from /home/user/.config/Nitrox/server.cfg
[10:15:24 INFO] Initializing network subsystem...
[10:15:24 INFO] Listening on 0.0.0.0:11000 (UDP)
[10:15:25 INFO] Database initialized
[10:15:26 INFO] All systems nominal
[10:15:26 INFO] Server started — awaiting connections.
```

**Key phrase**: `Server started` (this is what the launcher script waits for).

## Common Failure Modes

### 1. Missing System.Security.Permissions.dll (no backup, first run)
```
[10:20:01 ERR] An error occurred while starting the server.
System.IO.FileNotFoundException: Could not load file or assembly 'System.Security.Permissions, Version=8.0.0.0, Culture=neutral, PublicKeyToken=b03f5f7f11d50a3a' or one of its dependencies.
   at Nitrox.Server.Subnautica.Program.Main(String[] args)
```
**Fix**: Place working DLL in Managed folder (see skill main doc).

### 2. Reference assembly used instead of runtime (24KB NuGet DLL)
```
[10:22:15 ERR] Method not found: 'Void System.Security.Permissions.SecurityPermission::.ctor(System.Security.Permissions.PermissionState)'.
   at Newtonsoft.Json.Serialization.DefaultContractResolver..ctor()
   at Nitrox.Server..ctor()
   at Nitrox.Server.Subnautica.Program.Main(String[] args)
```
**Fix**: Replace with full implementation DLL (~180KB).

### 3. Version mismatch (Unity 6.0 DLL)
```
[10:25:40 ERR] Method not found: 'Void System.Security.Permissions.SecurityPermission::.ctor(System.Security.Permissions.PermissionState, Boolean)'.
   ...
```
**Fix**: Use DLL from .NET 8+ runtime, not Unity's older version.

### 4. Port already in use
```
[10:30:05 WRN] Failed to bind to port 11000: Address already in use
[10:30:05 ERR] Network initialization failed. Aborting.
```
**Fix**: Kill existing Nitrox server or change port in `server.cfg`.

### 5. Path/sandboxing issue (Nitrox in /opt)
```
[10:35:10 ERR] Could not find Nitrox data directory. Launcher aborted.
```
**Fix**: Move Nitrox to home directory (`~/Games/nitrox`).

## What the Launcher Checks

The script greps for the **exact string** `Server started`. It does NOT rely on:
- Exit codes (server runs as daemon)
- UDP port appearing in `ss` (may be delayed, and `-t` only shows TCP)
- Process existence alone (server may be starting/initializing)

## Tail the Log While Testing

```bash
# In one terminal, watch the log in real-time
tail -f ~/.config/Nitrox/logs/server[test]-*.log

# In another, launch the game via the script
~/bin/launch-subnautica-multiplayer
```

Look for these post-launch entries to confirm client connection:
```
[10:42:15 INFO] Client connected from 127.0.0.1:54321 (Subnautica)
[10:42:15 INFO] Player joined: Player (ID: 1234)
```

If you see `Client authenticated` and `Player joined`, multiplayer is working.

## Log File Rotation

Logs are named by date: `server[<save>]-<YYYYMMDD>.log`. If you get "Server started" on a previous day's log but not today's, the server may be reading an old config pointing to a deleted save. Delete old logs and try again.

## Deeper Debugging

To increase verbosity, add to `server.cfg`:
```ini
[Logging]
LogLevel=Debug
```
Then restart server. You'll see assembly binding logs:
```
[10:50:01 DBG] Assembly load: System.Security.Permissions from /home/user/.../Managed/
```

That confirms the DLL is being found.
