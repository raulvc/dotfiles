return {
  "MeanderingProgrammer/render-markdown.nvim",
  dependencies = { "romus204/tree-sitter-manager.nvim", "nvim-tree/nvim-web-devicons" }, -- if you prefer nvim-web-devicons
  ---@module 'render-markdown'
  ---@type render.md.UserConfig
  opts = {
    completions = { blink = { enabled = true }, lsp = { enabled = true } },
  },
  ft = { "markdown" },
}
