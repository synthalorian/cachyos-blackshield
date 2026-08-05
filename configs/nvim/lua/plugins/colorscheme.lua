-- synthwave '84 — the only acceptable colorscheme 🎹

return {
  {
    "lunarvim/synthwave84.nvim",
    lazy = false,
    priority = 1000,
    config = function()
      require("synthwave84").setup({
        glow = {
          error_msg = true,
          type2 = true,
          func = true,
          keyword = true,
          operator = false,
          buffer_current_target = true,
          buffer_visible_target = true,
          buffer_inactive_target = true,
        },
      })
      -- plugin bug workaround: load() runs `hi clear` which nils colors_name
      -- AFTER the colorscheme file set it, so load directly and re-set the name
      require("synthwave84").load()
      vim.g.colors_name = "synthwave84"
    end,
  },
}
