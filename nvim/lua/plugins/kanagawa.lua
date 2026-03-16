return {
  {
    "rebelot/kanagawa.nvim",
    lazy = false,
    priority = 1000, -- Load before other plugins
    branch = "master",
    config = function()
      require("kanagawa").setup {
        compile = false, -- Enable compiling the colorscheme
        undercurl = true, -- Enable undercurls
        commentStyle = { italic = true },
        functionStyle = {},
        keywordStyle = { italic = true },
        statementStyle = { bold = true },
        typeStyle = {},
        transparent = false, -- Do not set background color
        dimInactive = false, -- Dim inactive window `:h hl-NormalNC`
        terminalColors = true, -- Define vim.g.terminal_color_{0,17}

        colors = {
          palette = {
            -- Custom palette colors (optional)
          },
          theme = {
            all = {
              ui = {
                bg_gutter = "none", -- Remove gutter background
              },
            },
            wave = {
              ui = {
                float = {
                  bg = "none", -- Transparent floating windows
                },
              },
            },
            dragon = {
              syn = {
                parameter = "yellow",
              },
            },
            lotus = {},
          },
        },

        overrides = function(colors)
          local theme = colors.theme
          local palette = colors.palette

          return {
            -- Transparent floating windows
            NormalFloat = { bg = "none" },
            FloatBorder = { bg = "none" },
            FloatTitle = { bg = "none" },

            -- Save an hlgroup with dark background and dimmed foreground
            -- so that you can use it where your still want darker windows.
            -- E.g.: autocmd TermOpen * setlocal winhighlight=Normal:NormalDark
            NormalDark = { fg = theme.ui.fg_dim, bg = theme.ui.bg_m3 },

            -- Popular plugin support
            LazyNormal = { bg = theme.ui.bg_m3, fg = theme.ui.fg_dim },
            MasonNormal = { bg = theme.ui.bg_m3, fg = theme.ui.fg_dim },

            -- Telescope
            TelescopeTitle = { fg = theme.ui.special, bold = true },
            TelescopePromptNormal = { bg = theme.ui.bg_dim },
            TelescopePromptBorder = { fg = theme.ui.bg_dim, bg = theme.ui.bg_dim },
            TelescopeResultsNormal = { fg = theme.ui.fg_dim, bg = theme.ui.bg_dim },
            TelescopeResultsBorder = { fg = theme.ui.bg_dim, bg = theme.ui.bg_dim },
            TelescopePreviewNormal = { bg = theme.ui.bg_dim },
            TelescopePreviewBorder = { bg = theme.ui.bg_dim, fg = theme.ui.bg_dim },

            -- Completion menu (nvim-cmp)
            Pmenu = { fg = theme.ui.shade0, bg = theme.ui.bg_p1 },
            PmenuSel = { fg = "NONE", bg = theme.ui.bg_p2 },
            PmenuSbar = { bg = theme.ui.bg_m1 },
            PmenuThumb = { bg = theme.ui.bg_p2 },

            -- Better diff colors (fg = NONE to keep text readable)
            DiffAdd = { bg = palette.winterGreen, fg = "NONE" },
            DiffChange = { bg = palette.winterYellow, fg = "NONE" },
            DiffDelete = { bg = palette.winterRed, fg = "NONE" },
            DiffText = { bg = palette.winterBlue, fg = "NONE", bold = true },

            -- Gitsigns
            GitSignsAdd = { fg = palette.autumnGreen },
            GitSignsChange = { fg = palette.autumnYellow },
            GitSignsDelete = { fg = palette.autumnRed },

            -- Indent-blankline
            IblIndent = { fg = theme.ui.bg_p2 },
            IblScope = { fg = theme.ui.whitespace },

            -- Markdown enhancements
            ["@markup.heading.1.markdown"] = { fg = palette.dragonRed, bold = true },
            ["@markup.heading.2.markdown"] = { fg = palette.dragonOrange, bold = true },
            ["@markup.heading.3.markdown"] = { fg = palette.dragonYellow, bold = true },
            ["@markup.heading.4.markdown"] = { fg = palette.dragonGreen, bold = true },
            ["@markup.heading.5.markdown"] = { fg = palette.dragonBlue, bold = true },
            ["@markup.heading.6.markdown"] = { fg = palette.dragonViolet, bold = true },
            ["@markup.link.url.markdown_inline"] = { fg = palette.springBlue, underline = true },
            ["@markup.link.label.markdown_inline"] = { fg = palette.oniViolet, bold = true },
            ["@markup.italic.markdown_inline"] = { fg = palette.springViolet1, italic = true },
            ["@markup.strong.markdown_inline"] = { fg = palette.dragonRed, bold = true },
            ["@markup.raw.markdown_inline"] = { fg = palette.springGreen },
            ["@markup.list.markdown"] = { fg = palette.oniViolet },
            ["@markup.quote.markdown"] = { fg = theme.ui.special, italic = true },
            ["@markup.list.checked.markdown"] = { fg = palette.autumnGreen },
            ["@markup.list.unchecked.markdown"] = { fg = theme.ui.fg_dim },

            -- Diagnostics
            DiagnosticVirtualTextError = { bg = "none", fg = palette.samuraiRed },
            DiagnosticVirtualTextWarn = { bg = "none", fg = palette.roninYellow },
            DiagnosticVirtualTextInfo = { bg = "none", fg = palette.dragonBlue },
            DiagnosticVirtualTextHint = { bg = "none", fg = palette.springViolet1 },

            -- Multiselect highlights
            TelescopeMultiSelected = { bg = "#2a2a3f", fg = palette.springBlue },
            TelescopeMultiSelectedIcon = { fg = palette.springBlue, bold = true },

            -- Treesitter context
            TreesitterContext = { bg = theme.ui.bg_p2 },
            TreesitterContextLineNumber = { fg = theme.ui.special, bg = theme.ui.bg_p2 },

            -- Which-key
            WhichKey = { fg = palette.crystalBlue },
            WhichKeyGroup = { fg = palette.springViolet2 },
            WhichKeyDesc = { fg = theme.ui.fg },
            WhichKeySeparator = { fg = theme.ui.nontext },
            WhichKeyFloat = { bg = theme.ui.bg_m1 },

            -- Noice
            NoicePopupmenu = { bg = theme.ui.bg_m1 },
            NoicePopupmenuBorder = { fg = theme.ui.bg_m1, bg = theme.ui.bg_m1 },
            NoiceCmdlinePopup = { bg = theme.ui.bg_m1 },
            NoiceCmdlinePopupBorder = { fg = theme.ui.bg_m1, bg = theme.ui.bg_m1 },

            -- Bufferline integration
            BufferLineIndicatorSelected = { fg = palette.crystalBlue },
            BufferLineFill = { bg = theme.ui.bg_m3 },

            -- Lualine integration (if needed)
            StatusLine = { bg = theme.ui.bg_m3 },
            StatusLineNC = { bg = theme.ui.bg_m3, fg = theme.ui.nontext },
          }
        end,

        theme = "wave", -- Load "wave" theme when 'background' option is not set
        background = {
          dark = "wave", -- "wave" | "dragon"
          light = "lotus",
        },
      }

      -- Set colorscheme
      vim.cmd "colorscheme kanagawa"
    end,
  },
}
