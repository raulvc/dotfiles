return function(_, opts)
  -- Python DAP setup
  pcall(function()
    require("dap-python").setup(vim.fn.stdpath "data" .. "/mason/packages/debugpy/venv/bin/python")
  end)

  -- Go DAP setup
  pcall(function()
    require("dap-go").setup()
  end)

  -- Rust DAP setup
  pcall(function()
    require("rust-tools").setup {}
  end)

  -- Helper to check if file is a ginkgo test
  local function is_ginkgo_file(file_path)
    if not vim.endswith(file_path, "_test.go") then
      return false
    end
    local file = io.open(file_path, "r")
    if not file then
      return false
    end
    local content = file:read "*a"
    file:close()
    return content:match "github.com/onsi/ginkgo" ~= nil
  end

  -- Adapter setup logic
  if opts.adapters then
    local adapters = {}
    local priority_adapters = {} -- For adapters that need to be first (like ginkgo)

    for name, config in pairs(opts.adapters or {}) do
      if type(name) == "number" then
        -- Handle priority adapters (numeric keys with table config)
        if type(config) == "table" and config.name then
          local adapter = require(config.name)
          local adapter_config = config.config or {}

          -- Inject is_test_file for ginkgo to only match actual ginkgo tests
          if config.name == "neotest-ginkgo" then
            -- Wrap the adapter to filter by file content
            local original_adapter = adapter
            adapter = setmetatable({}, {
              __call = function(_, ...)
                return original_adapter(...)
              end,
              __index = function(_, key)
                if key == "is_test_file" then
                  return is_ginkgo_file
                end
                return original_adapter[key]
              end,
            })
          end

          if type(adapter_config) == "table" and not vim.tbl_isempty(adapter_config) then
            local meta = getmetatable(adapter)
            if adapter.setup then
              adapter.setup(adapter_config)
            elseif adapter.adapter then
              adapter.adapter(adapter_config)
              adapter = adapter.adapter
            elseif meta and meta.__call then
              adapter = adapter(adapter_config)
            end
          end
          priority_adapters[#priority_adapters + 1] = adapter
        elseif type(config) == "string" then
          config = require(config)
          adapters[#adapters + 1] = config
        else
          adapters[#adapters + 1] = config
        end
      elseif config ~= false then
        local adapter = require(name)
        if type(config) == "table" and not vim.tbl_isempty(config) then
          local meta = getmetatable(adapter)
          if adapter.setup then
            adapter.setup(config)
          elseif adapter.adapter then
            adapter.adapter(config)
            adapter = adapter.adapter
          elseif meta and meta.__call then
            adapter = adapter(config)
          else
            error("Adapter " .. tostring(name) .. " does not support setup")
          end
        end
        adapters[#adapters + 1] = adapter
      end
    end

    -- Merge priority adapters first, then regular adapters
    opts.adapters = vim.list_extend(priority_adapters, adapters)
  end

  -- Add consumer for build failure notifications before setup
  opts.consumers = opts.consumers or {}
  opts.consumers.notify = function(client)
    client.listeners.results = function(adapter_id, results)
      for pos_id, result in pairs(results) do
        if result.status == "failed" and result.errors then
          for _, err in ipairs(result.errors) do
            if err.message then
              vim.notify(err.message, vim.log.levels.ERROR, { title = "Test Failed" })
            end
          end
        end
      end
    end
    return {}
  end

  -- Filter out any invalid buffers before neotest scans them
  -- to avoid "Invalid buffer id" errors in _update_open_buf_positions
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if not vim.api.nvim_buf_is_valid(buf) then
      pcall(vim.api.nvim_buf_delete, buf, { force = true })
    end
  end

  local ok, err = pcall(require("neotest").setup, opts)
  if not ok then
    vim.notify("Neotest setup failed: " .. tostring(err), vim.log.levels.WARN)
  end
end
