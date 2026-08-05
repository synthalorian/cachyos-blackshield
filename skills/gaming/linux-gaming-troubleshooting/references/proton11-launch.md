# Proton 11 Launch Configuration for ArcheAge Classic

## Proton 11 Location

```
~/.local/share/Steam/steamapps/common/Proton 11.0/
├── files/
│   ├── bin/
│   │   └── wine          (no wine64 — just wine)
│   │   └── wineserver
│   │   └── msidb -> wine
│   ├── lib/              (32-bit libs)
│   └── lib64/            (64-bit libs)
└── version: proton-11.0-1-beta3 (Wine 11.0)
```

## Launch Script (run_proton11.sh)

Location: `~/Games/ArcheAgeClassic/run_proton11.sh`

```bash
#!/bin/bash
proton_wine="$HOME/.local/share/Steam/steamapps/common/Proton 11.0/files/bin/wine"
prefix="$HOME/Games/ArcheAgeClassic/Prefix"

export WINEPREFIX="$prefix"
export WINEESYNC=1
export WINEFSYNC=1

launcher_dir="$prefix/drive_c/Program Files (x86)/ArcheRage.to NA"
cd "$launcher_dir"
exec "$proton_wine" Launcher.exe 0
```

## Install Directory

The AAC installer (aaclassic-installer.exe) installs to:
`<WINEPREFIX>/drive_c/Program Files (x86)/ArcheRage.to NA/`

NOT "ArcheAge" or "ArcheAgeClassic" — the .exe contains "ArcheRage.to NA".

## Environment Variables

```bash
export WINEESYNC=1     # ESYNC (eventfd-based sync, better performance)
export WINEFSYNC=1     # FSYNC (futex-based sync, Linux 5.16+)
# export DXVK_HUD=fps  # Uncomment for FPS overlay
```

## Why Proton 11 Over Vanilla Wine

- Valve's DXVK has CryEngine-specific shader fixes
- Better VKD3D shader compilation
- Patched D3D11 handling that fixes the shading/texture bugs
- Uses Wine 11.0 (not 11.8) but the DXVK patches matter more than the Wine version

## Installed Winetricks Packages

```
corefonts gdiplus vcrun2010 dxvk d3dcompiler_42 d3dcompiler_43 d3dcompiler_46 d3dcompiler_47
```
