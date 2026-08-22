---
name: browser-theming
description: Use when theming Firefox/Chromium to the system palette.
version: 1.0.0
tags: [linux, firefox, chromium, theming, synthwave]
---

# Browser Theming (Linux)

**SCOPE RULE (user-corrected 2026-08-22): "change the shield/art for Firefox/Chromium" means the browser THEME art (NTP background, frame colors, theme-extension assets) — NEVER the application icons.** Do not touch `~/.local/share/icons/hicolor/*/apps/{firefox,chromium}.png` or create `.desktop` `Icon=` overrides unless the user explicitly asks for the app icon itself to change. App-icon work is the KDE icon layer's job. If a request mixes "browser + launcher icon", the launcher icon is the only icon in scope; when genuinely ambiguous, ask before touching icons. Reverting an unwanted icon swap = delete the hicolor pngs + the `.desktop` overrides, `kbuildsycoca6 --noincremental`, `plasmashell --replace`.

Class playbook for theming browsers to match the system stack (KDE/Ghostty/Limine/Plymouth).
Canonical live assets: `~/Projects/active/cachyos-blackshield/configs/browsers/`
(deployed by that repo's `./install.sh browsers` phase).

## synthwave '84 palette canon

bg `#240037` · deep `#0D0221` · fg `#FF7EDB` · magenta `#FF00FF` · purple `#8F00FF`
· mid-purple `#4B0080` · cyan `#03EDF9` · green `#72F1B8` · yellow `#F3E70F`
· red `#FE4450` · dim-fg `#B57EDB`. Selected-tab convention (from kitty/Ghostty):
active tab = fg pink on purple bg, i.e. light text swaps to dark bg `#240037`.

## Firefox

Three files per profile: `chrome/userChrome.css` (browser UI), `chrome/userContent.css`
(about:* pages ONLY — never style web content), `user.js` with
`user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);` — without
that pref both CSS files are silently ignored.

- Relative URLs in userContent.css resolve against the profile's `chrome/` folder —
  ship NTP art as `chrome/ntp_background.png` and reference `url("ntp_background.png")`.
- Useful Firefox system CSS vars: `--toolbar-bgcolor`, `--arrowpanel-background`,
  `--urlbar-box-bgcolor`, `--toolbarbutton-hover-background`, `--lwt-sidebar-background-color`,
  `--tab-loading-fill`. Setting these themes native menus/panels/sidebars in one stroke.
  **Pitfall — arrowpanel border leaks into URL bar:** `--arrowpanel-border-color` is read by
  Firefox's internal chrome CSS for the UNSELECTED urlbar state. Setting it to a warm accent
  (ember `#E5383B`, blood `#C1121F`, pink) gives the unfocused address bar a pink/ember border.
  Use `--bs-steel` (`#26262E`) or `--bs-border` for `--arrowpanel-border-color`; keep warm accents
  on `#urlbar[focused]`-scoped rules, panel borders, and tab accents only.
- Selected tab styling: `.tabbrowser-tab[selected] .tab-background`; urlbar focus glow:
  `#urlbar[focused] > #urlbar-background` with magenta border + box-shadow.
- Restart Firefox to apply; no runtime reload.
- **Launching the user's Firefox from the agent shell (KDE Wayland, verified 2026-08-22):** bare `firefox` dies with `Error: no DISPLAY environment variable specified`. Needs the full session env: `XAUTHORITY=$(ls /run/user/1000/xauth_* | head -1) WAYLAND_DISPLAY=wayland-0 XDG_RUNTIME_DIR=/run/user/1000 DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus MOZ_ENABLE_WAYLAND=1 firefox` (terminal background=true, no nohup wrapper).
- **Pitfall — `~/.mozilla/extensions/<name>/chrome/` dirs are inert red herrings:** a loose
  `chrome/userChrome.css` under `~/.mozilla/extensions/` WITHOUT a `manifest.json` is never
  loaded by Firefox — it's not an extension, just files on disk. If the profile's deployed
  CSS is correct but the render still shows the old styling, the cause is almost always
  "Firefox hasn't been restarted since the deploy" (chrome CSS is read once at startup), not
  a cascade fight with the inert dir. Verify the deployed file's mtime vs the running
  process's start time before hunting phantom overrides. Still fix the stale copy (or delete
  the dir) so it can't confuse the next diagnostic pass.
