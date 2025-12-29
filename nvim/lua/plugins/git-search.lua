return {
  {
    "sindrets/diffview.nvim",
    lazy = false,
    opts = {
      enhanced_diff_hl = true,
      view = {
        default = {
          layout = "diff2_horizontal",
        },
        merge_tool = {
          layout = "diff3_horizontal",
        },
        file_history = {
          layout = "diff2_horizontal",
        },
      },
    },
  },
  {
    "aaronhallaert/advanced-git-search.nvim",
    cmd = { "AdvancedGitSearch" },
    config = function()
      require("telescope").load_extension "advanced_git_search"
    end,
    dependencies = {
      --- See dependencies
      {
        "nvim-telescope/telescope.nvim",
        -- to show diff splits and open commits in browser
        "tpope/vim-fugitive",
        -- to open commits in browser with fugitive
        "tpope/vim-rhubarb",
        -- diffview.nvim for better side-by-side diffs
        "sindrets/diffview.nvim",
      },
    },
  },
}
