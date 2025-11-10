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
      enhanced_diff_hl = false, -- Disable to avoid color conflicts
      default = {
        disable_diagnostics = true, -- Disable diagnostics in diff view
      },
      view = {
        merge_tool = {
          disable_diagnostics = true,
          winbar_info = true,
        },
      },
      hooks = {
        -- do not fold
        diff_buf_win_enter = function(bufnr)
          vim.opt_local.foldenable = false
        end,
      },
    },

    config = function(_, opts)
      local actions = require "diffview.actions"

      require("diffview").setup(opts)

      -- Set Kanagawa-compatible diff colors
      local function set_diffview_highlights()
        local colors = {
          bg = "#1f1f28",
          fg = "#dcd7ba",
          red = "#e82424",
          green = "#98bb6c",
          blue = "#7e9cd8",
          yellow = "#e6c384",
          gray = "#54546d",
        }

        local highlights = {
          -- Diff colors
          DiffAdd = { bg = "#2a3f2a", fg = colors.green },
          DiffDelete = { bg = "#3f2a2a", fg = colors.red },
          DiffChange = { bg = "#2a2f3f", fg = colors.blue },
          DiffText = { bg = "#3a3f5f", fg = colors.yellow, bold = true },

          -- Diffview specific
          DiffviewNormal = { bg = colors.bg, fg = colors.fg },
          DiffviewCursorLine = { bg = colors.gray },
          DiffviewFilePanelTitle = { bg = colors.blue, fg = colors.bg, bold = true },
          DiffviewFilePanelCounter = { fg = colors.blue, bold = true },
          DiffviewFilePanelFileName = { fg = colors.fg },
          DiffviewFolderSign = { fg = colors.gray },
          DiffviewStatusAdded = { fg = colors.green },
          DiffviewStatusDeleted = { fg = colors.red },
          DiffviewStatusModified = { fg = colors.blue },
          DiffviewStatusRenamed = { fg = colors.yellow },
          DiffviewStatusUntracked = { fg = colors.gray },
        }

        for group, opts_hl in pairs(highlights) do
          vim.api.nvim_set_hl(0, group, opts_hl)
        end
      end

      -- Set highlights after colorscheme loads
      vim.api.nvim_create_autocmd("ColorScheme", {
        pattern = "*",
        callback = set_diffview_highlights,
      })

      -- Set highlights immediately
      set_diffview_highlights()
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
