return {
  "kevinhwang91/nvim-hlslens",
  event = "VeryLazy",
  keys = {
    {
      "n",
      "<Cmd>execute('normal! ' . v:count1 . 'n')<CR><Cmd>lua require('hlslens').start()<CR>",
      desc = "Search next with lens",
    },
    {
      "N",
      "<Cmd>execute('normal! ' . v:count1 . 'N')<CR><Cmd>lua require('hlslens').start()<CR>",
      desc = "Search previous with lens",
    },
    { "*", "*<Cmd>lua require('hlslens').start()<CR>", desc = "Search word under cursor with lens" },
    { "#", "#<Cmd>lua require('hlslens').start()<CR>", desc = "Search word under cursor backwards with lens" },
    { "g*", "g*<Cmd>lua require('hlslens').start()<CR>", desc = "Search partial word with lens" },
    { "g#", "g#<Cmd>lua require('hlslens').start()<CR>", desc = "Search partial word backwards with lens" },
  },
  opts = {},
}
