-- add yours here!

local o = vim.o
local g = vim.g
local opt = vim.opt
local api = vim.api

o.colorcolumn = "120"
o.sessionoptions = "blank,buffers,curdir,folds,help,tabpages,winsize,winpos,terminal,localoptions"

o.laststatus = 3
o.showmode = false
o.splitkeep = "screen"

o.clipboard = "unnamedplus"
o.cursorline = true
o.cursorlineopt = "number"

-- Indenting
o.expandtab = true
o.shiftwidth = 4
o.autoindent = true
o.smartindent = true
o.smarttab = true
o.tabstop = 4
o.softtabstop = 4
o.breakindent = true

opt.fillchars = { eob = " " }
o.ignorecase = true
o.smartcase = true
o.mouse = "a"

-- Numbers
o.number = true
o.numberwidth = 2
o.ruler = false

-- disable nvim intro
opt.shortmess:append "sI"

o.signcolumn = "yes"
o.splitbelow = true
o.splitright = true
o.timeoutlen = 300
o.undofile = true

-- Folding using treesitter
opt.foldmethod = "indent"
opt.foldexpr = "nvim_treesitter#foldexpr()"
vim.wo.foldenable = false

-- interval for writing swap file to disk, also used by gitsigns
o.updatetime = 100

-- go to previous/next line with h,l,left arrow and right arrow
-- when cursor reaches end/beginning of line
opt.whichwrap:append "<>[]hl"

opt.wrap = false -- disables word wrap

-- disable some default providers
g.loaded_node_provider = 0
g.loaded_python3_provider = 0
g.loaded_perl_provider = 0
g.loaded_ruby_provider = 0

-- add binaries installed by mason.nvim to path
local is_windows = vim.fn.has "win32" ~= 0
local sep = is_windows and "\\" or "/"
local delim = is_windows and ";" or ":"
vim.env.PATH = table.concat({ vim.fn.stdpath "data", "mason", "bin" }, sep) .. delim .. vim.env.PATH

o.ttimeoutlen = 10 -- Faster escape sequence recognition

-- Better visual feedback
opt.cursorline = true
opt.cursorcolumn = false -- Disable to reduce visual noise

opt.fixeol = true -- newline on save

vim.diagnostic.config {
  virtual_text = true, -- Display the text beside the line
  signs = true, -- Show signs like '●' or '■' in the sign column
  underline = false,
  update_in_insert = false, -- Update diagnostics only in normal mode
  severity_sort = true, -- Sort diagnostics by severity
}

local autocmd = api.nvim_create_autocmd
local augroup = api.nvim_create_augroup
local fn = vim.fn

o.autoread = true
autocmd({ "FocusGained", "BufEnter" }, {
  command = "if mode() != 'c' | checktime | endif",
  pattern = "*",
})

autocmd("FileType", {
  pattern = { "go", "gomod", "gowork" },
  callback = function()
    vim.opt_local.tabstop = 2
    vim.opt_local.softtabstop = 2
    vim.opt_local.shiftwidth = 2
    vim.opt_local.expandtab = false

    vim.opt_local.colorcolumn = "120"
  end,
})

autocmd({ "CursorMoved", "CursorMovedI", "WinScrolled" }, {
  desc = "Fix scrolloff when you are at the EOF",
  group = augroup("ScrollEOF", { clear = true }),
  callback = function()
    if api.nvim_win_get_config(0).relative ~= "" then
      return -- Ignore floating windows
    end

    local win_height = fn.winheight(0)
    local scrolloff = math.min(o.scrolloff, math.floor(win_height / 2))
    local visual_distance_to_eof = win_height - fn.winline()

    if visual_distance_to_eof < scrolloff then
      local win_view = fn.winsaveview()
      fn.winrestview { topline = win_view.topline + scrolloff - visual_distance_to_eof }
    end
  end,
})

autocmd("TermOpen", {
  desc = "Remove UI clutter in the terminal",
  callback = function()
    local is_terminal = api.nvim_get_option_value("buftype", { buf = 0 }) == "terminal"
    o.number = not is_terminal
    o.relativenumber = not is_terminal
    o.signcolumn = is_terminal and "no" or "yes"
  end,
})

autocmd("BufReadPost", {
  desc = "Auto jump to last position",
  group = augroup("auto-last-position", { clear = true }),
  callback = function(args)
    local position = api.nvim_buf_get_mark(args.buf, [["]])
    local winid = fn.bufwinid(args.buf)
    pcall(api.nvim_win_set_cursor, winid, position)
  end,
})

vim.api.nvim_create_autocmd("BufWritePre", {
  callback = function(args)
    vim.lsp.buf.format()
    vim.lsp.buf.code_action { context = { only = { "source.organizeImports" } }, apply = true }
    vim.lsp.buf.code_action { context = { only = { "source.fixAll" } }, apply = true }
  end,
})
