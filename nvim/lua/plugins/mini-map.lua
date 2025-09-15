return {
  "echasnovski/mini.map",
  lazy = false,
  config = function()
    local map = require "mini.map"
    map.setup {
      integrations = {
        map.gen_integration.builtin_search(),
        map.gen_integration.gitsigns {
          add = "GitSignsAdd",
          change = "GitSignsChange",
          delete = "GitSignsDelete",
        },
        map.gen_integration.diagnostic {
          error = "DiagnosticFloatingError",
          warn = "DiagnosticFloatingWarn",
          info = "DiagnosticFloatingInfo",
          hint = "DiagnosticFloatingHint",
        },
      },
      symbols = {
        encode = map.gen_encode_symbols.block "3x2",
        scroll_line = "█",
        scroll_view = "┃",
      },
      window = {
        side = "right",
        width = 10,
        winblend = 15,
        show_integration_count = true,
      },
    }

    -- Smart auto-open logic
    local function should_open_map()
      local bt = vim.bo.buftype
      local ft = vim.bo.filetype
      local excluded_ft = {
        "help",
        "alpha",
        "dashboard",
        "neo-tree",
        "Trouble",
        "trouble",
        "lazy",
        "mason",
        "notify",
        "toggleterm",
        "lazyterm",
        "NvimTree",
        "codecompanion",
        "TelescopePrompt",
      }

      return bt == "" and not vim.tbl_contains(excluded_ft, ft) and vim.fn.expand "%" ~= ""
    end

    vim.api.nvim_create_autocmd({ "BufEnter", "WinEnter" }, {
      callback = function()
        if should_open_map() and not map.current.win_id then
          map.open()
        end
      end,
    })

    -- Keybindings
    vim.keymap.set("n", "<leader>mm", map.toggle, { desc = "Toggle minimap" })
    vim.keymap.set("n", "<leader>mr", map.refresh, { desc = "Refresh minimap" })
    vim.keymap.set("n", "<leader>mf", map.toggle_focus, { desc = "Focus minimap" })
  end,
}
