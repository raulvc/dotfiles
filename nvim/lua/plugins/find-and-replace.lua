return {
  {
    "MagicDuck/grug-far.nvim",
    lazy = false,
    opts = { headerMaxWidth = 80 },
    cmd = "GrugFar",
    keys = {
      {
        "<leader>fr",
        function()
          local grug = require "grug-far"
          local ext = vim.bo.buftype == "" and vim.fn.expand "%:e"

          -- Get selected text in visual mode
          local search_text = nil
          if vim.fn.mode() == "v" or vim.fn.mode() == "V" then
            vim.cmd 'normal! "vy'
            search_text = vim.fn.getreg "v"
          end

          grug.open {
            transient = true,
            prefills = {
              search = search_text,
              filesFilter = ext and ext ~= "" and "*." .. ext or nil,
            },
          }
        end,
        mode = { "n", "v" },
        desc = "Search and Replace",
      },
      {
        "<C-CR>",
        function()
          local grug = require "grug-far"
          local instance = grug.get_instance(0) -- get current buffer instance
          if instance then
            instance:sync_all()
          end
        end,
        ft = "grug-far",
        desc = "Sync all changes",
      },
    },
  },
}
