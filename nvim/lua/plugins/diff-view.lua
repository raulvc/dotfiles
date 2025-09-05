local function get_default_branch()
  local result = vim.fn.system "git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null"

  if vim.v.shell_error ~= 0 then
    return "main" -- fallback to main if command fails
  end

  result = result:gsub("^refs/remotes/origin/", ""):gsub("%s+$", "")

  if result ~= "master" and result ~= "main" then
    vim.notify("Default branch detected as: " .. result, vim.log.levels.WARN)
  end

  if result == "" then
    return "main" -- fallback to main if empty result
  end

  return result
end

return {
  {
    -- NOTE: jump between diffs with ]c and [c (vim built in), see :h jumpto-diffs
    "sindrets/diffview.nvim",
    lazy = false,
    dependencies = {
      { "nvim-lua/plenary.nvim" },
      -- icons supported via mini-icons.lua
    },

    opts = {

      -- file_panel = {
      --   win_config = {
      --     position = "bottom",
      --   },
      -- },

      default = {
        disable_diagnostics = false,
      },
      view = {
        merge_tool = {
          disable_diagnostics = false,
          winbar_info = true,
        },
      },
      enhanced_diff_hl = true, -- See ':h diffview-config-enhanced_diff_hl'
      hooks = {
        -- do not fold
        diff_buf_win_enter = function(bufnr)
          vim.opt_local.foldenable = false
        end,

        -- TODO: jump to first diff: https://github.com/sindrets/diffview.nvim/issues/440
        -- TODO: enable diagnostics in diffview
      },
    },

    config = function(_, opts)
      local actions = require "diffview.actions"

      require("diffview").setup(opts)
    end,

    keys = {
      -- use [c and [c to navigate diffs (vim built in), see :h jumpto-diffs
      -- use ]x and [x to navigate conflicts
      {
        "<leader>gdc",
        function()
          local default_branch = require("fredrik.utils.git").get_default_branch()
          vim.cmd(":DiffviewOpen origin/" .. default_branch .. "...HEAD")
        end,
        desc = "Compare commits",
      },
      {
        "<leader>gdq",
        function()
          pcall(function()
            vim.cmd "DiffviewClose"
          end)
        end,
        desc = "Close Diffview tab",
      },

      { "<leader>gdh", ":DiffviewFileHistory %<CR>", desc = "File history" },
      { "<leader>gdH", ":DiffviewFileHistory<CR>", desc = "Repo history" },
      { "<leader>gdm", ":DiffviewOpen<CR>", desc = "Solve merge conflicts" },
      { "<leader>gdo", ":DiffviewOpen main", desc = "DiffviewOpen" },
      { "<leader>gdt", ":DiffviewOpen<CR>", desc = "DiffviewOpen this" },
      {
        "<leader>gdp",
        function()
          local default_branch = get_default_branch()
          vim.cmd(":DiffviewOpen origin/" .. default_branch .. "...HEAD --imply-local")
        end,
        desc = "Review current PR",
      },
      {
        "<leader>gdP",
        function()
          local default_branch = get_default_branch()
          return vim.cmd(
            ":DiffviewFileHistory --range=origin/" .. default_branch .. "...HEAD --right-only --no-merges --reverse"
          )
        end,
        desc = "Review current PR (per commit)",
      },
    },
  },
}
