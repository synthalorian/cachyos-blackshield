# Browser Theme Deployment — CachyOS machine (verified 2026-08)

How synthwave '84 browser themes are built and deployed on this box, plus the
automation recipes that survived contact with Firefox 153 / Chromium / KWin Wayland.

## Firefox (configs/browsers/firefox/)

Ships `chrome/userChrome.css` (chrome UI), `chrome/userContent.css` (about:* pages
only — never style web content), `user.js` (enables
`toolkit.legacyUserProfileCustomizations.stylesheets`), `chrome/ntp_background.png`
(relative URLs in userContent.css resolve against the profile's `chrome/` dir).

### PITFALL: seeding a profile on a machine where Firefox never ran

Firefox 150+ headless NEVER materializes the install-default profile:
- `firefox --headless about:blank` → runs on a throwaway profile, writes nothing
- `firefox --headless --screenshot ...` → same
- `firefox -CreateProfile name` → exits 0, creates nothing (silently broken)

The ONE working seed: `firefox --headless -profile <tmpdir> about:blank` — an
explicit `-profile` run materializes `installs.ini` AND the hashed install-default
profile dir (e.g. `238t2juz.default-release-1`).

**installs.ini install-hash Default wins over profiles.ini `Default=1`.** A
hand-written profiles.ini entry is ignored; Firefox creates its own
`*-1` suffixed profile on first run and uses that. Deploy targets:
installs.ini `Default=` first, then every `*.default*` dir as fallback.

## Chromium (configs/browsers/chromium/synthwave84/)

Unpacked theme (manifest_version 2 theme + generated NTP art). Chromium blocks
CLI theme installs — no Preferences-file hack survives Secure Preferences HMAC.
Stage at `~/.config/chromium-themes/synthwave84`; user loads via
chrome://extensions → Developer mode → Load unpacked (persists across restarts).

### CDP automation recipe (everything except the native folder dialog)

1. Launch: `chromium --remote-debugging-port=9222 --remote-allow-origins='*'`
   — without allow-origins, websocket handshake is rejected (HTTP 500/403).
2. Targets: GET `http://localhost:9222/json`; open page: PUT `/json/new?chrome://extensions`.
3. chrome://extensions is deep shadow DOM:
   ```js
   const mgr = document.querySelector('extensions-manager');
   const tb = mgr.shadowRoot.querySelector('extensions-toolbar');
   tb.shadowRoot.querySelector('#devMode').click();        // enable dev mode
   tb.shadowRoot.querySelector('#load-unpacked').click();  // opens GTK folder dialog
   ```
4. The folder dialog is NATIVE — CDP cannot fill it. Needs real input (ydotool)
   or the user. Dialog title: "Select the extension directory."

## KWin Wayland input/enumeration notes (this machine)

- `wtype` FAILS on KWin: "Compositor does not support the virtual keyboard
  protocol" (no zwlr_virtual_keyboard_manager_v1). Use `ydotool` (uinput).
- KWin scripting works: `qdbus6 org.kde.KWin /Scripting loadScript <file>` then
  `start`; `print()` output lands in `journalctl --user -u plasma-kwin_wayland`.
  API gotchas: `workspace.outputs` is undefined (use `window.output.geometry`),
  `workspace.sendWindowToOutput` is not a function, and mutating a
  `frameGeometry` copy then assigning it back silently no-ops.

## Blackshield theme deployment map (verified 2026-08-22)

The active browser theme is **Blackshield** (not synthwave84). Every location a
given asset must land — deploy to ALL of them, then verify with md5sum:

**Chromium frame/theme (`blackshield-mercenary`):**
- `~/.config/chromium/Themes/blackshield-mercenary/manifest.json` + `ntp_background.png`
  (the dir Chromium actually loads; `browser.theme.theme_id` in Preferences = `blackshield-mercenary`,
  colors written into `browser.theme.colors` as fallback)
- staged source: `~/.config/chromium-themes/blackshield/` (identical copies)
- repo: `configs/browsers/chromium/blackshield/`
- NTP bg is 1920x1080. Toolbar (active tab + address row, same key) = blood red `[193,18,31]`.

**Chromium NTP override ext (`blackshield-ntp`, manual Load unpacked only):**
- staged: `~/.config/chromium-themes/blackshield-ntp/` (manifest.json + newtab.html + shield.png 950x950)
- repo: `configs/browsers/chromium/blackshield-ntp/`
- path-derived ID: `ikdaoabccfooolibfbpmlccnleenndae`
- newtab.html page bg `#070709`; shield.png crops blend if their bg is near-black.

**Firefox:**
- live profile: `~/.mozilla/firefox/238t2juz.default-release-1/chrome/ntp_background.png` (2560x1440, `cover` in userContent.css)
- repo: `configs/browsers/firefox/chrome/`
- NTP art reloads only at Firefox startup.

**Master art pipeline (2026-08-22):** Krea 2 gen (1376x768) → PIL lanczos cover-crop to
2560x1440 + 1920x1080 → deploy everywhere. Working masters from the reforge session lived in
`/tmp/blackshield-reforge/` (ephemeral — the committed copies in the repo are canonical).
Standalone shield crops: bbox-detect via `max-channel > 45` mask (silver rim + red cross vs
near-black bg), square crop with ~12% padding, lanczos to target size.
