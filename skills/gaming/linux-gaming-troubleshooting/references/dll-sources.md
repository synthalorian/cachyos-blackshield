# Where to find a working System.Security.Permissions.dll on Arch Linux

The Nitrox server needs the **full implementation** of `System.Security.Permissions.dll` (not the reference assembly from NuGet). The DLL must be ≥100KB and contain the constructor `SecurityPermission(PermissionState)` that Newtonsoft.Json calls via reflection.

## Proven Sources (in order of preference)

### 1. PowerShell 7 Wine prefix (most reliable)
If you have any Windows game installed via Wine/Proton that includes PowerShell 7, it almost certainly contains the right DLL:

```bash
# Search all Wine prefixes for the file
find ~/Games -name "System.Security.Permissions.dll" -type f 2>/dev/null
find ~/.wine -name "System.Security.Permissions.dll" -type f 2>/dev/null 2>&1
```

Typical location:
```
~/Games/<game>/drive_c/Program Files/PowerShell/7/System.Security.Permissions.dll
~/.wine/drive_c/Program Files/PowerShell/7/System.Security.Permissions.dll
```

Expected: **183KB**, version 8.0.0.0 (or higher).

### 2. .NET SDK installation
If you have the full .NET SDK installed (not just runtime):

```bash
find /usr/share/dotnet -name "System.Security.Permissions.dll" | head -5
```

Look under packs:
```
/usr/share/dotnet/packs/Microsoft.NETCore.App.Ref/8.0.0/ref/net8.0/System.Security.Permissions.dll  # reference only — too small
/usr/share/dotnet/shared/Microsoft.NETCore.App/8.0.0/System.Security.Permissions.dll  # runtime — correct size
```

**Caution**: The `Ref` folder contains reference assemblies (metadata only, ~24KB). You want the `shared` folder runtime DLL (180KB+).

### 3. Download from Microsoft (if no local source)
You can extract it from the .NET 8 runtime NuGet package:

```bash
cd /tmp
curl -L -O https://www.nuget.org/api/v2/package/Microsoft.NETCore.App.Runtime.linux-x64/8.0.0
# Extract and find the DLL inside (requires unzip/bsdtar)
```

But this is more complex than using an existing Wine prefix.

### 4. From another Steam game that uses .NET
Some Windows games on Steam bundle .NET runtime DLLs. Check:
- Subnautica: Below Zero (may have it already)
- Other Unity games with modding support
- Games with in-game browsers or .NET plugins

Search your Steam library:
```bash
find ~/.local/share/Steam/steamapps/common -name "System.Security.Permissions.dll" 2>/dev/null
```

## What NOT to Use

❌ **NuGet `System.Security.Permissions` package** — reference assembly only (~24KB), no implementation. Will throw `MissingMethodException` at runtime.

❌ **Unity's version** (from Unity 2024's `System.Security.Permissions.dll` v6.0.0.0) — wrong constructor signature. Leads to `MissingMethodException: No constructor found`.

❌ **Mono's version** — GAC version may be outdated and incompatible.

❌ **Any DLL < 100KB** — almost certainly a reference assembly.

## Verification

After copying the DLL to Subnautica's Managed folder:

```bash
file ~/.local/share/Steam/steamapps/common/Subnautica/Subnautica_Data/Managed/System.Security.Permissions.dll
# Should say: "PE32+ executable (DLL) (console) x86-64, for MS Windows"

ls -lh ~/.local/share/Steam/steamapps/common/Subnautica/Subnautica_Data/Managed/System.Security.Permissions.dll
# Should be ~180-200KB

# Test server startup
~/Games/nitrox/Nitrox.Server.Subnautica --save test --embedded
# Should print "Server started" without exceptions
```

## Backup Strategy

Once you have a working DLL, save a copy to your Nitrox directory so Steam updates don't wipe it:

```bash
mkdir -p ~/Games/nitrox
cp /path/to/working/System.Security.Permissions.dll ~/Games/nitrox/System.Security.Permissions.dll.backup
```

The launcher script automatically checks and restores this DLL before each run.

## Why This Is Needed

Nitrox server (`.NET 9`) uses `System.Security.Permissions` through Newtonsoft.Json's reflection for legacy Unity serialization. .NET 5+ removed CAS (Code Access Security) from the default runtime; the types are in a separate assembly that's not included by default. Subnautica's Unity installation doesn't ship it. You get a `FileNotFoundException` or `MissingMethodException` if it's missing or wrong version.

Workaround: Drop the DLL into Subnautica's `Managed/` folder where the game's AppDomain will probe for assemblies. Works because Nitrox server shares the same `PATH`/`LD_LIBRARY_PATH` context when launched from the game's directory.
