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
    for name, config in pairs(opts.adapters or {}) do
      if type(name) == "number" then
        if type(config) == "string" then
          config = require(config)
        end
        adapters[#adapters + 1] = config
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
            adapter(config)
          else
            error("Adapter " .. tostring(name) .. " does not support setup")
          end
        end
        adapters[#adapters + 1] = adapter
      end
    end
    opts.adapters = adapters
  end

  require("neotest").setup(opts)
end
