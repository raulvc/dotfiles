-- add yours here

local map = vim.keymap.set

map("n", ";", ":", { desc = "CMD enter command mode" })
map("i", "jk", "<ESC>")
-- map({ "n", "i", "v" }, "<C-s>", "<cmd> w <cr>")
--
-- Splitting (matching zellij behavior)
--
map("n", "<M-S-e>", ":vsplit<CR>", { desc = "Split vertically (Alt+Shift+E)" })
map("n", "<M-S-o>", ":split<CR>", { desc = "Split horizontally (Alt+Shift+O)" })
--
---- Close window
local function smart_close()
  local success = pcall(function()
    local buf = vim.api.nvim_get_current_buf()
    local wins = vim.fn.win_findbuf(buf)

    if #wins > 1 then
      -- Multiple windows with same buffer - close window only
      vim.cmd "close"
    else
      -- Only one window with this buffer - close buffer
      local bufferline = require "bufferline"
      if bufferline and bufferline.close_buffer then
        bufferline.close_buffer(buf)
      else
        -- Fallback
        vim.cmd "bd"
      end
    end
  end)

  if not success then
    -- Default to force quit on any error
    vim.cmd "q!"
  end
end

map("n", "<M-S-w>", smart_close, { desc = "Close buffer" })

---- Opens last closed buffer
vim.keymap.set("n", "<C-Tab>", function()
  require("telescope.builtin").oldfiles {
    prompt_title = "Recently Closed",
    only_cwd = true,
    cwd_only = true,
  }
end, { desc = "Recently closed files" })

---- Window resizing (matching zellij resize)
map("n", "<M-j>", ":resize +2<CR>", { desc = "Resize up (Alt+Shift+Up)" })
map("n", "<M-k>", ":resize -2<CR>", { desc = "Resize down (Alt+Shift+Down)" })
map("n", "<M-n>", ":vertical resize +2<CR>", { desc = "Resize right (Alt+Shift+Right)" })
map("n", "<M-m>", ":vertical resize -2<CR>", { desc = "Resize left (Alt+Shift+Left)" })

-- Alt + Arrow keys for window navigation
map("n", "<M-Left>", "<C-w>h", { desc = "Move to left window" })
map("n", "<M-Right>", "<C-w>l", { desc = "Move to right window" })
map("n", "<M-Up>", "<C-w>k", { desc = "Move to top window" })
map("n", "<M-Down>", "<C-w>j", { desc = "Move to bottom window" })

-- Bind Alt + Shift + X to toggle zoom
map("n", "<M-S-x>", function()
  Snacks.zen.zoom()
end, { desc = "Toggle zoom pane (Snacks)" })

-- Enhanced JetBrains-style navigation
map("n", "<M-S-Left>", "<C-o>", { desc = "Navigate back" })
map("n", "<M-S-Right>", "<C-i>", { desc = "Navigate forward" })
-- Tab navigation
map("n", "<C-PageUp>", ":BufferLineCyclePrev<CR>", { desc = "Previous tab" })
map("n", "<C-PageDown>", ":BufferLineCycleNext<CR>", { desc = "Next tab" })

-- === FILE SEARCH (Ctrl+P) ===
map("n", "<C-p>", function()
  require("telescope.builtin").find_files {
    hidden = true, -- Show hidden files
    no_ignore = false, -- Respect .gitignore
  }
end, { desc = "Go to File (Ctrl+P)" })
-- === SEARCH IN FILES (Alt + Shift + s) ===
map("n", "<M-S-f>", function()
  require("telescope.builtin").live_grep()
end, { desc = "Search in files" })

-- Command search
map("n", "<C-S-p>", ":Telescope commands<CR>", { desc = "Find Commands" })

map({ "n", "v" }, "<M-f>", function()
  require("conform").format { async = true, lsp_fallback = true }
end, { desc = "Format document" })

map("n", "<M-S-l>", function()
  print "Running linter..."
  require("lint").try_lint()
end, { desc = "Run linter" })

local mc = require "multicursor-nvim"

vim.keymap.set({ "n", "v" }, "<Esc>", function()
  if mc.hasCursors() then
    mc.clearCursors()
  else
    vim.cmd "silent! NoiceDismiss"
    vim.cmd "silent! noh"
    vim.cmd "silent! fclose" -- Close floating windows
    return "<Esc>"
  end
end, { expr = true, desc = "Smart Esc" })

