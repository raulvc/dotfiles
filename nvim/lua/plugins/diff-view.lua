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
      enhanced_diff_hl = true, -- Enable for better word-level diff highlighting
      view = {
        default = {
          layout = "diff2_horizontal",
        },
        merge_tool = {
          layout = "diff3_horizontal",
          disable_diagnostics = true,
          winbar_info = true,
        },
        file_history = {
          layout = "diff2_horizontal",
        },
      },
      file_panel = {
        listing_style = "tree",
        tree_options = {
          flatten_dirs = true,
          folder_statuses = "only_folded",
        },
        win_config = {
          position = "left",
          width = 35,
        },
      },
      hooks = {
        diff_buf_win_enter = function(bufnr)
          vim.opt_local.foldenable = false
        end,
      },
    },

    config = function(_, opts)
      require("diffview").setup(opts)
    end,

    keys = {
      {
        "<leader>gdq",
        function()
          pcall(function()
            vim.cmd "DiffviewClose"
          end)
        end,
        desc = "Close Diffview tab",
      },

      {
        "<leader>gdh",
        ":DiffviewFileHistory %<CR>",
        mode = "n",
        desc = "File history",
      },
      {
        "<leader>gdh",
        ":DiffviewFileHistory<CR>",
        mode = "v",
        desc = "History for selected lines",
      },

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
