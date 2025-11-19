return {
  "mrjones2014/smart-splits.nvim",
  lazy = false,
  config = function()
    require("smart-splits").setup {
      -- Kitty integration
      multiplexer_integration = "kitty",
      -- Don't wrap around when at edge
      at_edge = "stop",
    }
  end,
}
