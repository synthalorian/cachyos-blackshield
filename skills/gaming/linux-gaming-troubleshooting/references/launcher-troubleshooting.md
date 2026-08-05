# Known Issue: Tauri v2 Launcher Architecture Mismatch (May 2026)

## Symptoms
- Launcher exits immediately with Return code 0 (clean exit, NOT crash)
- Game binary (`bin32/archeage.exe`) works fine independently
- Game is installed correctly (v211, 42GB game_pak intact)

## Root Cause
**October 2025 AAC installer shipped a new Tauri v2 launcher.**

| Component | Architecture | Notes |
|-----------|-------------|-------|
| `ArcheAge Classic Launcher.exe` | x86 (32-bit) | PE32, Intel i386 |
| `EdgeWebView/msedge.exe` | x64 (64-bit) | PE32+, AMD64 |
| Wine WOW64 | Partial bridge | Cannot bridge 32-bit app to 64-bit renderer process |

Wine cannot bridge a 32-bit app to a 64-bit child browser process. **This is a fundamental Wine limitation.**

## What Was Tested (All Failed)
1. WebView2 64-bit — Installed but architecture mismatch
2. WebView2 32-bit — Installer hangs/times out under Wine
3. Edge Browser (full x86) — Download/install failed
4. .NET Runtime (dotnet45) — Installed, mscoree.dll exists, didn't fix
5. Proton 11 via `proton run` — Same instant exit
6. Environment variables / registry keys — No effect
7. Direct game launch — Works but NO server auth (useless)

## What IS Working
- `dotnet45` installed via winetricks: `mscoree.dll` in system32/syswow64 ✅
- WebView2 64-bit installed: `drive_c/Program Files (x86)/Microsoft/EdgeWebView/Application/148.0.3967.54/` ✅
- `bin32/archeage.exe` launches fine (v211) ✅

## Potential Fixes (Untested)
1. Install **32-bit Edge browser** (x86 MSI) — provides matching architecture
2. Use **Bottles** — dedicated Wine manager with better WebView2 support
3. Add launcher as **Non-Steam Game** with Proton compatibility
4. Request the **older AAC installer** (pre-October 2025, Wine-compatible launcher)
5. Wait for Archerage to fix or update the launcher

## CRITICAL RULE
**NEVER suggest bypassing the launcher.** The user needs it for server authentication. The launcher is not optional.
