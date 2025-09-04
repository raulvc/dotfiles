vim.deprecate = function() end

-- bootstrap lazy and all plugins
local lazypath = vim.fn.stdpath "data" .. "/lazy/lazy.nvim"

if not vim.loop.fs_stat(lazypath) then
  local repo = "https://github.com/folke/lazy.nvim.git"
  vim.fn.system { "git", "clone", "--filter=blob:none", repo, "--branch=stable", lazypath }
end

vim.opt.rtp:prepend(lazypath)

vim.g.mapleader = " "
vim.g.maplocalleader = "\\"

local lazy_config = require "configs.lazy"

-- load plugins
require("lazy").setup({
  { import = "plugins" },
}, lazy_config)

vim.schedule(function()
  require "options"
end)

vim.schedule(function()
  require "mappings"
end)

-- Make word navigation stop at special characters like Sublime Text
vim.keymap.set({ "n", "v" }, "<C-Left>", "b", { desc = "Move word backward" })
vim.keymap.set({ "n", "v" }, "<C-Right>", "w", { desc = "Move word forward" })
vim.opt.iskeyword = "@,48-57,_,192-255"

-- require("overseer").setup {
--   strategy = "toggleterm",
-- }
