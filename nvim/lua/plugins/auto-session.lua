return {
  {
    "rmagatti/auto-session",
    cmd = { "SaveSession", "RestoreSession" },
    lazy = false,
    priority = 2000,
    config = function()
      vim.opt.sessionoptions:append "localoptions"

      require("auto-session").setup {
        auto_restore = true,
        auto_restore_last_session = false,
        auto_save = true,
        show_auto_restore_notif = true,
        enabled = true,
        log_level = "info",
        bypass_save_filetypes = {
          "alpha",
          "dashboard",
          "terminal",
          "neotest-output-panel",
          "neotest-summary",
          "kitty-scrollback",
        },
        session_lens = {
          load_on_setup = false, -- Don't auto-load on setup to avoid conflicts
        },
        suppressed_dirs = nil,

        pre_save_cmds = {
          -- Close minimap first to prevent handle errors
          function()
            pcall(function()
              require("mini.map").close()
            end)
          end,

          function()
            -- Close neotest UI components (based on <leader>tt mapping logic)
            pcall(function()
              local neotest = require "neotest"

              -- Stop running tests first
              pcall(function()
                neotest.run.stop()
              end)

              -- Try different close methods based on what's available (like in <leader>tt)
              if neotest.summary and neotest.summary.close then
                neotest.summary.close()
              elseif neotest.summary and neotest.summary.toggle then
                -- If no close, try toggle (it will close if open)
                neotest.summary.toggle()
              end

              if neotest.output_panel and neotest.output_panel.close then
                neotest.output_panel.close()
              end

              if neotest.output and neotest.output.close then
                neotest.output.close()
              end
            end)
          end,

          function()
            local terms = require("toggleterm.terminal").get_all()
            for _, term in pairs(terms) do
              if term:is_open() then
                term:close()
              end
            end
          end,
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
