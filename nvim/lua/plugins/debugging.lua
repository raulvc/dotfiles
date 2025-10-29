-- Generic terminal configuration for all debug sessions
local DEBUG_TERMINAL = {
  height = 8,
  buf = nil,
  win = nil,
  job_id = nil,
}

local debug_state = {
  is_running = false,
  first_run = true,
}

local function get_unused_port()
  local uv = vim.loop
  local server = uv.new_tcp()
  assert(server:bind("127.0.0.1", 0)) -- OS allocates an unused port
  local tcp_t = server:getsockname()
  server:close()
  assert(tcp_t and tcp_t.port > 0, "Failed to get an unused port")
  return tcp_t.port
end

-- Generic function to create debug terminal
local function create_debug_terminal(name)
  -- Clean up existing terminal
  if DEBUG_TERMINAL.job_id then
    vim.fn.jobstop(DEBUG_TERMINAL.job_id)
    DEBUG_TERMINAL.job_id = nil
  end

  if DEBUG_TERMINAL.win and vim.api.nvim_win_is_valid(DEBUG_TERMINAL.win) then
    pcall(vim.api.nvim_win_close, DEBUG_TERMINAL.win, true)
  end

  if DEBUG_TERMINAL.buf and vim.api.nvim_buf_is_valid(DEBUG_TERMINAL.buf) then
    pcall(vim.api.nvim_buf_delete, DEBUG_TERMINAL.buf, { force = true })
  end

  -- Create new terminal buffer
  DEBUG_TERMINAL.buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(DEBUG_TERMINAL.buf, name or "Debug Output")

  -- Set buffer options for auto-scroll
  vim.api.nvim_buf_set_option(DEBUG_TERMINAL.buf, "scrolloff", 0)

  -- Create terminal window
  vim.cmd("botright " .. DEBUG_TERMINAL.height .. "split")
  DEBUG_TERMINAL.win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(DEBUG_TERMINAL.win, DEBUG_TERMINAL.buf)

  -- Set window options for auto-scroll
  vim.api.nvim_win_set_option(DEBUG_TERMINAL.win, "scrolloff", 0)
  vim.api.nvim_win_set_option(DEBUG_TERMINAL.win, "wrap", false)

  return DEBUG_TERMINAL.buf, DEBUG_TERMINAL.win
end

-- Auto-scroll function
local function auto_scroll_terminal()
  if
    DEBUG_TERMINAL.win
    and vim.api.nvim_win_is_valid(DEBUG_TERMINAL.win)
    and DEBUG_TERMINAL.buf
    and vim.api.nvim_buf_is_valid(DEBUG_TERMINAL.buf)
  then
    local line_count = vim.api.nvim_buf_line_count(DEBUG_TERMINAL.buf)
    vim.api.nvim_win_set_cursor(DEBUG_TERMINAL.win, { line_count, 0 })
  end
end

-- Generic cleanup function
local function cleanup_debug_terminal()
  debug_state.is_running = false

  if DEBUG_TERMINAL.job_id then
    vim.fn.jobstop(DEBUG_TERMINAL.job_id)
    DEBUG_TERMINAL.job_id = nil
  end

  if DEBUG_TERMINAL.win and vim.api.nvim_win_is_valid(DEBUG_TERMINAL.win) then
    pcall(vim.api.nvim_win_close, DEBUG_TERMINAL.win, true)
    DEBUG_TERMINAL.win = nil
  end

  if DEBUG_TERMINAL.buf and vim.api.nvim_buf_is_valid(DEBUG_TERMINAL.buf) then
    pcall(vim.api.nvim_buf_delete, DEBUG_TERMINAL.buf, { force = true })
    DEBUG_TERMINAL.buf = nil
  end

  if debug_state.first_run then
    -- Kill all delve processes including telemetry
    vim.fn.jobstart({
      "bash",
      "-c",
      [[
    echo "Finding delve processes..."
    pgrep -f dlv | while read pid; do
      echo "Killing delve process: $pid"
      kill -9 "$pid" 2>/dev/null || true
    done
    ]],
    }, {
      detach = true,
      on_stdout = function(_, data)
        if data and #data > 0 then
          for _, line in ipairs(data) do
            if line ~= "" then
              print("Kill output:", line)
            end
          end
        end
      end,
    })

    -- Clean up debug files since delve doesn't do it reliably
    local cwd = vim.fn.getcwd()
    vim.defer_fn(function()
      vim.fn.jobstart({
        "bash",
        "-c",
        string.format("cd '%s' && rm __debug_bin* 2>/dev/null || true", cwd),
      }, { detach = true })
    end, 100) -- Small delay to let processes finish

    debug_state.first_run = false
  end
