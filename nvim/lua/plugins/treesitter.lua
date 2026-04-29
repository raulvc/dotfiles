return {
  {
    "romus204/tree-sitter-manager.nvim",
    lazy = false,
    config = function()
      require("tree-sitter-manager").setup({
        auto_install = true,
        highlight = true,
        nohighlight = {},
        ensure_installed = {
          "c",
          "lua",
          "vim",
          "vimdoc",
          "query",
          "javascript",
          "typescript",
          "go",
          "gomod",
          "rust",
          "html",
          "kitty",
          "markdown",
          "make",
          "markdown_inline",
          "sql",
          "yaml",
          "json",
          "proto",
          "bash",
          "dockerfile",
          "hcl",
          "terraform",
          "ruby",
          "xml",
          "groovy",
          "java",
          "python",
          "properties",
          "kotlin",
        },
      })
    end,
    init = function()
      vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
        pattern = "*.tpl",
        callback = function()
          vim.bo.filetype = "terraform"
        end,
      })

      vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
        pattern = "*.rb",
        callback = function()
          vim.bo.filetype = "ruby"
        end,
      })

      vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
        pattern = { ".pgpass", "pgpass" },
        callback = function()
          vim.bo.filetype = "conf"
        end,
      })

      vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
        pattern = "sonar-project.properties",
        callback = function()
          vim.bo.filetype = "properties"
        end,
      })

      vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
        pattern = "*.avsc",
        callback = function()
          vim.bo.filetype = "json"
        end,
      })

      vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
        pattern = "*.cql",
        callback = function()
          vim.bo.filetype = "sql"
        end,
      })

      vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
        pattern = "*.gradle.kts",
        callback = function()
          vim.bo.filetype = "kotlin"
        end,
      })
    end,
  },
  {
    "nvim-treesitter/nvim-treesitter-context",
    lazy = false,
    dependencies = {
      "romus204/tree-sitter-manager.nvim",
    },
  },
  {
    "nvim-treesitter/nvim-treesitter-textobjects",
    lazy = false,
    branch = "main",
    dependencies = {
      "romus204/tree-sitter-manager.nvim",
    },
    config = function()
      require("nvim-treesitter-textobjects").setup({
        select = {
          lookahead = true,
          selection_modes = {
            ["@parameter.outer"] = "v",
            ["@function.outer"] = "V",
            ["@class.outer"] = "<c-v>",
          },
          include_surrounding_whitespace = false,
        },
        move = {
          set_jumps = true,
        },
      })

      -- Selection keymaps
      local select_textobject = function(query)
        return function()
          require("nvim-treesitter-textobjects.select").select_textobject(query, "textobjects")
        end
      end

      vim.keymap.set({ "x", "o" }, "af", select_textobject("@function.outer"))
      vim.keymap.set({ "x", "o" }, "if", select_textobject("@function.inner"))
      vim.keymap.set({ "x", "o" }, "ac", select_textobject("@class.outer"))
      vim.keymap.set({ "x", "o" }, "ic", select_textobject("@class.inner"))
      vim.keymap.set({ "x", "o" }, "aa", select_textobject("@parameter.outer"))
      vim.keymap.set({ "x", "o" }, "ia", select_textobject("@parameter.inner"))
      vim.keymap.set({ "x", "o" }, "ab", select_textobject("@block.outer"))
      vim.keymap.set({ "x", "o" }, "ib", select_textobject("@block.inner"))
      vim.keymap.set({ "x", "o" }, "al", select_textobject("@loop.outer"))
      vim.keymap.set({ "x", "o" }, "il", select_textobject("@loop.inner"))
      vim.keymap.set({ "x", "o" }, "ai", select_textobject("@conditional.outer"))
      vim.keymap.set({ "x", "o" }, "ii", select_textobject("@conditional.inner"))
      vim.keymap.set({ "x", "o" }, "as", select_textobject("@statement.outer"))
      vim.keymap.set({ "x", "o" }, "is", select_textobject("@statement.inner"))
      vim.keymap.set({ "x", "o" }, "am", select_textobject("@call.outer"))
      vim.keymap.set({ "x", "o" }, "im", select_textobject("@call.inner"))
      vim.keymap.set({ "x", "o" }, "ad", select_textobject("@comment.outer"))

      -- Movement keymaps
      local goto_next_start = function(query)
        return function()
          require("nvim-treesitter-textobjects.move").goto_next_start(query, "textobjects")
        end
      end
      local goto_next_end = function(query)
        return function()
          require("nvim-treesitter-textobjects.move").goto_next_end(query, "textobjects")
        end
      end
      local goto_previous_start = function(query)
        return function()
          require("nvim-treesitter-textobjects.move").goto_previous_start(query, "textobjects")
        end
      end
      local goto_previous_end = function(query)
        return function()
          require("nvim-treesitter-textobjects.move").goto_previous_end(query, "textobjects")
        end
      end

      vim.keymap.set({ "n", "x", "o" }, "]f", goto_next_start("@function.outer"))
      vim.keymap.set({ "n", "x", "o" }, "]c", goto_next_start("@class.outer"))
      vim.keymap.set({ "n", "x", "o" }, "]a", goto_next_start("@parameter.inner"))
      vim.keymap.set({ "n", "x", "o" }, "]b", goto_next_start("@block.outer"))
      vim.keymap.set({ "n", "x", "o" }, "]l", goto_next_start("@loop.outer"))
      vim.keymap.set({ "n", "x", "o" }, "]i", goto_next_start("@conditional.outer"))
      vim.keymap.set({ "n", "x", "o" }, "]s", goto_next_start("@statement.outer"))
      vim.keymap.set({ "n", "x", "o" }, "]m", goto_next_start("@call.outer"))

      vim.keymap.set({ "n", "x", "o" }, "]F", goto_next_end("@function.outer"))
      vim.keymap.set({ "n", "x", "o" }, "]C", goto_next_end("@class.outer"))
      vim.keymap.set({ "n", "x", "o" }, "]A", goto_next_end("@parameter.inner"))
      vim.keymap.set({ "n", "x", "o" }, "]B", goto_next_end("@block.outer"))
      vim.keymap.set({ "n", "x", "o" }, "]L", goto_next_end("@loop.outer"))
      vim.keymap.set({ "n", "x", "o" }, "]I", goto_next_end("@conditional.outer"))
      vim.keymap.set({ "n", "x", "o" }, "]S", goto_next_end("@statement.outer"))
      vim.keymap.set({ "n", "x", "o" }, "]M", goto_next_end("@call.outer"))

      vim.keymap.set({ "n", "x", "o" }, "[f", goto_previous_start("@function.outer"))
      vim.keymap.set({ "n", "x", "o" }, "[c", goto_previous_start("@class.outer"))
      vim.keymap.set({ "n", "x", "o" }, "[a", goto_previous_start("@parameter.inner"))
      vim.keymap.set({ "n", "x", "o" }, "[b", goto_previous_start("@block.outer"))
      vim.keymap.set({ "n", "x", "o" }, "[l", goto_previous_start("@loop.outer"))
      vim.keymap.set({ "n", "x", "o" }, "[i", goto_previous_start("@conditional.outer"))
      vim.keymap.set({ "n", "x", "o" }, "[s", goto_previous_start("@statement.outer"))
      vim.keymap.set({ "n", "x", "o" }, "[m", goto_previous_start("@call.outer"))

      vim.keymap.set({ "n", "x", "o" }, "[F", goto_previous_end("@function.outer"))
      vim.keymap.set({ "n", "x", "o" }, "[C", goto_previous_end("@class.outer"))
      vim.keymap.set({ "n", "x", "o" }, "[A", goto_previous_end("@parameter.inner"))
      vim.keymap.set({ "n", "x", "o" }, "[B", goto_previous_end("@block.outer"))
      vim.keymap.set({ "n", "x", "o" }, "[L", goto_previous_end("@loop.outer"))
      vim.keymap.set({ "n", "x", "o" }, "[I", goto_previous_end("@conditional.outer"))
      vim.keymap.set({ "n", "x", "o" }, "[S", goto_previous_end("@statement.outer"))
      vim.keymap.set({ "n", "x", "o" }, "[M", goto_previous_end("@call.outer"))

      -- Swap keymaps
      vim.keymap.set("n", "<leader>sna", function()
        require("nvim-treesitter-textobjects.swap").swap_next("@parameter.inner")
      end)
      vim.keymap.set("n", "<leader>snf", function()
        require("nvim-treesitter-textobjects.swap").swap_next("@function.outer")
      end)
      vim.keymap.set("n", "<leader>snc", function()
        require("nvim-treesitter-textobjects.swap").swap_next("@class.outer")
      end)
      vim.keymap.set("n", "<leader>spa", function()
        require("nvim-treesitter-textobjects.swap").swap_previous("@parameter.inner")
      end)
      vim.keymap.set("n", "<leader>spf", function()
        require("nvim-treesitter-textobjects.swap").swap_previous("@function.outer")
      end)
      vim.keymap.set("n", "<leader>spc", function()
        require("nvim-treesitter-textobjects.swap").swap_previous("@class.outer")
      end)
    end,
  },
}
