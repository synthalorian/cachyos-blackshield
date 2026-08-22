---
name: neovim-config
description: >
  Neovim setup and configuration on Arch/CachyOS — installing, wiring as
  default editor (fish EDITOR/VISUAL, git core.editor), lazy.nvim config
  structure, headless plugin bootstrap, and known plugin pitfalls
  (nvim-treesitter branch break, synthwave84 colors_name bug).
  Triggers: nvim, neovim, vim config, lazy.nvim, default editor, EDITOR,
  colorscheme broken, treesitter error, plugin setup.
---

# Neovim Config

synth's editor: neovim with a hand-rolled lazy.nvim config (NOT a distro like
LazyVim/NvChad) and the synthwave84 colorscheme. The full known-good config is
backed up in the PRIVATE `cachyos-blackshield` repo (`configs/nvim/`,
github.com/synthalorian/cachyos-blackshield) — restore from there instead of
rebuilding from scratch when possible.

## Install + Wire as Default Editor (CachyOS/Arch)

```bash
sudo pacman -S --needed --noconfirm neovim wl-clipboard lazygit ripgrep fd
```

- `wl-clipboard` is required for system-clipboard sync on Wayland
  (`opt.clipboard = "unnamedplus"`); without it y/p stays inside nvim.
- `ripgrep` + `fd` power Telescope's live_grep/find_files.

Fish (`~/.config/fish/config.fish` — fish has no .profile-style env file):

```fish
set -gx EDITOR nvim
set -gx VISUAL nvim
```

Git: `git config --global core.editor nvim`

## Config Layout (lazy.nvim)

```
~/.config/nvim/
├── init.lua                      -- requires the three config modules
└── lua/
    ├── config/
    │   ├── options.lua           -- sets mapleader BEFORE lazy loads (critical)
    │   ├── keymaps.lua           -- leader = Space
    │   └── lazy.lua              -- bootstrap: git clone lazy.nvim, setup("plugins")
    └── plugins/*.lua             -- one spec file per domain; lazy auto-imports
```

`synth's plugin set (17): synthwave84, lualine, neo-tree, bufferline,
which-key, indent-blankline, telescope, treesitter, autopairs, Comment,
surround, gitsigns, lazygit + deps.`

## Headless Bootstrap + Verification

```bash
nvim --headless "+Lazy! sync" +qa        # install/update all plugins, non-interactive

# verify colorscheme + treesitter loaded:
nvim --headless -c 'lua print(tostring(vim.g.colors_name));
  \ print(tostring(pcall(require, "nvim-treesitter.configs")))' -c 'qa!'
```

Headless debugging pattern for a silently-failing colorscheme: replicate the
colorscheme file's body in a /tmp vim file with `print()` after each line —
this isolates WHICH statement clears state (see synthwave84 bug below).

## Pitfalls

- **`nvim-treesitter` `main` branch is a breaking rewrite** — the classic
  `require("nvim-treesitter.configs").setup({...})` module does not exist on
  `main` ("module 'nvim-treesitter.configs' not found"). Pin the legacy branch
  in the plugin spec: `branch = "master"`. Symptom appears at startup as a
  lazy.nvim "Failed to run config" error.

- **`lunarvim/synthwave84.nvim` nils `g:colors_name`** — its `load()` runs
  `hi clear`, which in current Neovim UNSETS `vim.g.colors_name` — but
  `colors/synthwave84.vim` sets the name BEFORE calling `load()`, so
  `:colorscheme synthwave84` ends with `colors_name == nil`. The colors still
  apply; only the name is lost (breaks statusline theme detection and
  verification checks). Workaround — skip `:colorscheme`, call directly and
  re-set the name AFTER load:

  ```lua
  require("synthwave84").setup({ glow = { ... } })
  require("synthwave84").load()
  vim.g.colors_name = "synthwave84"
  ```

- **lazy.nvim needs `mapleader` set before `setup()`** — put
  `vim.g.mapleader = " "` at the end of options.lua and require options
  before config/lazy in init.lua, or leader keymaps bind to `\`.

- **Nerd Fonts are system-level** — icons render as tofu without one
  installed AND selected in the terminal emulator's font config. Check with
  `fc-list | grep -i nerd` before blaming the plugin.

- **Headless `Lazy! sync` interleaves with treesitter parser downloads** —
  parser `[0/17] Downloading...` noise on stderr during headless runs is
  normal; grep it out when checking real errors.

## Authorship

Any nvim config committed to GitHub credits "Made by synth with synthclaw".