- **Pitfall — repo/live drift re-breaks on next install:** if the live profile CSS was
  hot-fixed (e.g. `--arrowpanel-border-color: var(--bs-steel)`) but the repo source under
  `configs/browsers/firefox/` still has the old value, the next `install.sh browsers` run
  redeploys the bug. Always diff repo vs live after a hot-fix and patch the repo to match.

### PROFILE SEEDING (verified Firefox 153, CachyOS) — the big pitfall

Firefox headless is useless for creating the real profile:
- `firefox --headless about:blank` and `--headless --screenshot` run on a THROWAWAY
  temp profile — `~/.mozilla/` is never created.
- `firefox -CreateProfile <name>` exits 0 and creates NOTHING (no output, no dir).
- Hand-made `profiles.ini` with `Default=1` is IGNORED: `installs.ini`'s
  install-hash `Default=` wins over profiles.ini precedence.

**What works:** `timeout 25 firefox --headless -profile <any-temp-dir> about:blank`
materializes `~/.mozilla/firefox/installs.ini` AND the install-default profile dir
(`<hash>.default-release-1`). Deploy recipe: parse installs.ini `Default=` first,
then fall back to every `*.default*` dir; deploy chrome/ + append user.js (guard with
a marker grep) into each. Full transcript: `references/firefox-profile-seeding.md`.

## Chromium

- Themes are manifest-v2 extension dirs: `{"manifest_version": 2, "theme": {"images": ...,
  "colors": {...RGB arrays...}, "tints": {...}, "properties": {...}}}`.
  Working color keys: `frame`, `frame_inactive`, `toolbar`, `tab_text`,
  `tab_background_text`, `bookmark_text`, `ntp_background`, `ntp_text`, `ntp_link`,
  `button_background`, `omnibox_text`, `omnibox_background`,
  `omnibox_results_background_selected`, `detached_bookmark_bar_background`.
- **Theme-API limit (verified 2026-08-21): the ACTIVE TAB and the TOOLBAR ROW are the same
  key (`toolbar`).** There is no separate active-tab color. "Black bar with red tabs" is
  only achievable as black `frame` (tab strip + inactive tabs) + red `toolbar` (active tab
  flowing into the address-bar row). If the user asks for a black toolbar with a lone red
  active tab, say it's impossible via theme keys before promising it.
  After editing an unpacked theme's manifest, the user reloads via the ↻ on the theme's
  `chrome://extensions` card (or browser restart) — Preferences `browser.theme.colors`
  refreshes from the manifest on load.
- **CLI/Preferences install is blocked** — Secure Preferences is HMAC-protected,
  so no prefs-file hack survives. But "Load unpacked" IS automatable via CDP:
  relaunch with `--remote-debugging-port=9222 --remote-allow-origins='*'`
  (allow-origins is required — websocket handshake 500s without it), PUT
  `/json/new?chrome://extensions`, then pierce shadow DOM:
  `extensions-manager → shadowRoot → extensions-toolbar → shadowRoot →
  #devMode.click()`, then `#load-unpacked.click()`. The native folder dialog
  that opens is the ONLY step CDP can't do — finish with ydotool input or hand
  the user the exact path to paste. Full recipe:
  `cachyos-site-config/references/browser-themes.md`.
- **Alternative: Preferences patching works on modern Chromium (verified 2026-08-21, Chromium 151)** — the `browser.theme` section in `Preferences` is NOT HMAC-protected the same way other sections are. You can patch it directly:
  ```python
  import json
  with open('~/.config/chromium/Default/Preferences') as f:
      d = json.load(f)
  d['browser']['theme'] = {
      "follows_system_colors": False,
      "theme_id": "<theme-dir-name>",
      "colors": {"frame": [16,16,20], ...}
  }
  with open('~/.config/chromium/Default/Preferences', 'w') as f:
      json.dump(d, f, indent=2)
  ```
  Then install the theme manifest as `~/.config/chromium/Themes/<theme-dir-name>/manifest.json` + assets. Chromium reads `theme_id` from Preferences and loads the matching theme dir from `Themes/`. Verify: `grep -o '"theme":[^}]*' ~/.config/chromium/Default/Preferences` should show the patched theme. This avoids the CDP dance entirely.
