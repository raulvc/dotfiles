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

  require("neotest").setup(opts)
end
