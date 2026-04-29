local is_kitty_scrollback = vim.env.KITTY_SCROLLBACK_NVIM ~= nil

return {
  { "rmagatti/auto-session", enabled = not is_kitty_scrollback },
  { "zbirenbaum/copilot.lua", enabled = not is_kitty_scrollback },
  { "giuxtaposition/blink-cmp-copilot", enabled = not is_kitty_scrollback },
  { "saghen/blink.cmp", enabled = not is_kitty_scrollback },
  { "xzbdmw/colorful-menu.nvim", enabled = not is_kitty_scrollback },

  -- Disable git-related plugins
  { "gitsigns.nvim", enabled = not is_kitty_scrollback },
  { "git-blame.nvim", enabled = not is_kitty_scrollback },
  { "diffview.nvim", enabled = not is_kitty_scrollback },

  -- Disable treesitter parsing
  { "tree-sitter-manager.nvim", enabled = not is_kitty_scrollback },
  { "nvim-treesitter-context", enabled = not is_kitty_scrollback },
  { "nvim-treesitter-textobjects", enabled = not is_kitty_scrollback },

  -- Disable LSP and linting
  { "nvim-lspconfig", enabled = not is_kitty_scrollback },
  { "nvim-lint", enabled = not is_kitty_scrollback },
  { "fidget.nvim", enabled = not is_kitty_scrollback },

  -- Disable UI enhancements
  { "noice.nvim", enabled = not is_kitty_scrollback },

  -- Disable DAP (debugger) plugins
  { "nvim-dap", enabled = not is_kitty_scrollback },
  { "nvim-dap-view", enabled = not is_kitty_scrollback },
  { "nvim-dap-virtual-text", enabled = not is_kitty_scrollback },
  { "nvim-dap-go", enabled = not is_kitty_scrollback },
  { "mason-nvim-dap.nvim", enabled = not is_kitty_scrollback },

  -- Disable neotest plugins
  { "neotest", enabled = not is_kitty_scrollback },
  { "neotest-golang", enabled = not is_kitty_scrollback },
  { "neotest-jest", enabled = not is_kitty_scrollback },
  { "neotest-plenary", enabled = not is_kitty_scrollback },
  { "neotest-python", enabled = not is_kitty_scrollback },
  { "neotest-rust", enabled = not is_kitty_scrollback },
  { "neotest-vim-test", enabled = not is_kitty_scrollback },

  {
    "mikesmithgh/kitty-scrollback.nvim",
    enabled = true,
    lazy = true,
    cmd = { "KittyScrollbackGenerateKittens", "KittyScrollbackCheckHealth" },
    event = { "User KittyScrollbackLaunch" },
    config = function()
      require("kitty-scrollback").setup {
        {
          -- Default configuration (edit mode - no auto-search)
          paste_window = {
            yank_register_enabled = true,
            yank_register = "+",
          },
          status_window = {
            enabled = true,
            style_simple = false,
          },
          keymaps_enabled = true,
          restore_options = true,
          highlight_overrides = {
            KittyScrollbackNvimStatusWinNormal = { link = "Normal" },
            KittyScrollbackNvimPasteWinNormal = { link = "Normal" },
          },
        },

        -- Configuration for search mode
        ksb_builtin_search = function()
          return {
            paste_window = {
              yank_register_enabled = true,
              yank_register = "+",
            },
            status_window = {
              enabled = true,
              style_simple = false,
            },
            callbacks = {
              after_ready = function()
                vim.schedule(function()
                  vim.api.nvim_feedkeys("/", "n", false)
                end)
              end,
            },
          }
        end,

        -- Configuration for fzf search
        ksb_builtin_last_cmd_output = function()
          return {
            paste_window = {
              yank_register_enabled = false,
            },
            callbacks = {
              after_ready = function()
                vim.schedule(function()
                  vim.api.nvim_feedkeys("/", "n", false)
                end)
              end,
            },
          }
        end,
      }
    end,
  },
}
