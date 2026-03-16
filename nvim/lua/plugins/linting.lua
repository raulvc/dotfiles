return {
  {
    "mfussenegger/nvim-lint",
    dependencies = {
      "williamboman/mason.nvim",
      "rshkarin/mason-nvim-lint",
    },
    event = { "BufReadPre", "BufNewFile" },
    config = function()
      local lint = require "lint"

      -- Configure linters by filetype
      lint.linters_by_ft = {
        javascript = { "eslint_d" },
        typescript = { "eslint_d" },
        python = { "flake8" },
        lua = { "luacheck" },
        go = { "golangcilint" },
        bash = { "shellcheck" },
        sh = { "shellcheck" },
      }

      require("mason-nvim-lint").setup {
        ensure_installed = { "flake8", "luacheck", "eslint_d", "golangcilint" },
        automatic_installation = true,
      }

      local lint_augroup = vim.api.nvim_create_augroup("lint", { clear = true })

      -- Lint on read and insert leave for fast feedback
      vim.api.nvim_create_autocmd({ "BufReadPost", "InsertLeave" }, {
        group = lint_augroup,
        callback = function()
          lint.try_lint()
        end,
      })

      -- Lint after save — conform runs on BufWritePre so formatting
      -- is already done by the time BufWritePost fires. No delay needed.
      vim.api.nvim_create_autocmd("BufWritePost", {
        group = lint_augroup,
        callback = function()
          lint.try_lint()
        end,
      })

      -- Manual lint trigger
      vim.keymap.set("n", "<leader>ll", function()
        lint.try_lint()
      end, { desc = "Trigger linting for current file" })
    end,
  },
}
