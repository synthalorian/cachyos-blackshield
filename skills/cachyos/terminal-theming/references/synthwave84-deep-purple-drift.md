# Synthwave '84 Deep Purple Drift

## Canonical anchor

- Deep purple: `#240037`
- Hot pink: `#FF7EDB`
- Neon yellow: `#F3E70F`
- Electric purple: `#8F00FF`
- Cyan: `#03EDF9`
- Magenta: `#FF00FF`

## Symptom

Ghostty/Kitty/OpenShark/KDE window backgrounds look inconsistent: terminals read as near-black `#0D0221` while Kitty/KDE read as deep purple `#240037`. This usually happens when configs drift apart or when a quick shell one-liner writes `#0D0221` because the skill/template lagged behind the agreed anchor.

## Quick restore

```bash
# Ghostty
kwriteconfig6 --file ~/.config/ghostty/config.ghostty --group General --key background '#240037'
kwriteconfig6 --file ~/.config/ghostty/config.ghostty --group General --key selection-foreground '#240037'
ghostty +validate-config

# Alacritty — update all background-dependent slots, not just primary.background
sed -i 's/background = "#0D0221"/background = "#240037"/g' ~/.config/alacritty/alacritty.toml
sed -i 's/text = "#0D0221"/text = "#240037"/g' ~/.config/alacritty/alacritty.toml

# KDE
kwriteconfig6 --file ~/.config/kwinrc --group Colors --key ActiveBackground '#240037'
kwriteconfig6 --file ~/.config/kwinrc --group Colors --key ActiveForeground '#FF7EDB'
kwriteconfig6 --file ~/.config/kdeglobals --group General --key background '#240037'
kwriteconfig6 --file ~/.config/kdeglobals --group Colors --key BackgroundNormal '#240037'
qdbus org.kde.ScreenScanner /Scanner org.kde.ScreenScanner.refresh 2>/dev/null || true
```

## Prevention

- `terminal-theming` and `kde-plasma-desktop-customization` now treat `#240037` as authoritative for synthwave '84.
- When editing Ghostty/Alacritty/Kitty/KDE color keys, compare against this anchor instead of `#0D0221`.
