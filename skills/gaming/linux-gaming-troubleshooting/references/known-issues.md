# AAC Launcher Black Screen — Architecture Mismatch (May 2026)

## Problem
Tauri v2 AAC launcher shows black screen and exits instantly on Wine.

## Root Cause
- **Launcher binary**: 32-bit x86 (PE32, Intel i386)
- **EdgeWebView msedge.exe**: 64-bit x64
- Wine's WOW64 cannot bridge 32-bit → 64-bit browser processes

This is a fundamental Wine limitation — the 32-bit Tauri app spawns a COM request for the WebView2 runtime, finds the 64-bit msedge.exe, and fails silently.

## Debug Evidence
- Registry key set correctly: `HKCU\SOFTWARE\Microsoft\EdgeUpdate\Clients\{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}` → correct path to msedge.exe
- WebView2 Runtime installed at: `drive_c/Program Files (x86)/Microsoft/EdgeWebView/Application/148.0.3967.54/`
- Early in debug log: `LdrGetDllHandleEx() retval=c0000135` (STATUS_DLL_NOT_FOUND for mscoree.dll)
- Launcher exits with return code 0 (clean exit, no crash)
- No game process created after launcher exits

## What Was Tried (all failed)
1. `winetricks -q webview2` — verb does not exist
2. Web installer EXE — fails with "Application could not be started, Bad format"
3. Offline EXE installer (198MB) — installs but same architecture mismatch
4. `winetricks -q dotnet45` — installed but doesn't fix 32→64 bridge
5. Registry `WEBVIEW2_BROWSER_EXECUTABLE_FOLDER` env var — didn't help
6. `TAURI_WEBVIEW_BROWSER_PATH` env var — didn't help
7. Proton 11 wine binary — fails to load (Proton wine is 64-bit only, loader is 32-bit)
8. `WINEARCH=win32` + 32-bit WebView2 offline installer — hung indefinitely

## Working Workaround
Skip the launcher entirely — run `wine bin32/archeage.exe` directly.

This loses server authentication from the launcher but the game binary runs fine on Wine 11.8 with no graphical issues when DXVK is properly installed.

## File Locations (October 2025 AAC installer)
- Install path: `drive_c/Program Files/AAClassic/` (NOT `Program Files (x86)`)
- Game exe: `bin32/archeage.exe`
- Game data: `game_pak` (~42GB)
- Launcher: `ArcheAge Classic Launcher.exe` (Tauri 2.11.1, 32-bit, uses Edge WebView2)
- Game version: `version` file contains version number (e.g., "211")
