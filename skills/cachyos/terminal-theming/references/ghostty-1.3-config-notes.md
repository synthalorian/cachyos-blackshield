# Ghostty 1.3.x configuration notes (CachyOS)

- Valid config filename: `~/.config/ghostty/config.ghostty`. The older `config` basename is ignored by Ghostty 1.3+.
- Validation command: `ghostty +validate-config`. It reports unknown fields and format errors but does NOT fail startup; Ghostty ignores bad keys at runtime.
- Full default reference: `ghostty +show-config --default --docs`. Source of truth is `src/config/Config.zig` in Ghostty's repo.
- Colors are set via `background`, `foreground`, and `palette = N=#RRGGBB`. There is no `link-color`, no `cursor-color <fg> <bg>`, no `selection-color`.
- Font emphasis: set `font-style-bold = true/false`, `font-style-italic`, `font-style-bold-italic`. There are no `bold-font-family` / `italic-font-family` keys.
- Window/appearance keys: `window-decoration`, `background-opacity`, `window-padding-x/y`, `scrollback-limit`, `mouse-scroll-multiplier`, `confirm-close-surface`.
- Cursor keys: `cursor-color`, `cursor-text`, `cursor-style`, `cursor-style-blink`.
- Selection keys: `selection-background`, `selection-foreground`.
- Keybinds: `keybind = <mods>+<key>=<action>` or `keybind = <mods>+<key>=<action>:<arg>`. No spaces around `=` inside the action segment; `increase_font_size:1` not `increase_font_size: 1`.
