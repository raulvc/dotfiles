return {
  {
    "rmagatti/auto-session",
    cmd = { "SaveSession", "RestoreSession" },
    lazy = false,
    priority = 2000,
    config = function()
      require("auto-session").setup {
        auto_restore = true,
        auto_restore_last_session = false,
        auto_save = true,
        show_auto_restore_notif = true,
        enabled = true,
        log_level = "info",
        pre_save_cmds = {
          function()
            require("configs.sessions").save_all()
          end,
          function()
            pcall(function()
              require("configs.dap_breakpoints").save()
            end)
          end,
        },
        post_restore_cmds = {
          function()
            require("configs.sessions").restore_all()
          end,
          function()
            -- Delay breakpoint restoration to ensure buffers are loaded
            vim.defer_fn(function()
              pcall(function()
                require("configs.dap_breakpoints").restore()
              end)
            end, 100)
          end,
        },
      }

      -- Manual save/restore commands
      vim.api.nvim_create_user_command("SessionSaveExtras", function()
        require("configs.sessions").save_all()
        pcall(function()
          require("configs.dap_breakpoints").save()
        end)
      end, {})

      vim.api.nvim_create_user_command("SessionRestoreExtras", function()
        require("configs.sessions").restore_all()
        pcall(function()
          require("configs.dap_breakpoints").restore()
        end)
      end, {})
    end,
  },
}
