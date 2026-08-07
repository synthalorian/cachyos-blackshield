# Browser Themes — Synthwave '84 🎹🦞

Browser chrome matching the KDE / Ghostty / Limine / Plymouth stack.

Palette canon: bg `#240037` · deep `#0D0221` · fg `#FF7EDB` · magenta `#FF00FF`
· purple `#8F00FF` · mid-purple `#4B0080` · cyan `#03EDF9` · green `#72F1B8`
· yellow `#F3E70F` · red `#FE4450`.

## Firefox

**What ships:** `configs/browsers/firefox/`
- `chrome/userChrome.css` — toolbars, tabs (selected tab = pink-on-purple,
  Ghostty tab-chrome convention), URL bar with magenta focus glow, menus,
  sidebar, findbar, scrollbars, tooltips.
- `chrome/userContent.css` — `about:newtab` / `about:home` /
  `about:privatebrowsing` / reader mode. New tab uses the striped-sun art
  (`chrome/ntp_background.png`).
- `user.js` — enables `toolkit.legacyUserProfileCustomizations.stylesheets`
  (required for userChrome) + dark devtools.

**Install:** `./install.sh browsers` deploys into every
`~/.mozilla/firefox/*.default*` profile and creates a headless profile if
Firefox has never been launched. Restart Firefox to apply.

**Notes:**
- Web page content is NOT touched — only browser chrome and `about:*` pages.
- To uninstall: delete the profile's `chrome/` dir and remove the appended
  block from `user.js`.

## Chromium

**What ships:** `configs/browsers/chromium/synthwave84/`
- `manifest.json` — frame/toolbar/tab/omnibox/NTP colors + tints.
- `ntp_background.png` — 1920x1080 striped-sun grid art (generated, committed).

**Install:** `./install.sh browsers` stages the theme at
`~/.config/chromium-themes/synthwave84`. Chromium blocks CLI theme installs,
so there's a one-time manual step:

1. Open `chrome://extensions`
2. Enable **Developer mode** (top right)
3. **Load unpacked** → select `~/.config/chromium-themes/synthwave84`

The theme applies instantly. To uninstall: `chrome://extensions` → Remove.

## Regenerating the NTP art

The PNG is generated with stdlib Python (no deps): deep-purple gradient,
striped retro sun, soft neon horizon, symmetric perspective grid, dithered
against banding. Regenerate only if the palette canon changes — commit the
result (`game prefs: generated assets go in git`).
