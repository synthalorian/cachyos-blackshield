# Synthwave84 SDDM Theme

## Location

```
/usr/share/sddm/themes/synthwave84/
```

## Required Files

| File | Purpose |
|------|---------|
| `Main.qml` | QtQuick UI — background, logo, input field, error text |
| `logo.svg` | SVG logo rendered above the login form |
| `metadata.desktop` | Theme metadata (name, description, author) |
| `theme.conf` | General section (can be minimal: `[General]` with no values) |

## Color Mapping

| Element | Color | Role |
|---------|-------|------|
| Background | `#240037` | Deep purple surface |
| Input field fill | `#0D0221` | Darkest purple (deep background) |
| Input field border | `#FFFF66` | Yellow — the input frame |
| Input text (dots) | `#FFFF66` | Yellow — typed password characters |
| Lock icon | `#FFFF66` | Yellow Nerd Font lock glyph |
| Logo fill | `#7B00B4` | Purple — matches Plymouth shutdown logo (`/usr/share/plymouth/themes/synthwave84/logo.png`) |
| Error text | `#FF0040` | Red |
| Font (both) | `3270 Nerd Font` | Terminal monospace |

## Main.qml Key Structure

- **Root:** `Rectangle { color: "#240037" }` — full-screen purple background
- **Column** centered: Image (logo.svg) → Row (lock icon + input field)
- **Row** horizontally centered: Text (lock icon) + Rectangle (password box)
- **Rectangle** (input box): `color: "#0D0221"`, `border.color: "#FFFF66"`, `border.width: 2`
- **TextInput** inside: `color: "#FFFF66"`, `font.family: "3270 Nerd Font"`
- **Error text** below: `color: "#FF0040"`

## Plymouth Color Linkage

The SDDM logo (`logo.svg`) intentionally matches the Plymouth shutdown logo (`/usr/share/plymouth/themes/synthwave84/logo.png`) at `#7B00B4`. If one logo is recolored, the other should follow so the boot → login → desktop color story is consistent. SDDM is pure SVG (quick sed recolor), Plymouth is PNG (needs PIL-based recolor as documented in `references/plymouth-image-roles.md`).

## Pitfalls

- **Empty directory = default fallback:** An empty `/usr/share/sddm/themes/synthwave84/` directory with no files causes SDDM to silently fall back to a built-in Qt theme with **white input fields**. The fix is to populate it with the four required files.
- **No service restart needed:** SDDM reads the theme on next login. Logout or reboot to pick up changes.
- **Non-destructive:** QML/theme files are safe — cannot break Hyprland or the desktop session. Worst case: SDDM falls back to default.
- **Font availability:** `3270 Nerd Font` must be installed system-wide for the greeter to render it. Falls back to the system Qt default if missing.
- **SDDM config already set:** The config at `/etc/sddm.conf.d/theme.conf` should already say `Current=synthwave84`. Only change it if you're switching to a different theme.
