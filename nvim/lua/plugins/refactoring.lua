return {
  "ThePrimeagen/refactoring.nvim",
  dependencies = {
    "nvim-lua/plenary.nvim",
    "nvim-treesitter/nvim-treesitter",
    "lewis6991/async.nvim",
  },
  opts = {},
  keys = {
    {
      "<leader>rr",
      function()
        require("refactoring").select_refactor()
      end,
      mode = { "n", "x" },
      desc = "Select refactor",
    },
    {
      "<leader>re",
      "<cmd>Refactor extract<cr>",
      mode = "x",
      desc = "Extract function",
    },
    {
      "<leader>rv",
      "<cmd>Refactor extract_var<cr>",
      mode = "x",
      desc = "Extract variable",
    },
    {
      "<leader>ri",
      function()
        require("refactoring").inline_var()
      end,
      mode = { "n", "x" },
      desc = "Inline variable",
    },
    {
      "<leader>rI",
      function()
        require("refactoring").inline_func()
      end,
      mode = "n",
      desc = "Inline function",
    },
    {
      "<leader>rp",
      function()
        require("refactoring").print_var()
      end,
      mode = { "n", "x" },
      desc = "Print variable",
    },
    {
      "<leader>rc",
      function()
        require("refactoring").debug_cleanup()
      end,
      mode = "n",
      desc = "Debug print cleanup",
    },
  },
}
