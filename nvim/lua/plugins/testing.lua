return {
  {
    "nvim-neotest/neotest",
    dependencies = {
      "nvim-neotest/nvim-nio",
      "nvim-lua/plenary.nvim",
      "antoinemadec/FixCursorHold.nvim",
      "romus204/tree-sitter-manager.nvim",
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
      "nvim-contrib/neotest-ginkgo",
      "mfussenegger/nvim-dap",
      {
        "rcasia/neotest-java",
        ft = { "java", "kotlin" },
        build = function()
          -- Download JUnit Platform Console Standalone JAR directly
          -- since :NeotestJava setup requires neotest to be initialized first
          local version = "6.0.3"
          local jar_dir = vim.fn.stdpath "data" .. "/neotest-java"
          local jar_path = jar_dir .. "/junit-platform-console-standalone-" .. version .. ".jar"

          if vim.fn.filereadable(jar_path) == 1 then
            return
          end

          vim.fn.mkdir(jar_dir, "p")
          local url = string.format(
            "https://repo1.maven.org/maven2/org/junit/platform/junit-platform-console-standalone/%s/junit-platform-console-standalone-%s.jar",
            version,
            version
          )
          vim.notify("Downloading JUnit Platform Console Standalone " .. version .. "...", vim.log.levels.INFO)
          vim.system({ "curl", "-fsSL", "-o", jar_path, url }):wait()

          if vim.fn.filereadable(jar_path) == 1 then
            vim.notify("JUnit Platform Console Standalone downloaded successfully", vim.log.levels.INFO)
          else
            vim.notify("Failed to download JUnit Platform Console Standalone JAR", vim.log.levels.ERROR)
          end
        end,
      },
    },

    opts = function(_, opts)
      -- Pretty icons for test status
      opts.icons = {
        passed = "✓",
        failed = "✗",
        running = "⟳",
        skipped = "○",
        unknown = "?",
        non_collapsible = "─",
        collapsed = "",
        expanded = "",
        child_prefix = "├",
        final_child_prefix = "╰",
        child_indent = "│",
        final_child_indent = " ",
        watching = "󰈈",
        running_animated = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" },
      }

      -- Floating output window (prettier than split)
      opts.output = {
        enabled = true,
        open_on_run = false, -- Don't auto-open, use <leader>to
      }

      -- Output panel at bottom
      opts.output_panel = {
        enabled = true,
        open = "botright split | resize 15",
      }

      -- Summary panel configuration
      opts.summary = {
        enabled = true,
        animated = true,
        follow = true,
        expand_errors = true,
        open = "botright vsplit | vertical resize 50",
        mappings = {
          expand = { "<CR>", "<2-LeftMouse>" },
          expand_all = "e",
          jumpto = "<C-CR>",
          output = "o",
          short = "O",
          attach = "a",
          run = "r",
          mark = "m",
          run_marked = "R",
          debug = "d",
          debug_marked = "D",
          clear_marked = "M",
          target = "t",
          clear_target = "T",
          stop = "s",
          watch = "w",
        },
      }

      -- Status virtual text
      opts.status = {
        enabled = true,
        virtual_text = true,
        signs = true,
      }

      -- Highlight groups for test status
      opts.highlights = {
        passed = "NeotestPassed",
        failed = "NeotestFailed",
        running = "NeotestRunning",
        skipped = "NeotestSkipped",
        test = "NeotestTest",
        namespace = "NeotestNamespace",
        file = "NeotestFile",
        dir = "NeotestDir",
        focused = "NeotestFocused",
        adapter_name = "NeotestAdapterName",
        select_win = "NeotestSelectWin",
        marked = "NeotestMarked",
        target = "NeotestTarget",
        unknown = "NeotestUnknown",
        watching = "NeotestWatching",
      }

      -- Floating window settings
      opts.floating = {
        border = "rounded",
        max_height = 0.6,
        max_width = 0.8,
        options = {},
      }

      -- Running configuration
      opts.run = {
        enabled = true,
      }

      -- Quickfix integration
      opts.quickfix = {
        enabled = true,
        open = false, -- Don't auto-open, use trouble instead
      }

      opts.log_level = vim.log.levels.WARN -- Less noisy than DEBUG

      -- Disable discovery to prevent scanning on startup
      opts.discovery = {
        enabled = false,
        concurrent = 1,
      }

      -- Diagnostic integration
      opts.diagnostic = {
        enabled = true,
        severity = vim.diagnostic.severity.ERROR,
      }

      -- Watch mode
      opts.watch = {
        enabled = true,
        symbol_queries = {},
      }

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

      -- Java/Kotlin: JUnit 4/5, TestNG, Kotest (via JUnit Platform runner)
      opts.adapters["neotest-java"] = {
        junit_jar = nil, -- auto-detected from Mason or project
        -- Automatically detected from pom.xml / build.gradle; override if needed:
        -- default_runner = "maven",  -- "maven" | "gradle"
        -- Suppress ByteBuddy dynamic agent warning on Java 21+
        jvm_args = { "-XX:+EnableDynamicAgentLoading" },
        root_dir = find_root { "pom.xml", "build.gradle", "build.gradle.kts", ".git" },
      }

      -- Ginkgo: for BDD-style Go tests (must be listed BEFORE neotest-golang)
      -- We use a numeric index to control ordering
      table.insert(opts.adapters, 1, {
        name = "neotest-ginkgo",
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
    config = function(_, opts)
      -- Set up highlight groups for neotest
      vim.api.nvim_set_hl(0, "NeotestPassed", { fg = "#50fa7b", bold = true })
      vim.api.nvim_set_hl(0, "NeotestFailed", { fg = "#ff5555", bold = true })
      vim.api.nvim_set_hl(0, "NeotestRunning", { fg = "#f1fa8c" })
      vim.api.nvim_set_hl(0, "NeotestSkipped", { fg = "#6272a4" })
      vim.api.nvim_set_hl(0, "NeotestTest", { fg = "#f8f8f2" })
      vim.api.nvim_set_hl(0, "NeotestNamespace", { fg = "#8be9fd" })
      vim.api.nvim_set_hl(0, "NeotestFile", { fg = "#bd93f9" })
      vim.api.nvim_set_hl(0, "NeotestDir", { fg = "#ffb86c" })
      vim.api.nvim_set_hl(0, "NeotestFocused", { fg = "#f8f8f2", bold = true, underline = true })
      vim.api.nvim_set_hl(0, "NeotestAdapterName", { fg = "#ff79c6", bold = true })
      vim.api.nvim_set_hl(0, "NeotestMarked", { fg = "#f1fa8c", bold = true })
      vim.api.nvim_set_hl(0, "NeotestTarget", { fg = "#ff5555" })
      vim.api.nvim_set_hl(0, "NeotestUnknown", { fg = "#6272a4" })
      vim.api.nvim_set_hl(0, "NeotestWatching", { fg = "#f1fa8c" })

      -- Call the original config
      require "configs.neotest"(_, opts)
    end,
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
          elseif ft == "java" or ft == "kotlin" then
            require("neotest").run.run { strategy = "dap" } -- use neotest-java DAP
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
