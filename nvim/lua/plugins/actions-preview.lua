return {
  "aznhe21/actions-preview.nvim",
  dependencies = { "nvim-telescope/telescope.nvim" },
  lazy = false,
  keys = {
    {
      "<leader>ca",
      function()
        require("actions-preview").code_actions()
      end,
      mode = { "n", "v" },
      desc = "Code actions (preview)",
    },
  },
  config = function()
    local hl = require "actions-preview.highlight"

    require("actions-preview").setup {
      backend = { "telescope" },

      telescope = {
        sorting_strategy = "ascending",
        layout_strategy = "vertical",
        layout_config = {
          width = 0.9,
          height = 0.95,
          prompt_position = "top",
          preview_cutoff = 20,
          preview_height = function(_, _, max_lines)
            return max_lines - 15
          end,
        },
      },

      diff = {
        algorithm = "patience",
        ignore_whitespace = false,
        ctxlen = 5,
      },

      highlight_command = {
        require("actions-preview.highlight").delta(),
        require("actions-preview.highlight").diff_so_fancy(),
        require("actions-preview.highlight").diff_highlight(),
      },
    }
  end,
}
