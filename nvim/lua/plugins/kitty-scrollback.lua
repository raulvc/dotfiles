return {
  "mikesmithgh/kitty-scrollback.nvim",
  enabled = true,
  lazy = true,
  cmd = { "KittyScrollbackGenerateKittens", "KittyScrollbackCheckHealth" },
  event = { "User KittyScrollbackLaunch" },
  config = function()
    require("kitty-scrollback").setup {
      {
        -- Default configuration for all windows
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
        callbacks = {
          after_ready = function()
            vim.schedule(function()
              vim.cmd "normal! G" -- Go to bottom
              vim.api.nvim_feedkeys("/", "n", false) -- Start search mode
            end)
          end,
        },
      },
      -- Configuration for fzf search
      ksb_builtin_last_cmd_output = function()
        return {
          paste_window = {
            yank_register_enabled = false,
          },
          callbacks = {
            on_ready = function()
              vim.cmd "normal! G"
              vim.cmd "normal! ?\\$ <CR>" -- Find last prompt
              vim.cmd "FzfLua lines"
            end,
          },
        }
      end,
    }
  end,
}
