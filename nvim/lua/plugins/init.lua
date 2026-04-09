return {
  {
    "stevearc/conform.nvim",
    event = "BufWritePre", -- uncomment for format on save
    cmd = { "ConformInfo" },
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
}
