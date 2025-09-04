return {
	{
		"nvim-treesitter/nvim-treesitter",
		event = { "BufReadPost", "BufNewFile" },
		cmd = { "TSInstall", "TSBufEnable", "TSBufDisable", "TSModuleInfo" },
		build = ":TSUpdate",
		lazy = false,
		opts = {
			ensure_installed = {
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
			},

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
			},
		},
		config = function(_, opts)
			require("nvim-treesitter.configs").setup(opts)
		end,
	},
	{
		"nvim-treesitter/nvim-treesitter-context",
		lazy = false,
	},
}
