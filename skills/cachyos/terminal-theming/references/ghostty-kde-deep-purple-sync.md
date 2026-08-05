# Ghostty/KDE color-sync notes

- Synthwave '84 canonical background for terminals: `#240037`.
- Ghostty config: set `background = #240037` and `selection-foreground = #240037`.
- KDE color-scheme file: `~/.local/share/color-schemes/SweetAmbarBlue.colors`.
- Quick refresh after `.colors` edits: `qdbus org.kde.ScreenScanner /Scanner org.kde.ScreenScanner.refresh`.
- Plasma often needs `plasmashell --replace` or a full logout/login before some color-scheme changes repaint everywhere.
- In `kwinrc`, also set `ActiveBackground/ActiveForeground` so window borders follow the same deep-purple baseline.