end

local dap_breakpoints = require "configs.dap_breakpoints"
dap_breakpoints.setup_autocmds()

local function show_breakpoints_telescope()
  local dap = require "dap"
  local dap_breakpoints = require "dap.breakpoints"
  local breakpoints = dap_breakpoints.get()

  -- Convert breakpoints to quickfix format for telescope
  local qf_list = {}
  for buf, buf_bps in pairs(breakpoints) do
    local filepath = vim.api.nvim_buf_get_name(buf)
    if filepath and filepath ~= "" then
      for _, bp in ipairs(buf_bps) do
        table.insert(qf_list, {
          filename = filepath,
          lnum = bp.line,
          col = 1,
          text = string.format(
            "%s%s",
            bp.condition and "🟡 " or "🔴 ",
            bp.condition and ("condition: " .. bp.condition) or "breakpoint"
          ),
        })
      end
    end
  end

  if #qf_list == 0 then
    vim.notify("No breakpoints set", vim.log.levels.INFO)
    return
  end

  -- Use telescope to display breakpoints
  require("telescope.pickers")
    .new({}, {
      prompt_title = "DAP Breakpoints",
      finder = require("telescope.finders").new_table {
        results = qf_list,
        entry_maker = require("telescope.make_entry").gen_from_quickfix(),
      },
      sorter = require("telescope.config").values.generic_sorter {},
      previewer = require("telescope.config").values.qflist_previewer {},
      attach_mappings = function(prompt_bufnr, map)
        local actions = require "telescope.actions"
        local action_state = require "telescope.actions.state"

        -- Delete breakpoint with 'd'
        map("n", "d", function()
          local selection = action_state.get_selected_entry()
          if selection then
            -- Find and remove the breakpoint
            local buf = vim.fn.bufnr(selection.filename)
            if buf ~= -1 then
              -- Set cursor to the breakpoint line and toggle it
              local current_win = vim.api.nvim_get_current_win()
              vim.api.nvim_win_set_buf(current_win, buf)
              vim.api.nvim_win_set_cursor(current_win, { selection.lnum, 0 })
              dap.toggle_breakpoint()
              vim.notify("Breakpoint removed", vim.log.levels.INFO)
            end
            -- Refresh the picker
            actions.close(prompt_bufnr)
            vim.schedule(show_breakpoints_telescope)
          end
        end)

        return true
      end,
    })
    :find()
end

