return {
  {
    "nvim-neotest/neotest",
    dependencies = {
      "nvim-neotest/nvim-nio",
      "nvim-lua/plenary.nvim",
      "antoinemadec/FixCursorHold.nvim",
      "nvim-treesitter/nvim-treesitter",
      "nvim-neotest/neotest-plenary",
      "nvim-neotest/neotest-vim-test",
      {
        "fredrikaverpil/neotest-golang",
        branch = "main",
        dependencies = {
          "leoluz/nvim-dap-go",
          "andythigpen/nvim-coverage",
        },
      },
      {
        "rouge8/neotest-rust",
        dependencies = {
          "simrat39/rust-tools.nvim",
        },
      },
      {
        "nvim-neotest/neotest-python",
        dependencies = {
          "mfussenegger/nvim-dap-python",
        },
      },
      "mfussenegger/nvim-dap",
    },
    opts = function(_, opts)
      opts.output = {
        enabled = true,
      }

      opts.output_panel = {
        enabled = true,
        open = "botright split | resize 15",
      }

      opts.log_level = vim.log.levels.DEBUG

      quickfix = { require("trouble").open { mode = "quickfix", focus = false } }

      opts.adapters = opts.adapters or {}

      -- Go: go test with DAP (dlv)
      opts.adapters["neotest-golang"] = {
        go_test_args = {
          "-v",
          "-race",
          "-count=1",
          "-coverprofile=" .. vim.fn.getcwd() .. "/coverage.out",
        },
        runner = "gotestsum",
        gotestsum_args = { "--format=standard-verbose" },
        experimental = {
          test_table = true,
        },
        dev_notifications = true,
        dap_go_enabled = true,
        env = {
          GOEXPERIMENT = "synctest",
        },
      }

      -- Rust: codelldb via rust-tools
      opts.adapters["neotest-rust"] = {
        dap = true,
      }

      -- Python: debugpy
      opts.adapters["neotest-python"] = {
        dap = {
          justMyCode = false,
        },
      }

      opts.adapters["neotest-vim-test"] = false
      opts.consumers = opts.consumers or {}

      opts.consumers.trouble = function(client)
        client.listeners.results = function(adapter_id, results, partial)
          if partial then
            return
          end
          local tree = assert(client:get_position(nil, { adapter = adapter_id }))

          local failed = 0
          for pos_id, result in pairs(results) do
            if result.status == "failed" and tree:get_key(pos_id) then
              failed = failed + 1
            end
          end
          vim.schedule(function()
            local trouble = require "trouble"
            if trouble.is_open() then
              trouble.refresh()
              if failed == 0 then
                trouble.close()
              end
            end
          end)
          return {}
        end
      end

      -- opts.consumers = {
      --   overseer = require "neotest.consumers.overseer",
      -- }
    end,
    config = require "configs.neotest",
    keys = {
      {
        "<leader>ta",
        function()
          require("neotest").run.attach()
          require("neotest").summary.open()
          require("neotest").output_panel.open {}
        end,
        desc = "[t]est [a]ttach",
      },
      {
        "<leader>tf",
        function()
          require("neotest").run.run(vim.fn.expand "%")
          require("neotest").summary.open()
          require("neotest").output_panel.open()
        end,
        desc = "[t]est run [f]ile",
      },
      {
        "<leader>tA",
        function()
          require("neotest").run.run(vim.uv.cwd())
          require("neotest").summary.open()
          require("neotest").output_panel.open()
        end,
        desc = "[t]est [A]ll files",
      },
      {
        "<leader>tS",
        function()
          require("neotest").run.run { suite = true }
          require("neotest").summary.open()
          require("neotest").output_panel.open()
        end,
        desc = "[t]est [S]uite",
      },
      {
        "<leader>tn",
        function()
          require("neotest").run.run()
          require("neotest").summary.open()
          require("neotest").output_panel.open()
        end,
        desc = "[t]est [n]earest",
      },
      {
        "<leader>tl",
        function()
          require("neotest").run.run_last()
          require("neotest").summary.open()
          require("neotest").output_panel.open()
        end,
        desc = "[t]est [l]ast",
      },
      {
        "<leader>ts",
        function()
          require("neotest").summary.toggle()
        end,
        desc = "[t]est [s]ummary",
      },
      {
        "<leader>to",
        function()
          require("neotest").output.open { enter = true, auto_close = true }
        end,
        desc = "[t]est [o]utput",
      },
      {
        "<leader>tO",
        function()
          require("neotest").output_panel.toggle()
        end,
        desc = "[t]est [O]utput panel",
      },
      {
        "<leader>tt",
        function()
          -- Try to stop running tests, ignore errors if none running
          local neotest = require "neotest"

          -- Stop running tests
          pcall(function()
            neotest.run.stop()
          end)

          -- Try different close methods based on what's available
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

          vim.notify("🛑 Terminated neotest", vim.log.levels.INFO)
        end,
        desc = "[t]est [t]erminate",
      },
      {
        "<leader>te",
        function()
          local input = vim.fn.input "Environment variables (KEY=value KEY2=value2): "
          if input ~= "" then
            local env_vars = {}

            -- Parse environment variables (KEY=value format)
            for env_var in input:gmatch "([%w_]+=[^%s]+)" do
              local key, value = env_var:match "([%w_]+)=([^%s]+)"
              if key and value then
                env_vars[key] = value
              end
            end

            require("neotest").run.run {
              env = env_vars,
            }
            require("neotest").summary.open()
            require("neotest").output_panel.open()
          else
            -- Fall back to normal nearest test if no input
            require("neotest").run.run()
            require("neotest").summary.open()
            require("neotest").output_panel.open()
          end
        end,
        desc = "[t]est nearest with [e]nv vars",
      },
      {
        "<leader>tE",
        function()
          local input = vim.fn.input "Environment variables (KEY=value KEY2=value2): "
          if input ~= "" then
            local env_vars = {}

            -- Parse environment variables (KEY=value format)
            for env_var in input:gmatch "([%w_]+=[^%s]+)" do
              local key, value = env_var:match "([%w_]+)=([^%s]+)"
              if key and value then
                env_vars[key] = value
              end
            end

            require("neotest").run.run {
              vim.fn.expand "%",
              env = env_vars,
            }
            require("neotest").summary.open()
            require("neotest").output_panel.open()
          else
            -- Fall back to normal file test if no input
            require("neotest").run.run(vim.fn.expand "%")
            require("neotest").summary.open()
            require("neotest").output_panel.open()
          end
        end,
        desc = "[t]est fil[E] with env vars",
      },

      {
        "<leader>td",
        function()
          local ft = vim.bo.filetype
          if ft == "go" then
            require("dap-go").debug_test() -- use DAP-go for Go
          else
            require("neotest").run.run { strategy = "dap" } -- use neotest-DAP for others
          end
        end,
        desc = "Debug nearest test",
      },
      {
        "<leader>tC",
        function()
          local input = vim.fn.input "Go test command (flags and env vars): "
          if input ~= "" then
            local env_vars = {}
            local test_args = {}

            -- Parse environment variables (KEY=value format)
            for env_var in input:gmatch "([%w_]+=[%w_]+)" do
              local key, value = env_var:match "([%w_]+)=([%w_]+)"
              if key and value then
                env_vars[key] = value
              end
            end

            -- Parse test flags (remove env vars from input)
            local flags_only = input:gsub("[%w_]+=[%w_]+%s*", "")
            if flags_only ~= "" then
              test_args = vim.split(flags_only:gsub("^%s*", ""):gsub("%s*$", ""), " ")
            end

            require("neotest").run.run {
              strategy = "dap",
              extra_args = test_args,
              env = env_vars,
            }
          else
            require("neotest").run.run { strategy = "dap" }
          end
        end,
        desc = "Debug test with custom flags and env vars",
      },
      {
        "<leader>tD",
        function()
          local ft = vim.bo.filetype
          if ft == "go" then
            local filename = vim.fn.expand "%:p"
            require("dap-go").debug_test { test_file = "filename", test_func = nil }
          else
            require("neotest").run.run { strategy = "dap" } -- use neotest-DAP for others
          end
        end,
        desc = "Debug current file",
      },
    },
  },
}
