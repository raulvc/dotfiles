return {
  {
    "akinsho/toggleterm.nvim",
    version = "*",
    config = function()
      require("toggleterm").setup {
        start_in_insert = true,
        insert_mappings = true,
        terminal_mappings = true,
        close_on_exit = true,
        auto_scroll = true,
      }
      -- Custom keybindings
      local Terminal = require("toggleterm.terminal").Terminal

      -- Function to toggle terminal
      local function toggle_terminal()
        vim.cmd "ToggleTerm"
      end

      -- Function to hide terminal without closing
      local function hide_terminal()
        local terms = require("toggleterm.terminal").get_all()
        for _, term in pairs(terms) do
          if term:is_open() then
            term:close()
          end
        end
      end

      -- Keybindings
      -- Ctrl + / to toggle terminal (open/close)
      vim.keymap.set({ "n", "i", "t" }, "<C-/>", toggle_terminal, { desc = "Toggle terminal" })

      -- Alt + Up to hide terminal without closing
      vim.keymap.set("t", "<M-Up>", [[<Cmd>wincmd k<CR>]], { desc = "Go to buffer above" })
    end,
    lazy = false,
  },
}