return {

  {
    "mfussenegger/nvim-dap",
    event = "VeryLazy",
    lazy = false,
    priority = 1500,
    dependencies = {
      {
        "jay-babu/mason-nvim-dap.nvim",
        dependencies = {
          "mason-org/mason.nvim",
        },
        opts = {
          ensure_installed = { "delve" },
          automatic_installation = true,
        },
      },
      {
        "theHamsta/nvim-dap-virtual-text",
      },
      {
        "leoluz/nvim-dap-go",
        ft = "go",
        config = function()
          require("dap-go").setup()
        end,
      },
      {
        "LiadOz/nvim-dap-repl-highlights",
        dependencies = { "nvim-treesitter/nvim-treesitter" },
        config = function()
          require("nvim-dap-repl-highlights").setup()
        end,
      },
    },
    keys = {
      {
        "<leader>db",
        function()
          require("dap").toggle_breakpoint()
        end,

        desc = "toggle [d]ebug [b]reakpoint",
      },
      {
        "<leader>dB",
        function()
          local dap = require "dap"

          -- Create floating buffer
          local buf = vim.api.nvim_create_buf(false, true)
          local width = math.floor(vim.o.columns * 0.6)
          local height = 1

          -- Calculate center position
          local row = math.floor((vim.o.lines - height) / 2)
          local col = math.floor((vim.o.columns - width) / 2)

          -- Open floating window
          local win = vim.api.nvim_open_win(buf, true, {
            relative = "editor",
            width = width,
            height = height,
            row = row,
            col = col,
            style = "minimal",
            border = "rounded",
            title = " Breakpoint Condition ",
            title_pos = "center",
          })

          -- Set buffer options for REPL-like behavior
          vim.bo[buf].buftype = "prompt"
          vim.bo[buf].filetype = "dap-repl" -- This enables DAP autocomplete!

          -- Set the prompt
          vim.fn.prompt_setprompt(buf, "condition> ")

          -- Handle Ctrl+Enter to set breakpoint
          vim.keymap.set("i", "<C-CR>", function()
            local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
            local condition = lines[1]:gsub("^condition> ", ""):gsub("^%s+", ""):gsub("%s+$", "")

            -- Close the floating window
            vim.api.nvim_win_close(win, true)

            if condition ~= "" then
              dap.set_breakpoint(condition)
              vim.notify("✓ Conditional breakpoint set: " .. condition, vim.log.levels.INFO)
            end
          end, { buffer = buf })

          -- Handle Escape to cancel
          vim.keymap.set({ "n", "i" }, "<Esc>", function()
            vim.api.nvim_win_close(win, true)
          end, { buffer = buf })

          -- Start in insert mode
          vim.cmd "startinsert"
        end,
        desc = "[d]ebug conditional [B]reakpoint",
      },

      {
        "<leader>dc",
        function()
          require("dap").continue()
        end,
        desc = "[d]ebug [c]ontinue (start here)",
      },

      {
        "<F9>",
        function()
          require("dap").continue()
        end,
        desc = "[d]ebug [c]ontinue (start here)",
      },

      {
        "<leader>dC",
        function()
          require("dap").run_to_cursor()
        end,
        desc = "[d]ebug [C]ursor",
      },
      {
        "<leader>dg",
        function()
          require("dap").goto_()
        end,
        desc = "[d]ebug [g]o to line",
      },
      {
        "<leader>do",
        function()
          require("dap").step_over()
        end,
        desc = "[d]ebug step [o]ver",
      },
      {
        "<leader>dO",
        function()
          require("dap").step_out()
        end,
        desc = "[d]ebug step [O]ut",
      },
      {
        "<F8>",
        function()
          require("dap").step_over()
        end,
        desc = "[d]ebug step [o]ver",
      },
      {
        "<leader>di",
        function()
          require("dap").step_into()
        end,
        desc = "[d]ebug [i]nto",
      },
      {
        "<leader>dj",
        function()
          require("dap").down()
        end,
        desc = "[d]ebug [j]ump down",
      },
      {
        "<leader>dk",
        function()
          require("dap").up()
        end,
        desc = "[d]ebug [k]ump up",
      },
      {
        "<leader>dl",
        function()
          require("dap").run_last()
        end,
        desc = "[d]ebug [l]ast",
      },
      {
        "<leader>dp",
        function()
          require("dap").pause()
        end,
        desc = "[d]ebug [p]ause",
      },
      {
        "<leader>dr",
        function()
          require("dap").repl.toggle()
        end,
        desc = "[d]ebug [r]epl",
      },
      {
        "<leader>dR",
        function()
          require("dap").clear_breakpoints()
        end,
        desc = "[d]ebug [R]emove breakpoints",
      },
      {
        "<leader>dL",
        function()
          show_breakpoints_telescope()
        end,
        desc = "[d]ebug [L]ist breakpoints",
      },
      {
        "<leader>ds",
        function()
          require("dap").session()
        end,
        desc = "[d]ebug [s]ession",
      },
      {
        "<leader>dt",
        function()
          cleanup_debug_terminal()
          require("dapui").close()
          require("dap").terminate()
        end,
        desc = "[d]ebug [t]erminate",
      },
      {
        "<leader>dw",
        function()
          require("dap.ui.widgets").hover()
        end,
        desc = "[d]ebug [w]idgets",
      },
    },
    config = function()
      vim.fn.sign_define("DapBreakpoint", {
        text = "🔴",
        texthl = "DapBreakpoint",
        linehl = "",
        numhl = "DapBreakpoint",
      })
      vim.fn.sign_define("DapBreakpointCondition", {
        text = "🟡",
        texthl = "DapBreakpointCondition",
        linehl = "",
        numhl = "DapBreakpointCondition",
      })
      vim.fn.sign_define("DapBreakpointRejected", {
        text = "⭕",
        texthl = "DapBreakpointRejected",
        linehl = "",
        numhl = "DapBreakpointRejected",
      })
      -- 🎯 Enhanced stopped line configuration
      vim.fn.sign_define("DapStopped", {
        text = "👉",
        texthl = "DapStopped",
        linehl = "DapStoppedLine",
        numhl = "DapStopped",
      })
      vim.fn.sign_define("DapLogPoint", {
        text = "📝",
        texthl = "DapLogPoint",
        linehl = "",
        numhl = "",
      })

      -- 🌈 Enhanced highlight groups for better visibility
      vim.api.nvim_set_hl(0, "DapBreakpoint", { fg = "#e51400" })
      vim.api.nvim_set_hl(0, "DapBreakpointCondition", { fg = "#f1c40f" })
      vim.api.nvim_set_hl(0, "DapBreakpointRejected", { fg = "#ec5f67" })

      -- 🎯 Critical: Stopped line highlighting
      vim.api.nvim_set_hl(0, "DapStopped", { fg = "#00ff00", bold = true })
      vim.api.nvim_set_hl(0, "DapStoppedLine", { bg = "#2d4635", fg = "#ffffff" }) -- Green background
    end,
  },
  {
    "theHamsta/nvim-dap-virtual-text",
    dependencies = { "mfussenegger/nvim-dap", "nvim-treesitter/nvim-treesitter" },
    config = function()
      require("nvim-dap-virtual-text").setup {}
    end,
  },

  {
    "rcarriga/nvim-dap-ui",
    event = "VeryLazy",
    dependencies = {
      "nvim-neotest/nvim-nio",
      "mfussenegger/nvim-dap",
    },
    opts = {
      force_buffers = true,
      layouts = {
        {
          elements = {
            { id = "stacks", size = 0.25 },
            { id = "scopes", size = 0.35 },
            { id = "repl", size = 0.25 },
            { id = "watches", size = 0.15 },
          },
          position = "left",
          size = 40,
        },
      },
      render = {
        indent = 1,
        max_value_lines = 3,
        sort_variables = function(a, b)
          -- Don't sort if either is a slice/array element (contains brackets)
          local a_is_indexed = a.name:match "%[%d+%]"
          local b_is_indexed = b.name:match "%[%d+%]"

          if a_is_indexed and b_is_indexed then
            -- Extract numeric indices and compare numerically
            local a_idx = tonumber(a.name:match "%[(%d+)%]")
            local b_idx = tonumber(b.name:match "%[(%d+)%]")
            if a_idx and b_idx then
              return a_idx < b_idx
            end
          end

          -- Sort by scope first
          if a.scope ~= b.scope then
            local order = { ["Locals"] = 1, ["Arguments"] = 2, ["Globals"] = 3 }
            return (order[a.scope] or 99) < (order[b.scope] or 99)
          end

          -- Alphabetical for non-indexed variables
          return a.name < b.name
        end,
      },

      element_mappings = {
        scopes = {
          edit = "e",
          expand = { "<CR>", "<2-LeftMouse>" },
          repl = "r",
        },
      },
      expand_lines = vim.fn.has "nvim-0.7" == 1,
      mappings = {
        expand = { "<CR>", "<2-LeftMouse>" },
        open = "o",
        remove = "d",
        edit = "e",
        repl = "r",
        toggle = "t",
      },
      floating = {
        max_height = nil,
        max_width = nil,
        border = "single",
        mappings = {
          close = { "q", "<Esc>" },
        },
      },
    },
    config = function(_, opts)
      local dap = require "dap"
      local dapui = require "dapui"

      -- Go adapter using generic terminal
      dap.adapters.go = function(callback, config)
        debug_state.is_running = true

        -- Add a small delay on first run to ensure clean state
        local delay = DEBUG_TERMINAL.job_id and 0 or 100 -- 100ms delay only on first run

        local port = config.port or get_unused_port()
        local term_buf, term_win = create_debug_terminal "Go Debug Output"

        DEBUG_TERMINAL.job_id = vim.fn.jobstart({
          "bash",
          "-c",
          "/home/raul/go/bin/dlv dap -l 127.0.0.1:"
            .. port
            .. ' 2>&1 | while IFS= read -r line; do echo "$line" | /home/raul/.nvm/versions/node/v20.11.0/bin/pino-pretty -c . 2>/dev/null || echo "$line"; done',
        }, {
          term = true,
          buffer = term_buf,
          cwd = config.cwd, -- Set working directory

          on_stdout = function()
            auto_scroll_terminal()
          end,
          on_stderr = function()
            auto_scroll_terminal()
          end,
          on_exit = function(job_id, exit_code)
            debug_state.is_running = false
            DEBUG_TERMINAL.job_id = nil
            vim.notify("Delve process exited with code: " .. exit_code, vim.log.levels.INFO)
          end,
        })

        if DEBUG_TERMINAL.job_id <= 0 then
          callback(nil, "Failed to start dlv")
          cleanup_debug_terminal()
          return
        end

        vim.defer_fn(function()
          callback { type = "server", host = "127.0.0.1", port = port }
        end, 1000) -- Increase to 1 second to ensure delve is ready
      end

      dap.listeners.after.event_initialized["dapui_config"] = function()
        vim.cmd "silent! wall"
        local ok, err = pcall(function()
          dapui.open()
        end)
        if not ok then
          vim.notify("Failed to open DAP UI: " .. tostring(err), vim.log.levels.WARN)
          vim.cmd "silent! wall!"
          dapui.open()
        end
        vim.notify("🐛 Debug session started", vim.log.levels.INFO)
      end

      dap.listeners.before.event_terminated["dapui_config"] = function()
        cleanup_debug_terminal()
        dapui.close()
      end

      dap.listeners.before.event_exited["dapui_config"] = function()
        cleanup_debug_terminal()
        dapui.close()
      end

      dapui.setup(opts)

      dap.configurations.go = {
        {
          type = "go",
          name = "Debug",
          request = "launch",
          program = "${file}",
        },
      }

      dap.adapters["pwa-node"] = function(callback, config)
        local port = config.port or get_unused_port()

        local handle = vim.fn.jobstart({
          "node",
          vim.fn.stdpath "data" .. "/mason/packages/js-debug-adapter/js-debug/src/dapDebugServer.js",
          tostring(port),
        }, {
          detach = true,
          on_exit = function()
            vim.notify("js-debug-adapter process exited", vim.log.levels.INFO)
          end,
        })

        if handle <= 0 then
          callback(nil, "Failed to start js-debug-adapter")
          return
        end

        -- Wait for the adapter to start
        vim.defer_fn(function()
          callback {
            type = "server",
            host = "127.0.0.1",
            port = port,
          }
        end, 1000)
      end

      dap.configurations.typescript = {
        {
          type = "pwa-node",
          request = "launch",
          name = "Launch TypeScript file",
          program = "${file}",
          cwd = "${workspaceFolder}",
          sourceMaps = true,
          protocol = "inspector",
          console = "integratedTerminal",
          outFiles = { "${workspaceFolder}/dist/**/*.js" },
          runtimeArgs = { "--loader", "ts-node/esm" },
        },
        {
          type = "pwa-node",
          request = "launch",
          name = "Launch Jest Tests",
          -- trace = true, -- include debugger info
          runtimeExecutable = "node",
          runtimeArgs = {
            "./node_modules/jest/bin/jest.js",
            "--runInBand",
            "${file}",
          },
          rootPath = "${workspaceFolder}",
          cwd = "${workspaceFolder}",
          console = "integratedTerminal",
          internalConsoleOptions = "neverOpen",
        },
        {
          type = "pwa-node",
          request = "attach",
          name = "Attach to Node.js",
          processId = require("dap.utils").pick_process,
          cwd = "${workspaceFolder}",
        },
      }

      dap.configurations.javascript = dap.configurations.typescript
    end,
    keys = {
      {
        "<leader>du",
        function()
          require("dapui").toggle {}
        end,
        desc = "[d]ap [u]i",
      },
      {
        "<leader>dev",
        function()
          -- Evaluate variable as string
          local word = vim.fn.expand "<cword>"
          require("dapui").eval("string(" .. word .. ")")
        end,
        desc = "[d]ap [e]val as string",
      },
      {
        "<leader>deb",
        function()
          -- Evaluate byte array as string
          local word = vim.fn.expand "<cword>"
          require("dapui").eval('fmt.Sprintf("%s", ' .. word .. ")")
        end,
        desc = "[d]ap [e]val [b]ytes as string",
      },
    },
  },
}
