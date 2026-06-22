return {
  {
    "saghen/blink.pairs",
    dependencies = "saghen/blink.lib",
    lazy = false,
    version = "*",
    build = function()
      require("blink.pairs").build():pwait(60000)
    end,
    opts = {
      highlights = {
        matchparen = {
          include_surrounding = true,
        },
      },
    },
  },
}
