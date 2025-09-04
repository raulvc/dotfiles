local M = {}

local path = vim.fn.stdpath "config" .. "/breakpoints.json"

local function read_saved()
  local f = io.open(path, "r")
  if not f then
    return {}
  end
  local ok, decoded = pcall(vim.fn.json_decode, f:read "*a" or "")
  f:close()
  if not ok or type(decoded) ~= "table" then
    return {}
  end
  return decoded
end

local function write_saved(tbl)
  local f = io.open(path, "w")
  if not f then
    vim.notify("Error writing breakpoints to file", vim.log.levels.ERROR)
    return
  end
  f:write(vim.fn.json_encode(tbl))
  f:close()
end

local function set_for_buffer(bufnr, file)
  if not file or file == "" then
    return
  end
  local saved = read_saved()
  local entries = saved[file]
  if not entries or #entries == 0 then
    return
  end

  local dap_bps = require "dap.breakpoints"
  local current = dap_bps.get()[bufnr] or {}
  local existing = {}
  for _, bp in ipairs(current) do
    existing[bp.line] = true
  end

  for _, bp in ipairs(entries) do
    if not existing[bp.line] then
      dap_bps.set({
        condition = bp.condition,
        log_message = bp.logMessage,
        hit_condition = bp.hitCondition,
      }, bufnr, bp.line)
    end
  end
end

function M.save()
  local dap_bps = require("dap.breakpoints").get()
  local out = {}
  for bufnr, list in pairs(dap_bps) do
    local file = vim.api.nvim_buf_get_name(bufnr)
    if file ~= "" and type(list) == "table" and #list > 0 then
      out[file] = {}
      for _, bp in ipairs(list) do
        table.insert(out[file], {
          line = bp.line,
          condition = bp.condition,
          logMessage = bp.logMessage,
          hitCondition = bp.hitCondition,
        })
      end
    end
  end
  write_saved(out)
  vim.notify("Breakpoints saved", vim.log.levels.INFO)
end

function M.restore()
  -- Apply to all currently loaded buffers
  local bufs = vim.api.nvim_list_bufs()
  for _, b in ipairs(bufs) do
    if vim.api.nvim_buf_is_loaded(b) then
      local file = vim.api.nvim_buf_get_name(b)
      set_for_buffer(b, file)
    end
  end
  vim.notify("Breakpoints restored", vim.log.levels.INFO)
end

function M.on_buf_read(bufnr, file)
  set_for_buffer(bufnr, file)
end

function M.setup_autocmds()
  vim.api.nvim_create_autocmd("BufReadPost", {
    pattern = "*",
    callback = function(ev)
      M.on_buf_read(ev.buf, ev.file)
    end,
  })

  -- Auto-save breakpoints when they change
  vim.api.nvim_create_autocmd("User", {
    pattern = "DapBreakpointChanged",
    callback = function()
      vim.defer_fn(function()
        M.save()
      end, 100) -- Small delay to ensure all changes are processed
    end,
  })

  -- Save on exit
  vim.api.nvim_create_autocmd("VimLeavePre", {
    callback = function()
      M.save()
    end,
  })
end

return M