- Stage the theme dir at `~/.config/chromium-themes/<name>` so the Load unpacked
  path is stable and reinstalls are one click.
- **Verify without UI:** profile `Preferences` gains `"theme": {"id": "<32-hex>"}`
  and the theme dir name string: `grep -o '"theme":[^}]*' ~/.config/chromium/Default/Preferences`.
- NTP art goes in `images.theme_ntp_background` + `properties.ntp_background_alignment`.

### NTP-override extensions (chrome_url_overrides)

Modern Chromium's NTP often ignores `theme_ntp_background` (the "Customize Chromium" NTP wins). The deterministic fix is a tiny MV3 extension: `{"manifest_version": 3, "chrome_url_overrides": {"newtab": "newtab.html"}}` staged at `~/.config/chromium-themes/<name>/` alongside the theme.

- **Path-derived extension ID (verified Chromium 151):** for an unpacked extension, the ID = SHA-256 of the absolute path (UTF-8 bytes), first 16 bytes hex, each hex digit mapped 0-9a-f → a-p. Verified against a known Load-unpacked registration. Useful for predicting the ID before install:
  ```python
  import hashlib
  d = hashlib.sha256(b"/abs/path/to/ext").hexdigest()[:32]
  ext_id = "".join(chr(ord('a') + int(c, 16)) for c in d)
  ```
- **Pitfall — Preferences injection does NOT activate `chrome_url_overrides` (verified 2026-08-21):** writing a full `extensions.settings.<id>` entry (location=4, correct manifest, path-derived ID) into `Default/Preferences` survives the next launch unmodified — but the NTP stays `chrome://newtab/` and the override never engages. The frame *theme* got in this way historically, but URL overrides only activate when the extension is loaded through the UI. **Manual "Load unpacked" is the deterministic path:** send the user to `chrome://extensions` → Developer mode ON → Load unpacked → in the file dialog press Ctrl+L and paste the staged dir path. (If the injected entry already exists with the same path-derived ID, the manual load re-registers/overrides it cleanly — no cleanup needed first.)
- **Render-test the NTP HTML without the browser UI:** `chromium --headless=new --disable-gpu --no-sandbox --screenshot=/tmp/ntp.png --window-size=1600,900 file:///path/to/newtab.html`, then vision_analyze. Fast iteration loop before involving the user.
- **If the user REMOVED the NTP/theme extension and wants it back:** just hand them the staged path (`/home/synth/.config/chromium-themes/<name>`) + 4 steps: chrome://extensions → Developer mode ON → Load unpacked → Ctrl+L, paste path. Re-registers with the SAME path-derived ID; no cleanup, no agent-side work. Don't relaunch their browser over this.
- **Visual verification of browser UI chrome on KWin Wayland (verified 2026-08-22):** `computer_use` capture can return empty 0×0 for native-Wayland Chromium windows AND for `app='screen'` — don't conclude the browser isn't running (check `pgrep -x chromium`). `spectacle` from the agent shell core-dumps ("Aborted") unless given the full session env. Working invocation:
  ```bash
  env WAYLAND_DISPLAY=wayland-0 QT_QPA_PLATFORM=wayland \
      DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus \
      XDG_RUNTIME_DIR=/run/user/1000 \
      spectacle -b -n -f -o /tmp/shot.png
  ```
  Then vision_analyze the file. Caveats: the shot is the whole desktop — if the browser is behind another app (user mid-call etc.), the tab strip isn't visible and you CANNOT confirm chrome colors; say so honestly. CDP `Page.captureScreenshot` captures page CONTENT only, never the frame/tab strip, so it can't verify theme colors either.
