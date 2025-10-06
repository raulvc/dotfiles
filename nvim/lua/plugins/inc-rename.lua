return {
  "smjonas/inc-rename.nvim",
  lazy = false,
  opts = {},
  config = function()
    require("inc_rename").setup {
      input_buffer_type = "snacks",
    }
  end,
}
