-- Editor: fuzzy finding, syntax, editing helpers

return {
  -- Telescope fuzzy finder
  {
    "nvim-telescope/telescope.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    config = function()
      require("telescope").setup({
        defaults = {
          layout_config = { prompt_position = "top" },
          sorting_strategy = "ascending",
        },
      })
    end,
  },

  -- Treesitter syntax highlighting
  {
    "nvim-treesitter/nvim-treesitter",
    branch = "master", -- legacy configs API; 'main' branch is a breaking rewrite
    build = ":TSUpdate",
    config = function()
      require("nvim-treesitter.configs").setup({
        ensure_installed = {
          "lua", "vim", "vimdoc", "python", "rust", "javascript",
          "typescript", "json", "yaml", "toml", "markdown", "bash",
          "c", "cpp", "html", "css", "dart",
        },
        highlight = { enable = true },
        indent = { enable = true },
      })
    end,
  },

  -- Auto pairs
  {
    "windwp/nvim-autopairs",
    event = "InsertEnter",
    config = true,
  },

  -- Comment toggling: gcc (line), gc (visual)
  {
    "numToStr/Comment.nvim",
    config = true,
  },

  -- Surround: ysiw" cs'" ds"
  {
    "kylechui/nvim-surround",
    event = "VeryLazy",
    config = true,
  },
}
