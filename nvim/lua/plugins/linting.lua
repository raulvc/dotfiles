return {
  {
    "mfussenegger/nvim-lint",
    dependencies = {
      "williamboman/mason.nvim", -- Ensure mason is installed for managing linters
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
        -- Add more as needed
      }

      require("mason-nvim-lint").setup {
        ensure_installed = { "flake8", "luacheck", "eslint_d", "golangcilint" },
        automatic_installation = true,
      }

      -- Create autocommand group for linting
      local lint_augroup = vim.api.nvim_create_augroup("lint", { clear = true })

      -- In your nvim-lint config, replace the autocmd with:
      vim.api.nvim_create_autocmd("BufWritePost", {
        group = lint_augroup,
        callback = function()
          -- Format first, then lint
          vim.defer_fn(function()
            lint.try_lint()
          end, 100) -- Small delay to let conform finish
        end,
      })
      -- Manual lint trigger
      vim.keymap.set("n", "<leader>ll", function()
        lint.try_lint()
      end, { desc = "Trigger linting for current file" })
    end,
  },
}
