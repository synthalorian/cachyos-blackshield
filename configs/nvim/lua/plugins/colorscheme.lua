-- Blackshield Mercenary — blood & steel 🛡️
-- Local colorscheme living at lua/colors/blackshield.lua.

return {
  {
    "blackshield",
    dir = vim.fn.stdpath("config"),
    lazy = false,
    priority = 1000,
    config = function()
      require("colors.blackshield")
      vim.cmd.colorscheme("blackshield")
    end,
  },
}
