# Chromium Theme Color-Key Semantics + KDE Icon Theme Traps (verified 2026-08-21)

## Chromium theme keys (Chromium 151)

- `toolbar` colors BOTH the active tab AND the toolbar/address row — one merged key.
- `frame` colors the tab strip behind the INACTIVE tabs.
- Consequence: "black tab strip + red active tab" = `frame` black + `toolbar` red,
  but the red necessarily flows down through the address row too. A black toolbar row
  with a lone red active tab is NOT expressible via theme keys — tell the user before
  promising it.

## KDE icon theme ([Icons] in kdeglobals)

- KDE writes/reads the key as capital-T `Theme=`. A stale lowercase `theme=` entry from
  an older write can COEXIST as a duplicate; `kreadconfig6 --group Icons --key theme`
  (lowercase) then returns the stale value while the system uses the capital-T one.
- After changing the icon theme, grep the raw `[Icons]` block and delete duplicate-case keys.
- Running apps (Dolphin, plasmashell) cache the icon theme in memory — a kdeglobals edit
  does NOT live-update them. New windows / next login pick it up, or
  `systemctl --user restart plasma-plasmashell.service` for the panel.
  Don't conclude "the change didn't take" from a still-running app.

(This note also intended for the SKILL.md bodies of browser-theming and
kde-plasma-desktop-customization — the read-before-write guard refused both patches
in the 2026-08-21 late session despite skill_view loads; see curator log.)
