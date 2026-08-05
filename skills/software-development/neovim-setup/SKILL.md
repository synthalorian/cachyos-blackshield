---
name: neovim-setup
description: >
  Install and configure Neovim as the primary editor on Linux — lazy.nvim
  plugin manager, synthwave '84 colorscheme, fish/git EDITOR wiring, and
  known plugin bug workarounds.
  Triggers: nvim, neovim, vim config, lazy.nvim, editor setup, default editor, colorscheme, treesitter.
---

# Neovim Setup

Set up Neovim as the user's primary editor with a lean custom lazy.nvim config (NOT a distro like LazyVim — user prefers hand-rolled and lightweight).

## Steps

1. **Install packages** (CachyOS/Arch):
   ```bash
   sudo pacman -S --needed --noconfirm neovim wl-clipboard lazygit ripgrep fd
   ```
   `wl-clipboard` is required for system-clipboard sync on Wayland. ripgrep/fd power Telescope.

2. **Wire as default editor** in `~/.config/fish/config.fish`:
   ```fish
   set -gx EDITOR nvim
   set -gx VISUAL nvim
   ```
   Plus `git config --global core.editor nvim`.

3. **Config layout** at `~/.config/nvim/` — copy the known-good files from `templates/nvim-config/`:
   - `init.lua` → requires `config.options`, `config.keymaps`, `config.lazy`
   - `lua/config/options.lua` — 2-space tabs, relative numbers, `clipboard=unnamedplus`, leader = Space
   - `lua/config/keymaps.lua` — window nav, buffer cycling, Telescope/LazyGit shortcuts
   - `lua/config/lazy.lua` — lazy.nvim bootstrap, `require("lazy").setup("plugins")`
   - `lua/plugins/{colorscheme,ui,editor,git}.lua` — one file per plugin group

4. **Headless bootstrap + verify**:
   ```bash
   nvim --headless "+Lazy! sync" +qa
   nvim --headless -c 'lua print(vim.g.colors_name)' -c 'qa!'
   ```

## Plugin Stack (templates)

- **Colorscheme:** `lunarvim/synthwave84.nvim` (glow enabled) — user's synthwave '84 aesthetic
- **UI:** lualine, neo-tree, bufferline, which-key, indent-blankline
- **Editor:** telescope, nvim-treesitter, autopairs, Comment, nvim-surround
- **Git:** gitsigns, lazygit.nvim

## Pitfalls (verified 2026-07, nvim 0.12)

- **nvim-treesitter `main` branch is a breaking rewrite** — the `nvim-treesitter.configs` module no longer exists there. Pin `branch = "master"` in the plugin spec or `require("nvim-treesitter.configs").setup()` fails with "module not found".
- **synthwave84.nvim colors_name bug** — the plugin's `load()` runs `hi clear`, which nils `vim.g.colors_name` AFTER the colorscheme file sets it. Symptom: colorscheme applies visually but `colors_name` reads nil and `:colorscheme synthwave84` appears to silently no-op. Workaround: call `require("synthwave84").load()` directly, then set `vim.g.colors_name = "synthwave84"` manually (see templates/nvim-config/lua/plugins/colorscheme.lua).
- **Debugging "silent" colorscheme failures:** test in stages — `nvim -u NONE` + `:source <file>` isolates the file itself; a debug copy of the colorscheme file with `print()` inside the lua heredoc shows exactly where state gets clobbered. `vim.cmd.colorscheme()` swallowing errors into nil `colors_name` is the tell.
- **Nerd Fonts:** verify with `fc-list | grep -i nerd` before enabling devicons — CachyOS ships MesloLGS Nerd Fonts, so icons work out of the box.

## Files

- `templates/nvim-config/` — complete known-good config tree (verified on CachyOS, nvim 0.12). Copy wholesale, then modify.
