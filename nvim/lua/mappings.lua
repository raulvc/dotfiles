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

map("v", "<leader>gd", function()
  -- Temporarily redirect error output to /dev/null
  vim.cmd "redir! > /dev/null"
  pcall(function()
    vim.cmd "'<,'>AdvancedGitSearch diff_commit_line"
  end)
  vim.cmd "redir END"
end, { desc = "Git diff commit for selection" })

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
      return action.title and action.title:match "Split.*separate.*lines"
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
      return action.title and action.title:match "Join.*one.*line"
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

  -- Temporarily redirect error output to /dev/null
  vim.cmd "redir! > /dev/null"
  pcall(function()
    vim.cmd "'<,'>AdvancedGitSearch diff_commit_line"
  end)
  vim.cmd "redir END"
end, { desc = "Git diff commit for current line (±10 lines)" })

map("n", "<leader>cc", ":CodeCompanionChat Toggle<CR>", { desc = "Toggle CodeCompanion Chat" })
map("n", "<leader>ch", ":CodeCompanionHistory<CR>", { desc = "Opens CodeCompanionHistory" })

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

-- === TEXT WRAPPING MAPPINGS ===
-- Function to wrap selection with specified characters
local function wrap_selection(left, right)
  right = right or left -- If no right char provided, use left for both sides

  -- Get visual selection start and end positions
  local start_pos, end_pos

  -- Check if we're in visual mode
  local mode = vim.fn.mode()
  if mode == "v" or mode == "V" or mode == "\22" then -- \22 is visual block mode
    -- We're in active visual mode, get current selection
    start_pos = vim.fn.getpos "." -- Current cursor position
    -- We need to use a different approach for active visual mode
    vim.cmd "normal! \27" -- Escape to exit visual mode, which sets the marks
    start_pos = vim.fn.getpos "'<"
    end_pos = vim.fn.getpos "'>"
    -- Re-enter visual mode to restore selection
    vim.cmd "normal! gv"
  else
    -- Not in visual mode, use existing marks
    start_pos = vim.fn.getpos "'<"
    end_pos = vim.fn.getpos "'>"
  end

  -- Extract line and column (1-indexed from getpos, need 0-indexed for API)
  local start_row = start_pos[2] - 1
  local start_col = start_pos[3] - 1
  local end_row = end_pos[2] - 1
  local end_col = end_pos[3]

  -- Ensure coordinates are in correct order
  if start_row > end_row or (start_row == end_row and start_col > end_col) then
    start_row, end_row = end_row, start_row
    start_col, end_col = end_col, start_col
  end

  -- Get line lengths to validate column positions (with nil check)
  local start_line = vim.api.nvim_buf_get_lines(0, start_row, start_row + 1, false)[1]
  local end_line = vim.api.nvim_buf_get_lines(0, end_row, end_row + 1, false)[1]

  if not start_line or not end_line then
    return -- Invalid line numbers
  end

  local start_line_len = #start_line
  local end_line_len = #end_line

  -- Clamp column positions to valid ranges
  start_col = math.max(0, math.min(start_col, start_line_len))
  end_col = math.max(0, math.min(end_col, end_line_len))

  -- For single line selections, ensure start_col <= end_col
  if start_row == end_row and start_col > end_col then
    start_col, end_col = end_col, start_col
  end

  -- Get the selected text
  local lines = vim.api.nvim_buf_get_text(0, start_row, start_col, end_row, end_col, {})

  if #lines == 0 then
    return
  end

  -- Exit visual mode first
  if vim.fn.mode():match "[vV\22]" then
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "n", false)
  end

  -- Wrap the text
  if #lines == 1 then
    -- Single line selection
    local wrapped = left .. lines[1] .. right
    vim.api.nvim_buf_set_text(0, start_row, start_col, end_row, end_col, { wrapped })
  else
    -- Multi-line selection
    lines[1] = left .. lines[1]
    lines[#lines] = lines[#lines] .. right
    vim.api.nvim_buf_set_text(0, start_row, start_col, end_row, end_col, lines)
  end
end

-- Function to wrap current word (for normal mode)
local function wrap_current_word(left, right)
  right = right or left

  -- Get current cursor position
  local cursor_pos = vim.api.nvim_win_get_cursor(0)
  local row = cursor_pos[1] - 1
  local col = cursor_pos[2]

  -- Get current line
  local line = vim.api.nvim_buf_get_lines(0, row, row + 1, false)[1]
  if not line then
    return
  end

  -- Find word boundaries
  local word_start = col
  local word_end = col

  -- Find start of word (move backwards)
  while word_start > 0 and line:sub(word_start, word_start):match "[%w_]" do
    word_start = word_start - 1
  end
  if not line:sub(word_start + 1, word_start + 1):match "[%w_]" then
    word_start = word_start + 1
  end

  -- Find end of word (move forwards)
  while word_end < #line and line:sub(word_end + 1, word_end + 1):match "[%w_]" do
    word_end = word_end + 1
  end

  -- If no word found, return
  if word_start >= word_end then
    return
  end

  -- Get the word
  local word = line:sub(word_start + 1, word_end)
  local wrapped = left .. word .. right

  -- Replace the word
  vim.api.nvim_buf_set_text(0, row, word_start, row, word_end, { wrapped })
end

-- Wrap with quotes and brackets (Visual mode)
map("v", "<leader>a'", function()
  wrap_selection "'"
end, { desc = "Wrap selection with single quotes" })
map("v", '<leader>a"', function()
  wrap_selection '"'
end, { desc = "Wrap selection with double quotes" })
map("v", "<leader>a`", function()
  wrap_selection "`"
end, { desc = "Wrap selection with backticks" })
map("v", "<leader>a(", function()
  wrap_selection("(", ")")
end, { desc = "Wrap selection with parentheses" })
map("v", "<leader>a[", function()
  wrap_selection("[", "]")
end, { desc = "Wrap selection with square brackets" })
map("v", "<leader>a{", function()
  wrap_selection("{", "}")
end, { desc = "Wrap selection with curly braces" })
map("v", "<leader>a<", function()
  wrap_selection("<", ">")
end, { desc = "Wrap selection with angle brackets" })

-- Normal mode variants that work on current word
map("n", "<leader>a'", function()
  wrap_current_word "'"
end, { desc = "Wrap current word with single quotes" })

map("n", '<leader>a"', function()
  wrap_current_word '"'
end, { desc = "Wrap current word with double quotes" })

map("n", "<leader>a`", function()
  wrap_current_word "`"
end, { desc = "Wrap current word with backticks" })

map("n", "<leader>a(", function()
  wrap_current_word("(", ")")
end, { desc = "Wrap current word with parentheses" })

map("n", "<leader>a[", function()
  wrap_current_word("[", "]")
end, { desc = "Wrap current word with square brackets" })

map("n", "<leader>a{", function()
  wrap_current_word("{", "}")
end, { desc = "Wrap current word with curly braces" })

map("n", "<leader>a<", function()
  wrap_current_word("<", ">")
end, { desc = "Wrap current word with angle brackets" })
