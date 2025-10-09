return {
  {
    "nvim-treesitter/nvim-treesitter",
    branch = "main",
    event = { "BufReadPost", "BufNewFile" },
    cmd = { "TSInstall", "TSBufEnable", "TSBufDisable", "TSModuleInfo" },
    build = ":TSUpdate",
    lazy = false,
    opts = {
      auto_install = true,
      sync_install = false,
      highlight = { enable = true },
      indent = { enable = false },
      textobjects = {
        select = {
          enable = true,
          lookahead = true, -- Automatically jump forward to textobj
          keymaps = {
            -- You can use the capture groups defined in textobjects.scm
            ["af"] = "@function.outer",
            ["if"] = "@function.inner",
            ["ac"] = "@class.outer",
            ["ic"] = "@class.inner",
            ["aa"] = "@parameter.outer",
            ["ia"] = "@parameter.inner",
            ["ab"] = "@block.outer",
            ["ib"] = "@block.inner",
            ["al"] = "@loop.outer",
            ["il"] = "@loop.inner",
            ["ai"] = "@conditional.outer",
            ["ii"] = "@conditional.inner",
            ["as"] = "@statement.outer",
            ["is"] = "@statement.inner",
            ["am"] = "@call.outer",
            ["im"] = "@call.inner",
            ["ad"] = "@comment.outer",
          },
          -- You can choose the selection style among 'same', 'next', 'previous'
          selection_modes = {
            ["@parameter.outer"] = "v", -- charwise
            ["@function.outer"] = "V", -- linewise
            ["@class.outer"] = "<c-v>", -- blockwise
          },
          include_surrounding_whitespace = false,
        },
        -- Movement between text objects
        move = {
          enable = true,
          set_jumps = true, -- whether to set jumps in the jumplist
          goto_next_start = {
            ["]f"] = "@function.outer",
            ["]c"] = "@class.outer",
            ["]a"] = "@parameter.inner",
            ["]b"] = "@block.outer",
            ["]l"] = "@loop.outer",
            ["]i"] = "@conditional.outer",
            ["]s"] = "@statement.outer",
            ["]m"] = "@call.outer",
          },
          goto_next_end = {
            ["]F"] = "@function.outer",
            ["]C"] = "@class.outer",
            ["]A"] = "@parameter.inner",
            ["]B"] = "@block.outer",
            ["]L"] = "@loop.outer",
            ["]I"] = "@conditional.outer",
            ["]S"] = "@statement.outer",
            ["]M"] = "@call.outer",
          },
          goto_previous_start = {
            ["[f"] = "@function.outer",
            ["[c"] = "@class.outer",
            ["[a"] = "@parameter.inner",
            ["[b"] = "@block.outer",
            ["[l"] = "@loop.outer",
            ["[i"] = "@conditional.outer",
            ["[s"] = "@statement.outer",
            ["[m"] = "@call.outer",
          },
          goto_previous_end = {
            ["[F"] = "@function.outer",
            ["[C"] = "@class.outer",
            ["[A"] = "@parameter.inner",
            ["[B"] = "@block.outer",
            ["[L"] = "@loop.outer",
            ["[I"] = "@conditional.outer",
            ["[S"] = "@statement.outer",
            ["[M"] = "@call.outer",
          },
        },
        -- Text object swapping
        swap = {
          enable = true,
          swap_next = {
            ["<leader>sna"] = "@parameter.inner",
            ["<leader>snf"] = "@function.outer",
            ["<leader>snc"] = "@class.outer",
          },
          swap_previous = {
            ["<leader>spa"] = "@parameter.inner",
            ["<leader>spf"] = "@function.outer",
            ["<leader>spc"] = "@class.outer",
          },
        },
        -- LSP interop
        lsp_interop = {
          enable = true,
          border = "none",
          floating_preview_opts = {},
          peek_definition_code = {
            ["<leader>df"] = "@function.outer",
            ["<leader>dF"] = "@class.outer",
          },
        },
      },
      incremental_selection = {
        enable = true,
        keymaps = {
          init_selection = "<Enter>", -- set to `false` to disable one of the mappings
          node_incremental = "<Enter>",
          scope_incremental = false,
          node_decremental = "<Backspace>",
        },
        is_supported = function()
          local mode = vim.api.nvim_get_mode().mode
          return mode == "n"
        end,
      },
    },
    config = function(_, opts)
      require("nvim-treesitter.config").setup(opts)
    end,
    init = function()
      local parser_installed = {
        "c",
        "lua",
        "vim",
        "vimdoc",
        "query",
        "javascript",
        "typescript",
        "go",
        "rust",
        "html",
        "markdown",
        "make",
        "markdown_inline",
        "sql",
        "yaml",
        "json",
      }

      vim.defer_fn(function()
        require("nvim-treesitter").install(parser_installed)
      end, 1000)
      require("nvim-treesitter").update()

      -- auto-start highlights & indentation
      vim.api.nvim_create_autocmd("FileType", {
        desc = "User: enable treesitter highlighting",
        callback = function(ctx)
          -- highlights
          local hasStarted = pcall(vim.treesitter.start) -- errors for filetypes with no parser

          -- indent
          local noIndent = { "json", "yaml", "yml" } -- Add filetypes that should use default indentation

          if hasStarted and not vim.list_contains(noIndent, ctx.match) then
            vim.bo.indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
          end
        end,
      })
    end,
  },
  {
    "nvim-treesitter/nvim-treesitter-context",
    lazy = false,
    dependencies = {
      "nvim-treesitter/nvim-treesitter",
    },
  },
  {
    "nvim-treesitter/nvim-treesitter-textobjects",
    lazy = false,
    branch = "main",
    dependencies = {
      "nvim-treesitter/nvim-treesitter",
    },
  },
}
