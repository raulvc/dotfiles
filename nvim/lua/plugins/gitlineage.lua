return {
  "lionyxml/gitlineage.nvim",
  lazy = false,
  dependencies = {
    "sindrets/diffview.nvim", -- optional, for open_diff feature
  },
  config = function()
    require("gitlineage").setup {
      keymap = "<leader>gl",
    }
  end,
}