- **Killing the user's Chromium:** use `pkill -x chromium` — NEVER `pkill -f chromium`, which matches the invoking shell's own cmdline and SIGTERMs the Hermes command mid-run (hit 2026-08-21).
- **Launching the user's Chromium from the agent shell (KDE Wayland):** needs `XAUTHORITY=/run/user/1000/xauth_*` (glob for it — the random suffix rotates per login) plus `--ozone-platform=wayland --disable-features=Vulkan` (Wayland+Vulkan error can kill the process shortly after start). Verify state via `--remote-debugging-port=9222` and `curl localhost:9222/json` (target list shows the real NTP URL) — a native-Wayland Chromium window does not appear in `computer_use list_windows`, so don't conclude "not running" from an empty window list.
- **Pitfall — extension theme injected into Preferences only NEVER loads (burned 2026-08-22):** an unpacked theme extension registered in `Default/Preferences` `extensions.settings` (location=4, correct path-derived ID) but ABSENT from `Default/Secure Preferences` `extensions.settings` (empty) is silently never loaded. Symptom: `extensions.theme` pointer and/or `browser.theme.theme_id` reference the extension, manifest has the right colors, yet tabs/frame render default. Fix (the deterministic path): (1) install the manifest at `~/.config/chromium/Themes/<theme_id>/manifest.json` (+ assets), matching `browser.theme.theme_id` exactly; (2) write the full color palette into `browser.theme.colors` in Preferences (Chromium refreshes it from the manifest on load, but the written values are the fallback); (3) delete the `extensions.theme` pointer AND the stale injected `extensions.settings.<id>` entry for the theme ext (keep the NTP-override ext entry if present — it still needs manual Load unpacked); (4) relaunch. Check FIRST: `python3 -c "import json; sp=json.load(open('...Secure Preferences')); print(list(sp.get('extensions',{}).get('settings',{}).keys()))"` — empty list = nothing injected ever loaded.
- **Pitfall — extension themes override Preferences `theme_id`:** Chromium may carry both a `browser.theme.theme_id` in Preferences AND an active extension theme registered under `extensions.theme` (with a `pack` path under `~/.config/chromium-themes/<name>/`). When the extension theme is active, Chromium renders THAT theme — even if Preferences points to a different `theme_id`. Symptom: Preferences shows the correct `theme_id` but the browser UI still uses a different theme (e.g. synthwave purple instead of Blackshield dark steel). Diagnosis: `grep -o '"extensions\\.theme":[^}]*' Preferences` — if present with a `pack` path, an extension theme is intercepting. Fix: (1) remove the `extensions.theme` entry from Preferences, (2) delete or disable the extension theme directory at `~/.config/chromium-themes/<name>/`, (3) ensure only the desired `theme_id` remains in `browser.theme`. Restart Chromium after.
- **Pitfall — vision analysis can misreport theme application:** A vision scan of a browser screenshot may report the theme "looks applied" because it sees the NTP background image or dark page content, but the actual theme colors (frame, toolbar, omnibox, tab colors) may not be applied. The NTP image can be present while the theme manifest is NOT loaded. Verify theme application by inspecting Preferences: `grep -o '"theme":[^}]*' Preferences` should show the expected `theme_id` AND matching color arrays. If the NTP image is present but frame/toolbar/omnibox colors are wrong, the theme manifest isn't loaded — check that `theme_id` matches the manifest directory name in `~/.config/chromium/Themes/`.

## NTP art generation

`scripts/gen-synthwave84-ntp.py` — stdlib-only Python (no PIL) that writes a 1920x1080
PNG: deep-purple gradient, STRIPED sun (gaps widen toward horizon), soft neon horizon
bloom, symmetric perspective grid (exact vanishing point: `off = (x-cx)/fy`, rows uniform
in `sqrt(fy)` space), dithered against banding. Verified via pixel-column check +
vision_analyze. Pitfall the script already encodes: when the sun is clipped at the
horizon, parameterize stripes over the VISIBLE half (`s = 1 + dy/radius`, 0→1) — using
the raw disc coordinate leaves `u <= 0` everywhere visible and stripes never render.

Commit generated art to git (synth's standing rule for game/visual assets).
