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
  opts = {
    -- Use telescope for the preview
    backend = { "telescope" },

    -- Telescope options
    telescope = {
      sorting_strategy = "ascending",
      layout_strategy = "vertical",
      layout_config = {
        width = 0.8,
        height = 0.9,
        prompt_position = "top",
        preview_cutoff = 20,
        preview_height = function(_, _, max_lines)
          return max_lines - 15
        end,
      },
    },

    -- Show diff in the preview window
    diff = {
      algorithm = "patience",
      ignore_whitespace = true,
    },
  },
}
