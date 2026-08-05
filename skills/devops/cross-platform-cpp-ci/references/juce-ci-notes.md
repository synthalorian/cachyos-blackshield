# JUCE CI + Packaging Notes

JUCE-specific detail for cross-platform builds and release packaging. Earned on the Open Synth v2.0.2 pipeline (2026-07-25).

## JUCE dependency setup in CI

- JUCE is often NOT a git submodule in projects that use a local `~/.juce`. In CI: `git clone --depth 1 --branch 8.0.12 https://github.com/juce-framework/JUCE.git "$RUNNER_TEMP/JUCE"` then `cmake -DJUCE_DIR="$RUNNER_TEMP/JUCE"`. Pin the tag to whatever the project's local JUCE reports (`git -C ~/.juce describe --tags`).
- `clap-juce-extensions` (if used for CLAP) has nested submodules (`clap-libs/clap`, `clap-libs/clap-helpers`) — always `git submodule update --init --recursive libs/clap-juce-extensions`.
- Sample/asset libraries can be 1GB+ — checkout only on tag builds.

## Icons / branding pipeline

- CMake: `juce_add_gui_app(... ICON_BIG assets/icon_1024.png ICON_SMALL assets/icon_512.png)` — JUCE generates `.ico` (Windows), `.icns` (macOS), and embeds the Linux icon AT BUILD TIME. Changing icon art requires a rebuild on every platform.
- GitHub repo social preview has NO REST endpoint (`PUT/POST /repos/{owner}/{repo}/social-preview` → 404). Manual upload: repo Settings > General > Social preview. Prepare a 1280×640 center-crop (PIL: crop square to 2:1 then `resize((1280,640), Image.LANCZOS)`).

## Linux desktop icon association (JUCE runs XWayland, not native Wayland)

Blank/generic taskbar tile = window↔desktop-file association failure, NOT a build problem.

1. Get the window's WM_CLASS: `DISPLAY=:0 xprop -root _NET_CLIENT_LIST` for window IDs, then `DISPLAY=:0 xprop -id <id> WM_CLASS` (JUCE emits e.g. `"Open Synth", "Open Synth"` — instance AND class, space included).
2. Desktop file must declare `StartupWMClass=<exact WM_CLASS string>` and `Icon=<name>` matching an icon installed to `~/.local/share/icons/hicolor/<size>/apps/<name>.png`.
3. `desktop-file-validate` the file, then `kbuildsycoca6 --noincremental` and `plasmashell --replace` (KDE) to pick up changes.
4. `xlsclients` isn't always installed; `xprop -root _NET_CLIENT_LIST` + per-window xprop is the portable path.
5. Vision fallback: a generic empty rounded-square in the panel = placeholder; KDE Plasma's own fallback. If the user pins a launcher before the icon exists, Plasma caches the missing icon — unpin/re-pin.

## Packaging per OS

- Linux: `tar -czf dist/app-linux-standalone.tar.gz -C <artefacts>/Standalone .` (samples are copied into artefact dirs by CMake POST_BUILD, so packaging the dir bundles them).
- macOS: `zip -r` works in bash.
- Windows: NO zip in Git Bash → pwsh `Compress-Archive -Path "$art/VST3/App.vst3" -DestinationPath dist/app-win-vst3.zip`.
- Multi-config generators (VS/Xcode) put test binaries in `build/Release/`.
