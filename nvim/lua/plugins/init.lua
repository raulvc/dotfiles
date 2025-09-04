return {
  {
    "stevearc/conform.nvim",
    event = "BufWritePre", -- uncomment for format on save
    opts = require "configs.conform",
  },

  {
    "folke/lazydev.nvim",
    ft = "lua", -- only load on lua files
    opts = {
      library = {
        -- See the configuration section for more details
        -- Load luvit types when the `vim.uv` word is found
        { path = "${3rd}/luv/library", words = { "vim%.uv" } },
        { "nvim-dap-ui" },
      },
    },
    lazy = false,
  },

  {
    "numToStr/Comment.nvim",
    event = { "BufReadPre", "BufNewFile" },
    config = function()
      require("Comment").setup {
        toggler = {
          line = "<M-S-/>", -- Normal mode line comment
        },
        opleader = {
          line = "<M-S-/>", -- Visual mode line comment
        },
      }
    end,
  },

  { "rafamadriz/friendly-snippets" },

  {
    "rebelot/kanagawa.nvim",
    lazy = false,
    branch = "master",
    config = function()
      require("kanagawa").setup {
        transparent = false,
        colors = {
          theme = {
            all = {
              ui = {
                bg_gutter = "none",
              },
            },
          },
        },
        overrides = function(colors)
          local theme = colors.theme
          return {
            ["@markup.link.url.markdown_inline"] = { link = "Special" }, -- (url)
            ["@markup.link.label.markdown_inline"] = { link = "WarningMsg" }, -- [label]
            ["@markup.italic.markdown_inline"] = { link = "Exception" }, -- *italic*
            ["@markup.raw.markdown_inline"] = { link = "String" }, -- `code`
            ["@markup.list.markdown"] = { link = "Function" }, -- + list
            ["@markup.quote.markdown"] = { link = "Error" }, -- > blockcode
            ["@markup.list.checked.markdown"] = { link = "WarningMsg" }, -- - [X] checked list item
          }
        end,
      }
      vim.cmd "colorscheme kanagawa"
    end,
  },

  {
    "kylechui/nvim-surround",
    version = "*",
    event = "VeryLazy",
    config = function()
      require("nvim-surround").setup {
        -- Configuration here, or leave empty to use defaults
      }
    end,
  },
  { "nvim-tree/nvim-web-devicons", opts = {} },
  {
    "windwp/nvim-autopairs",
    event = "InsertEnter",
    config = true,
    -- use opts = {} for passing setup options
    -- this is equivalent to setup({}) function
  },
  {
    "cuducos/yaml.nvim",
    ft = { "yaml" }, -- optional
    dependencies = {
      "nvim-treesitter/nvim-treesitter",
      "folke/snacks.nvim", -- optional
      "nvim-telescope/telescope.nvim", -- optional
      "ibhagwan/fzf-lua", -- optional
    },
    config = function()
      require("yaml_nvim").setup { ft = { "yaml" } }
    end,
  },

  {
    "lukas-reineke/virt-column.nvim",
    opts = {},
    config = function()
      require("virt-column").setup()
    end,
    lazy = false,
  },
  {
    "lewis6991/gitsigns.nvim",
    event = "User FilePost",
    lazy = false,
    opts = function()
      return {
        signs = {
          delete = { text = "󰍵" },
          changedelete = { text = "󱕖" },
        },
      }
    end,
  },

  {
    "akinsho/bufferline.nvim",
    version = "*",
    lazy = false,
    dependencies = "nvim-tree/nvim-web-devicons",
    opts = {
      options = {
        mode = "buffers",
        separator_style = "slant",
        diagnostics = "nvim_lsp",
        middle_mouse_command = "bdelete! %d",
        indicator = {
          style = "icon",
        },
        offsets = {
          {
            filetype = "NvimTree",
            text = function()
              return vim.fn.getcwd()
            end,
            highlight = "Directory",
            text_align = "left",
            separator = true,
          },
        },
      },
    },
  },
  {
    "nvim-lualine/lualine.nvim",
    lazy = false,
    dependencies = { "nvim-tree/nvim-web-devicons" },
    config = function()
      require("lualine").setup {
        options = {
          theme = "auto",
        },
      }
    end,
  },
  {
    {
      "folke/which-key.nvim",
      event = "VeryLazy",
      opts = {
        -- your configuration comes here
        -- or leave it empty to use the default settings
        -- refer to the configuration section below
      },
      keys = {
        {
          "<leader>?",
          function()
            require("which-key").show { global = false }
          end,
          desc = "Buffer Local Keymaps (which-key)",
        },
      },
    },
  },
  {
    "lewis6991/satellite.nvim",
    lazy = false,
  },
  -- {
  --   "stevearc/overseer.nvim",
  --   opts = {},
  -- },
}
