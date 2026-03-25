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

-- Read REQUESTER_TOKEN from file
local function get_requester_token()
  local token_file = vim.fn.expand "~/requester_token"
  local file = io.open(token_file, "r")
  if not file then
    vim.notify("Warning: Could not read ~/requester_token", vim.log.levels.WARN)
    return nil
  end
  local token = file:read "*all"
  file:close()
  -- Trim whitespace/newlines
  return token and token:match "^%s*(.-)%s*$" or nil
end

local REQUESTER_TOKEN = get_requester_token()

-- Set as global environment variable for all DAP sessions
if REQUESTER_TOKEN then
  vim.env.REQUESTER_TOKEN = REQUESTER_TOKEN
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
          ensure_installed = { "delve", "java-debug-adapter", "kotlin-debug-adapter" },
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

          local buf = vim.api.nvim_create_buf(false, true)
          local width = math.floor(vim.o.columns * 0.6)
          local height = 1

          local row = math.floor((vim.o.lines - height) / 2)
          local col = math.floor((vim.o.columns - width) / 2)

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

          vim.bo[buf].buftype = "prompt"
          vim.bo[buf].filetype = "dap-repl"

          vim.fn.prompt_setprompt(buf, "condition> ")

          vim.keymap.set("i", "<C-CR>", function()
            local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
            local condition = lines[1]:gsub("^condition> ", ""):gsub("^%s+", ""):gsub("%s+$", "")

            vim.api.nvim_win_close(win, true)

            if condition ~= "" then
              dap.set_breakpoint(condition)
              vim.notify("✓ Conditional breakpoint set: " .. condition, vim.log.levels.INFO)
            end
          end, { buffer = buf })

          vim.keymap.set({ "n", "i" }, "<Esc>", function()
            vim.api.nvim_win_close(win, true)
          end, { buffer = buf })

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
          require("dap-view").close(true)
          require("dap").terminate()
        end,
        desc = "[d]ebug [t]erminate",
      },
      {
        "<leader>dw",
        function()
          require("dap-view").add_expr()
        end,
        desc = "[d]ebug add [w]atch",
      },
      {
        "<leader>du",
        function()
          require("dap-view").toggle()
        end,
        desc = "[d]ap [u]i toggle",
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

      vim.api.nvim_set_hl(0, "DapBreakpoint", { fg = "#e51400" })
      vim.api.nvim_set_hl(0, "DapBreakpointCondition", { fg = "#f1c40f" })
      vim.api.nvim_set_hl(0, "DapBreakpointRejected", { fg = "#ec5f67" })
      vim.api.nvim_set_hl(0, "DapStopped", { fg = "#00ff00", bold = true })
      vim.api.nvim_set_hl(0, "DapStoppedLine", { bg = "#2d4635", fg = "#ffffff" })
    end,
  },
  {
    "theHamsta/nvim-dap-virtual-text",
    dependencies = { "mfussenegger/nvim-dap", "nvim-treesitter/nvim-treesitter" },
    config = function()
      require("nvim-dap-virtual-text").setup {
        enabled = true,
        enabled_commands = true,
        highlight_changed_variables = true,
        highlight_new_as_changed = false,
        show_stop_reason = true,
        commented = false,
        only_first_definition = true,
        all_references = false,
        virt_text_pos = "eol",
        all_frames = false,
        virt_text_win_col = nil,
        display_callback = function(variable, buf, stackframe, node, options)
          if #variable.value > 50 then
            return variable.name .. " = " .. string.sub(variable.value, 1, 47) .. "..."
          end
          return variable.name .. " = " .. variable.value
        end,
      }
    end,
  },

  {
    "igorlfs/nvim-dap-view",
    event = "VeryLazy",
    version = "1.*",
    dependencies = {
      "mfussenegger/nvim-dap",
    },
    opts = {
      winbar = {
        show = true,
        sections = { "watches", "scopes", "exceptions", "breakpoints", "threads", "repl", "console" },
        default_section = "scopes",
        controls = {
          enabled = true,
          position = "right",
          buttons = {
            "play",
            "step_into",
            "step_over",
            "step_out",
            "step_back",
            "run_last",
            "terminate",
            "disconnect",
          },
        },
      },
      windows = {
        size = 0.3,
        position = "below",
        terminal = {
          size = 0.5,
          position = "left",
          hide = { "delve" }, -- Hide built-in terminal for delve since you have custom one
        },
        anchor = function()
          -- Anchor to your custom debug terminal
          if DEBUG_TERMINAL.win and vim.api.nvim_win_is_valid(DEBUG_TERMINAL.win) then
            return DEBUG_TERMINAL.win
          end
        end,
      },

      switchbuf = "usetab,uselast",
      auto_toggle = true,
    },
    config = function(_, opts)
      local dap = require "dap"
      local dap_view = require "dap-view"

      dap_view.setup(opts)

      -- Go adapter using generic terminal
      dap.adapters.go = function(callback, config)
        debug_state.is_running = true

        local port = config.port or get_unused_port()
        local term_buf, term_win = create_debug_terminal "Go Debug Output"

        local pino_pretty_path = vim.fn.expand "/usr/bin/pino-pretty"
        local dlv_path = vim.fn.expand "/usr/bin/dlv"

        DEBUG_TERMINAL.job_id = vim.fn.jobstart({
          "bash",
          "-c",
          string.format("%s dap -l 127.0.0.1:%d 2>&1 | %s -c || cat", dlv_path, port, pino_pretty_path),
        }, {
          term = true,
          buffer = term_buf,
          cwd = config.cwd,

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
        end, 1000)
      end

      -- DAP event listeners for dap-view
      dap.listeners.after.event_initialized["dap_view_config"] = function()
        vim.cmd "silent! wall"
        vim.notify("🐛 Debug session started", vim.log.levels.INFO)
      end

      dap.listeners.before.event_terminated["dap_view_config"] = function()
        cleanup_debug_terminal()
      end

      dap.listeners.before.event_exited["dap_view_config"] = function()
        cleanup_debug_terminal()
      end

      -- Helper to build the full variable path from the scopes/watches view
      local function build_var_path_from_cursor()
        local current_line_num = vim.api.nvim_win_get_cursor(0)[1]
        local lines = vim.api.nvim_buf_get_lines(0, 0, current_line_num + 1, false)

        local function get_indent(line)
          local tabs = line:match "^(\t*)"
          return tabs and #tabs or 0
        end

        local function get_var_name(line)
          -- Skip lines that are just pointer dereference (icon = ... without a name)
          if line:match "^[\t]*%s*[󰅀󰅂]%s*=" then
            return nil
          end
          -- Handle map key/value patterns: [key 0], [val 0]
          local map_type, map_idx = line:match "%[(key)%s+(%d+)%]%s*="
          if not map_type then
            map_type, map_idx = line:match "%[(val)%s+(%d+)%]%s*="
          end
          if map_type and map_idx then
            return nil, map_type, map_idx
          end
          -- Handle array index [0], [1], etc.
          local idx = line:match "%[(%-?%d+)%]%s*="
          if idx then
            return "[" .. idx .. "]"
          end
          -- Try full expression after expand/collapse icon (watches view)
          -- Captures things like: 󰅀 campaigns[0].Campaign = ...
          local icon_expr = line:match "[󰅀󰅂]%s+([%w_%.%[%]]+)%s*="
          if icon_expr then
            return icon_expr
          end
          -- Extract name before " = "
          return line:match "([%w_]+)%s*="
        end

        local path_parts = {}
        local current_indent = get_indent(lines[current_line_num])
        local current_name, map_type, map_idx = get_var_name(lines[current_line_num])

        if map_type then
          return nil, map_type, map_idx, lines[current_line_num]
        end

        if current_name then
          table.insert(path_parts, 1, current_name)
        end

        local prev_indent = current_indent
        for i = current_line_num - 1, 1, -1 do
          local line = lines[i]
          local indent = get_indent(line)
          if indent < prev_indent then
            local name = get_var_name(line)
            if name then
              table.insert(path_parts, 1, name)
            end
            prev_indent = indent
            if indent == 0 then
              break
            end
          end
        end

        local var_name = ""
        for i, part in ipairs(path_parts) do
          if part:match "^%[" then
            var_name = var_name .. part
          elseif i == 1 then
            var_name = part
          else
            var_name = var_name .. "." .. part
          end
        end

        return var_name
      end

      -- Fix ESC in REPL to properly exit insert mode
      vim.api.nvim_create_autocmd("FileType", {
        pattern = { "dap-repl", "dap-view" },
        callback = function(ev)
          vim.keymap.set("i", "<Esc>", "<C-\\><C-n>", { buffer = ev.buf, silent = true, nowait = true })
          vim.keymap.set("n", "q", "<C-w>q", { buffer = ev.buf, silent = true })

          -- Evaluate .String() on the variable under cursor
          vim.keymap.set("n", "gs", function()
            local dap = require "dap"
            local session = dap.session()
            if not session then
              vim.notify("No active debug session", vim.log.levels.WARN)
              return
            end

            local var_name, map_type, map_idx, raw_line = build_var_path_from_cursor()

            -- Handle map key/value - extract UUID bytes directly from line
            if map_type then
              local bytes_str = raw_line:match "%[(%d+[%d,]+)%]"
              if bytes_str then
                local byte_values = {}
                for b in bytes_str:gmatch "%d+" do
                  table.insert(byte_values, tonumber(b))
                end
                if #byte_values == 16 then
                  local uuid_str = string.format(
                    "%02x%02x%02x%02x-%02x%02x-%02x%02x-%02x%02x-%02x%02x%02x%02x%02x%02x",
                    byte_values[1],
                    byte_values[2],
                    byte_values[3],
                    byte_values[4],
                    byte_values[5],
                    byte_values[6],
                    byte_values[7],
                    byte_values[8],
                    byte_values[9],
                    byte_values[10],
                    byte_values[11],
                    byte_values[12],
                    byte_values[13],
                    byte_values[14],
                    byte_values[15],
                    byte_values[16]
                  )
                  vim.lsp.util.open_floating_preview(
                    { "[" .. map_type .. " " .. map_idx .. '].String() = "' .. uuid_str .. '"' },
                    "go",
                    { border = "rounded", title = " String() ", title_pos = "center" }
                  )
                  return
                end
              end
              vim.notify("Could not extract UUID from map key/value", vim.log.levels.WARN)
              return
            end

            if not var_name or var_name == "" then
              vim.notify("Could not extract variable name", vim.log.levels.WARN)
              return
            end

            vim.notify("Evaluating " .. var_name .. ".String()", vim.log.levels.INFO)

            session:evaluate("call " .. var_name .. ".String()", function(err, resp)
              vim.schedule(function()
                if err then
                  vim.lsp.util.open_floating_preview(
                    { "Error: " .. tostring(err) },
                    "text",
                    { border = "rounded", title = " Error ", title_pos = "center" }
                  )
                elseif resp and resp.result then
                  vim.lsp.util.open_floating_preview(
                    { var_name .. ".String() = " .. resp.result },
                    "go",
                    { border = "rounded", title = " String() ", title_pos = "center" }
                  )
                else
                  vim.lsp.util.open_floating_preview({ "No result" }, "text", { border = "rounded" })
                end
              end)
            end)
          end, { buffer = ev.buf, silent = true, desc = "Evaluate .String()" })

          -- Add variable under cursor (with full path) to watches
          vim.keymap.set("n", "w", function()
            local var_name = build_var_path_from_cursor()

            if not var_name or var_name == "" then
              vim.notify("Could not extract variable path", vim.log.levels.WARN)
              return
            end

            require("dap-view").add_expr(var_name)
            vim.notify("Added watch: " .. var_name, vim.log.levels.INFO)
          end, { buffer = ev.buf, silent = true, desc = "Add variable path to watches" })
        end,
      })

      dap.configurations.go = {
        {
          type = "go",
          name = "Debug current package",
          request = "launch",
          mode = "debug",
          program = "${workspaceFolder}",
        },
        {
          type = "go",
          name = "Debug current directory",
          request = "launch",
          mode = "debug",
          program = "${fileDirname}",
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

      -- Java DAP adapter (java-debug-adapter installed via Mason)
      dap.adapters.java = function(callback, config)
        local port = config.port or get_unused_port()
        local java_debug_jar = vim.fn.glob(
          vim.fn.stdpath "data"
            .. "/mason/packages/java-debug-adapter/extension/server/com.microsoft.java.debug.plugin-*.jar"
        )

        if java_debug_jar == "" then
          vim.notify("java-debug-adapter not found. Install via :MasonInstall java-debug-adapter", vim.log.levels.ERROR)
          return
        end

        callback {
          type = "server",
          host = "127.0.0.1",
          port = port,
          enrich_config = function(final_config, on_config)
            -- If using nvim-jdtls, it handles starting the debug adapter
            on_config(final_config)
          end,
        }
      end

      dap.configurations.java = {
        {
          type = "java",
          request = "launch",
          name = "Launch Java Test (current file)",
          mainClass = "",
          projectName = "",
          cwd = "${workspaceFolder}",
        },
        {
          type = "java",
          request = "attach",
          name = "Attach to Java process",
          hostName = "127.0.0.1",
          port = 5005,
        },
      }

      -- Kotlin DAP adapter (kotlin-debug-adapter installed via Mason)
      dap.adapters.kotlin = {
        type = "executable",
        command = vim.fn.stdpath "data" .. "/mason/packages/kotlin-debug-adapter/bin/kotlin-debug-adapter",
        options = {
          auto_continue_if_many_stopped = false,
        },
      }

      dap.configurations.kotlin = {
        {
          type = "kotlin",
          request = "launch",
          name = "Launch Kotlin Test",
          projectRoot = "${workspaceFolder}",
          mainClass = "",
        },
        {
          type = "kotlin",
          request = "attach",
          name = "Attach to Kotlin process",
          hostName = "127.0.0.1",
          port = 5005,
          timeout = 10000,
        },
      }
    end,
  },
}