map({ "n", "i" }, "<C-S-a>", function()
  if vim.fn.mode() == "i" then
    vim.cmd "stopinsert"
  end

  -- Get buffer info
  local last_line = vim.api.nvim_buf_line_count(0)
  local last_line_content = vim.api.nvim_buf_get_lines(0, last_line - 1, last_line, false)[1] or ""

  -- Position cursor at start
  vim.api.nvim_win_set_cursor(0, { 1, 0 })

  -- Enter visual mode and select to end
  vim.cmd "normal! v"
  vim.api.nvim_win_set_cursor(0, { last_line, #last_line_content })
end, { desc = "Select all" })

map({ "n", "v" }, "d", '"_d', { desc = "Delete without yanking" })
map({ "n", "v" }, "c", '"_c', { desc = "Change without yanking" })
map("n", "D", '"_D', { desc = "Delete to end of line without yanking" })
map("n", "dd", '"_dd')

-- Normal mode indentation
map("n", "<S-Tab>", "<<", { desc = "Unindent" })
map("n", "<Tab>", ">>", { desc = "Indent" })

-- Insert mode indentation
map("i", "<S-Tab>", "<C-d>", { desc = "Unindent in insert mode" })

-- Visual mode indentation (keeps selection after indenting)
map("v", "<Tab>", ">gv", { desc = "Indent selection" })
map("v", "<S-Tab>", "<gv", { desc = "Unindent selection" })

map("n", "<leader>co", ":BufferLineCloseOthers<CR>", { desc = "Close other buffers (bufferline)" })

map("v", "<leader>gd", ":'<,'>AdvancedGitSearch diff_commit_line<CR>", { desc = "Git diff commit for selection" })

map("i", "<M-BS>", "<C-o>dB", { noremap = true, silent = true, desc = "enables delete word on insert mode" })
map({ "n", "v" }, "<C-s>", "<cmd>w!<CR>", { desc = "Save buffer (force)" })
map("i", "<C-s>", "<C-o>:w!<CR>", { desc = "Save buffer (force)" })

-- Go-specific LSP code actions
map("n", "<leader>sl", function()
  if vim.bo.filetype ~= "go" then
    print "Split arguments action is only available for Go files"
    return
  end

  vim.lsp.buf.code_action {
    filter = function(action)
      return action.title and action.title:match "Split.*arguments.*separate.*lines"
    end,
    apply = true,
  }
end, { desc = "Split arguments into separate lines [Go]" })

map("n", "<leader>jl", function()
  if vim.bo.filetype ~= "go" then
    print "Join arguments action is only available for Go files"
    return
  end

  vim.lsp.buf.code_action {
    filter = function(action)
      return action.title and action.title:match "Join.*arguments.*one.*line"
    end,
    apply = true,
  }
end, { desc = "Join arguments into one line [Go]" })

map("n", "<leader>ga", function()
  local current_line = vim.api.nvim_win_get_cursor(0)[1]
  local total_lines = vim.api.nvim_buf_line_count(0)

  -- Calculate range: current line ±10 lines
  local start_line = math.max(1, current_line - 10)
  local end_line = math.min(total_lines, current_line + 10)

  -- Set visual selection marks
  vim.api.nvim_buf_set_mark(0, "<", start_line, 0, {})
  vim.api.nvim_buf_set_mark(0, ">", end_line, 0, {})

  -- Execute the command as if it was called from visual mode
  vim.cmd "'<,'>AdvancedGitSearch diff_commit_line"
end, { desc = "Git diff commit for current line (±10 lines)" })

map("n", "<leader>cc", ":CodeCompanionChat Toggle<CR>", { desc = "Toggle CodeCompanion Chat" })

map({ "n", "i", "v" }, "<M-n>", function()
  -- Create a new scratch buffer each time (not toggle)
  Snacks.scratch.open {
    win = {
      -- This ensures we get a fresh buffer
      buf = -1,
    },
  }
  -- Enter insert mode after the buffer is created
  vim.schedule(function()
    vim.cmd "startinsert"
  end)
end, { desc = "Open new scratch buffer" })
