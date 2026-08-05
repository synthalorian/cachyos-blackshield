# WebView2 Runtime Installation for AAC Launcher

## Problem
The ArcheAge Classic Launcher.exe requires Microsoft Edge WebView2 Runtime. On Windows this is typically pre-installed. Under Wine, it must be installed manually.

## Failed Approaches

### 1. `winetricks webview2`
**Status:** Verb does not exist in winetricks.

### 2. Web Installer (tiny stub ~2MB)
**Status:** Fails with `Application could not be started, or no application associated with the specified file.`
The stub downloader invokes external HTTPS processes that Wine doesn't handle properly.

### 3. Wrong standalone URL
Some Microsoft WebView2 download URLs look like standalone installers but are actually web stubs.

## Working Approach

Use the **Microsoft Edge WebView2 Runtime Evergreen Standalone Installer for Windows X64**:

```bash
export WINEPREFIX="$HOME/Games/ArcheAgeClassic/Prefix"

URL="https://msedge.dl.delivery.mp.microsoft.com/filestreamingservice/files/304fddef-b073-4e0a-b1ff-c2ea02584017/MicrosoftEdgeWebView2RuntimeInstallerX64.exe"
wget -q "$URL" -O /tmp/webview2.exe
wine /tmp/webview2.exe
```

**Expected behavior:** A GUI installer window appears. It runs silently (no clicks needed) and exits with 0 on success.

**Verification:**
```bash
export WINEPREFIX="$HOME/Games/ArcheAgeClassic/Prefix"
ls "$WINEPREFIX/drive_c/Program Files (x86)/Microsoft/EdgeWebView/" 2>/dev/null && echo "Installed!" || echo "Check other paths"
# May also be under: $WINEPREFIX/drive_c/windows/system32/WebView2/
```

## Notes
- The URL may change over time. If the download returns a 404, grab the latest standalone installer URL from: https://developer.microsoft.com/en-us/microsoft-edge/webview2/#download-section
- File size should be ~150MB (not ~2MB like the web stub)
- Install AFTER winetricks deps, BEFORE running the AAC launcher
