return {
  {
    "LunarVim/bigfile.nvim",
    lazy = false,
    event = { "FileReadPre", "BufReadPre", "BufNewFile" },
    opts = {
      filesize = 2, -- size in MiB
      pattern = { "*" }, -- autocmd pattern or function see <### Overriding the detection of big files>
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
