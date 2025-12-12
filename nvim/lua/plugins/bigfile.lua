return {
  {
    "LunarVim/bigfile.nvim",
    lazy = false,
    event = { "FileReadPre", "BufReadPre", "BufNewFile" },
    opts = {
      filesize = 2, -- size in MiB
      pattern = function(bufnr, filesize_mib)
        -- Exclude CodeCompanion chat buffers
        local filetype = vim.api.nvim_get_option_value("filetype", { buf = bufnr })
        if filetype == "codecompanion" then
          return false
        end

        -- Apply to all other files
        return filesize_mib > 2
      end,

      features = { -- features to disable
        "indent_blankline",
        "illuminate",
        "lsp",
        "treesitter",
        "syntax",
        "matchparen",
        "vimopts",
        "filetype",
      },
    },
    config = function(_, opts)
      require("bigfile").setup(opts)
    end,
  },
}
