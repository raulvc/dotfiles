local M = {}

-- Get session-specific file path
local function get_session_file(suffix)
  local session_dir = vim.fn.stdpath "data" .. "/sessions"
  local session_name = vim.fn.fnamemodify(vim.fn.getcwd(), ":t")
  return session_dir .. "/" .. session_name .. suffix
end

-- Save nvim-tree state
M.save_nvim_tree_state = function()
  local nvim_tree_api = require "nvim-tree.api"
  local tree_winid = nvim_tree_api.tree.winid()
  local is_tree_open = tree_winid ~= nil and vim.api.nvim_win_is_valid(tree_winid)

  local file = io.open(get_session_file "_tree_state", "w")
  if file then
    file:write(tostring(is_tree_open))
    file:close()
    return true
  end
  return false
end

-- Restore nvim-tree state
M.restore_nvim_tree_state = function()
  local tree_state_file = get_session_file "_tree_state"
  if vim.fn.filereadable(tree_state_file) == 1 then
    local content = vim.fn.readfile(tree_state_file)
    local was_tree_open = content[1] == "true"

    local nvim_tree_api = require "nvim-tree.api"
    local tree_winid = nvim_tree_api.tree.winid()
    local is_tree_open = tree_winid ~= nil and vim.api.nvim_win_is_valid(tree_winid)

    if was_tree_open and not is_tree_open then
      nvim_tree_api.tree.open()
    elseif not was_tree_open and is_tree_open then
      nvim_tree_api.tree.close()
    end
    return true
  end
  return false
end

-- Save DAP breakpoints
M.save_dap_breakpoints = function()
  local breakpoints = require("dap.breakpoints").get()
  local bp_data = {}

  for file_path, file_breakpoints in pairs(breakpoints) do
    if #file_breakpoints > 0 then
      local relative_path = vim.fn.fnamemodify(file_path, ":.")
      bp_data[relative_path] = file_breakpoints
    end
  end

  if vim.tbl_count(bp_data) > 0 then
    local bp_file = get_session_file "_breakpoints.json"
    local file = io.open(bp_file, "w")
    if file then
      file:write(vim.fn.json_encode(bp_data))
      file:close()
      return vim.tbl_count(bp_data)
    end
  end
  return 0
end

-- Restore DAP breakpoints
M.restore_dap_breakpoints = function()
  local bp_file = get_session_file "_breakpoints.json"
  if vim.fn.filereadable(bp_file) == 1 then
    local ok, bp_content = pcall(function()
      local content = vim.fn.readfile(bp_file)
      return vim.fn.json_decode(table.concat(content, "\n"))
    end)

    if ok and bp_content then
      local dap = require "dap"
      local restored_count = 0

      for relative_path, file_breakpoints in pairs(bp_content) do
        local full_path = vim.fn.fnamemodify(relative_path, ":p")
        if vim.fn.filereadable(full_path) == 1 then
          for _, bp in ipairs(file_breakpoints) do
            dap.set_breakpoint(bp.condition, bp.hit_condition, bp.log_message, full_path, bp.line)
            restored_count = restored_count + 1
          end
        end
      end

      return restored_count
    end
  end
  return 0
end

-- Save all session extras
M.save_all = function()
  local tree_saved = M.save_nvim_tree_state()
  local bp_count = M.save_dap_breakpoints()

  local status = {}
  if tree_saved then
    table.insert(status, "tree state")
  end
  if bp_count > 0 then
    table.insert(status, bp_count .. " breakpoints")
  end

  if #status > 0 then
    vim.notify("💾 Saved: " .. table.concat(status, ", "), vim.log.levels.INFO)
  end
end

-- Restore all session extras
M.restore_all = function()
  vim.defer_fn(function()
    local tree_restored = M.restore_nvim_tree_state()
    local bp_count = M.restore_dap_breakpoints()

    local status = {}
    if tree_restored then
      table.insert(status, "tree state")
    end
    if bp_count > 0 then
      table.insert(status, bp_count .. " breakpoints")
    end

    if #status > 0 then
      vim.notify("🔄 Restored: " .. table.concat(status, ", "), vim.log.levels.INFO)
    end
  end, 500)
end

return M
