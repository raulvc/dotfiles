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
        version = "*", -- Optional, but recommended; track releases
        build = function()
          vim.system({ "go", "install", "gotest.tools/gotestsum@latest" }):wait() -- Optional, but recommended
        end,
      },
      {
        "rouge8/neotest-rust",
        dependencies = {
          "simrat39/rust-tools.nvim",
        },
      },
      {
        "nvim-neotest/neotest-python",
      },
      {
        "nvim-neotest/neotest-jest",
      },
      "nvim-contrib/nvim-ginkgo",
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

      -- Disable discovery to prevent scanning on startup
      opts.discovery = {
        enabled = false, -- Only discover tests when explicitly running them
      }

      quickfix = { require("trouble").open { mode = "quickfix", focus = false } }

      opts.adapters = opts.adapters or {}

      -- Helper function to find project root
      local function find_root(patterns)
        return function(path)
          local lib = require "neotest.lib"
          local root = lib.files.match_root_pattern(unpack(patterns))(path)

          -- Safety check: never use home or .config as root
          local home = vim.fn.expand "~"
          local config_dir = vim.fn.expand "~/.config"

          if root == home or root == config_dir or not root then
            return vim.fn.getcwd() -- Fallback to current working directory
          end

          return root
        end
      end

      -- Go: go test with DAP (dlv)
      opts.adapters["neotest-golang"] = {
        go_test_args = {
          "-v",
          "-count=1",
          "-coverprofile=" .. vim.fn.getcwd() .. "/coverage.out",
        },
        runner = "gotestsum",
        gotestsum_args = {
          "--format=pkgname-and-test-fails",
        },
        experimental = {
          test_table = true,
        },
        dev_notifications = true,
        dap_go_enabled = true,
        env = {
          -- GOEXPERIMENT = "synctest",
        },

        root_dir = find_root { "go.mod", "go.work", ".git" },
      }

      -- Rust: codelldb via rust-tools
      opts.adapters["neotest-rust"] = {
        dap = true,
        root_dir = find_root { "Cargo.toml", ".git" },
      }

      -- Python: debugpy
      opts.adapters["neotest-python"] = {
        dap = {
          justMyCode = false,
        },
        root_dir = find_root { "pyproject.toml", "setup.py", "setup.cfg", "requirements.txt", "pytest.ini", ".git" },
      }

      opts.adapters["neotest-jest"] = {
        jestCommand = "npm test --",
        jestConfigFile = "jest.config.js",
        env = { CI = true },
        cwd = function(path)
          return vim.fn.getcwd()
        end,
        root_dir = find_root { "package.json", ".git" },
      }

      -- Ginkgo: for BDD-style Go tests (must be listed BEFORE neotest-golang)
      -- We use a numeric index to control ordering
      table.insert(opts.adapters, 1, {
        name = "nvim-ginkgo",
        config = {
          root_dir = find_root { "go.mod", "go.work", ".git" },
        },
      })

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
      {
        "<leader>tL",
        function()
          -- Show last 50 lines of neotest log in a split
          local log_file = vim.fn.stdpath "log" .. "/neotest.log"
          if vim.fn.filereadable(log_file) == 1 then
            -- Create a new split for the log output
            vim.cmd "botright split"
            vim.cmd "resize 20"
            local buf = vim.api.nvim_create_buf(false, true)
            vim.api.nvim_win_set_buf(0, buf)

            -- Set buffer options
            vim.bo[buf].buftype = "nofile"
            vim.bo[buf].swapfile = false
            vim.bo[buf].filetype = "log"

            -- Use tail command to get last 50 lines
            vim.fn.jobstart({ "tail", "-n", "50", log_file }, {
              stdout_buffered = true,
              on_stdout = function(_, lines)
                if lines and #lines > 0 then
                  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
                end
              end,
              on_exit = function()
                -- Go to the end of buffer
                vim.schedule(function()
                  local line_count = vim.api.nvim_buf_line_count(buf)
                  vim.api.nvim_win_set_cursor(0, { line_count, 0 })
                end)
              end,
            })
          else
            vim.notify("Neotest log file not found at: " .. log_file, vim.log.levels.WARN)
          end
        end,
        desc = "[t]est [L]ogs (last 50 lines)",
      },
    },
  },
}
