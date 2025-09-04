return {
    {
        "mason-org/mason.nvim",
        cmd = { "Mason", "MasonInstall", "MasonUpdate" },
        opts = function()
            return {
                PATH = "skip",

                ui = {
                    icons = {
                        package_pending = " ",
                        package_installed = " ",
                        package_uninstalled = " ",
                    },
                },

                max_concurrent_installers = 10,
            }
        end,
        config = function()
            require("mason").setup()
        end,
        lazy = false,
    },
    {
        "williamboman/mason-lspconfig.nvim",
        dependencies = {
            "Saghen/blink.cmp",
        },
        lazy = false,
        opts = {
            auto_install = true,
        },
        config = function()
            require("mason-lspconfig").setup {
                ensure_installed = {
                    "lua_ls",
                    "bashls",
                    "gopls",
                    "pyright",
                    "rust_analyzer",
                    "kotlin_lsp",
                },
            }
        end,
    },
    {
        "neovim/nvim-lspconfig",
        lazy = false,
        config = function()
            local capabilities = require("blink.cmp").get_lsp_capabilities()
            local builtin = require "telescope.builtin"

            -- Configure servers using vim.lsp.config (Neovim 0.11+)
            vim.lsp.config("lua_ls", {
                capabilities = capabilities,
            })

            vim.lsp.config("bashls", {
                capabilities = capabilities,
            })

            vim.lsp.config("gopls", {
                capabilities = capabilities,
                settings = {
                    gopls = {
                        usePlaceholders = true,
                        completeUnimported = true,
                        staticcheck = true,
                        gofumpt = true,
                        analyses = {
                            unusedparams = true,
                            unusedVariable = true,
                            unreachable = false,
                            fillstruct = true,
                            undeclaredname = true,
                        },
                        symbolScope = "workspace",
                        hints = {
                            parameterNames = true,
                            assignVariableTypes = true,
                            constantValues = true,
                            compositeLiteralTypes = true,
                            compositeLiteralFields = true,
                            functionTypeParameters = true,
                        },
                        vulncheck = "imports",
                        analysisProgressReporting = true,
                        -- Enable experimental features for stub generation
                        experimentalPostfixCompletions = true,
                        codelenses = {
                            gc_details = false,
                            generate = true,
                            regenerate_cgo = true,
                            run_govulncheck = true,
                            test = true,
                            tidy = true,
                            upgrade_dependency = true,
                            vendor = true,
                        },
                    },
                },
            })

            vim.lsp.config("pyright", {
                capabilities = capabilities,
            })

            vim.lsp.config("hyprls", {
                capabilities = capabilities,
            })

            vim.lsp.config("rust_analyzer", {
                capabilities = capabilities,
                settings = {
                    ["rust-analyzer"] = {
                        diagnostics = {
                            enable = true,
                            experimental = {
                                enable = true,
                            },
                        },
                        check = {
                            command = "check",
                            extraArgs = { "--all-features" },
                            features = "all",
                        },
                        imports = {
                            granularity = {
                                group = "module",
                            },
                            prefix = "self",
                        },
                        cargo = {
                            allFeatures = true,
                            buildScripts = {
                                enable = true,
                            },
                        },
                        procMacro = {
                            enable = true,
                        },
                    },
                },
            })

            vim.lsp.config("kotlin_lsp", {
                capabilities = capabilities,
            })

            -- Keymappings with improved workspace symbols
            -- vim.keymap.set("n", "<leader>gd", builtin.lsp_definitions, { desc = "[G]oto [D]efinition" })
            -- vim.keymap.set("n", "<leader>gi", builtin.lsp_implementations, { desc = "[G]oto [I]mplementation" })
            -- vim.keymap.set("n", "<leader>gr", builtin.lsp_references, { desc = "[G]oto [R]eferences" })
            vim.keymap.set("n", "<leader>gs", builtin.lsp_dynamic_workspace_symbols, { desc = "[G]oto [S]ymbol" })
            vim.keymap.set("n", "<leader>ds", builtin.lsp_document_symbols, { desc = "[D]ocument [S]ymbols" })
            vim.keymap.set("n", "<leader>rn", vim.lsp.buf.rename, { desc = "[R]e[n]ame" })
            vim.keymap.set({ "n", "v" }, "<leader>ca", vim.lsp.buf.code_action, { desc = "[C]ode [A]ctions" })
            vim.keymap.set("n", "<C-q>", vim.lsp.buf.hover, { desc = "Hover Documentation" })
            vim.keymap.set("n", "<M-r>", builtin.lsp_references, { desc = "[G]oto [R]eferences" })
            vim.keymap.set("n", "<M-g>", builtin.lsp_implementations, { desc = "[G]oto [I]mplementation" })
            vim.keymap.set("n", "<M-d>", builtin.lsp_definitions, { desc = "[G]oto [D]efinition" })
        end,
    },
    {
        "saghen/blink.compat",
        -- use the latest release, via version = '*', if you also use the latest release for blink.cmp
        version = "*",
        -- lazy.nvim will automatically load the plugin when it's required by blink.cmp
        lazy = true,
        -- make sure to set opts so that lazy.nvim calls blink.compat's setup
        opts = {},
    },

    {
        "saghen/blink.cmp",
        -- optional: provides snippets for the snippet source
        dependencies = {
            "saghen/blink.compat",
            "rafamadriz/friendly-snippets",
            "moyiz/blink-emoji.nvim",
            "ray-x/cmp-sql",
            "L3MON4D3/LuaSnip",
            { "samiulsami/cmp-go-deep", dependencies = { "kkharji/sqlite.lua" } },
        },

        -- use a release tag to download pre-built binaries
        version = "*",
        -- AND/OR build from source, requires nightly: https://rust-lang.github.io/rustup/concepts/channels.html#working-with-nightly-rust
        -- build = 'cargo build --release',
        -- If you use nix, you can build from source using latest nightly rust with:
        -- build = 'nix run .#build-plugin',

        ---@module 'blink.cmp'
        ---@type blink.cmp.Config
        opts = {
            -- 'default' (recommended) for mappings similar to built-in completions (C-y to accept)
            -- 'super-tab' for mappings similar to vscode (tab to accept)
            -- 'enter' for enter to accept
            -- 'none' for no mappings
            --
            -- All presets have the following mappings:
            -- C-space: Open menu or open docs if already open
            -- C-n/C-p or Up/Down: Select next/previous item
            -- C-e: Hide menu
            -- C-k: Toggle signature help (if signature.enabled = true)
            --
            -- See :h blink-cmp-config-keymap for defining your own keymap
            keymap = {
                preset = "enter",
                ["<Up>"] = { "select_prev", "fallback" },
                ["<Down>"] = { "select_next", "fallback" },
                ["<CR>"] = { "accept", "fallback" },
                ["<Esc>"] = {
                    "cancel",
                    "fallback",
                },
                ["<C-space>"] = {
                    function(cmp)
                        cmp.show {}
                    end,
                },
                ["<C-q>"] = { "show_documentation" },
            },

            snippets = { preset = "luasnip" },

            appearance = {
                -- 'mono' (default) for 'Nerd Font Mono' or 'normal' for 'Nerd Font'
                -- Adjusts spacing to ensure icons are aligned
                nerd_font_variant = "mono",

                kind_icons = {
                    Text = "󰉿",
                    Method = "󰊕",
                    Function = "󰊕",
                    Constructor = "󰒓",

                    Field = "󰜢",
                    Variable = "󰆦",
                    Property = "󰖷",

                    Class = "󱡠",
                    Interface = "󱡠",
                    Struct = "󱡠",
                    Module = "󰅩",

                    Unit = "󰪚",
                    Value = "󰦨",
                    Enum = "󰦨",
                    EnumMember = "󰦨",

                    Keyword = "󰻾",
                    Constant = "󰏿",

                    Snippet = "󱄽",
                    Color = "󰏘",
                    File = "󰈔",
                    Reference = "󰬲",
                    Folder = "󰉋",
                    Event = "󱐋",
                    Operator = "󰪚",
                    TypeParameter = "󰬛",
                },
            },

            -- (Default) Only show the documentation popup when manually triggered
            completion = {
                documentation = { auto_show = true },
                list = { selection = { auto_insert = false } },
            },

            signature = { enabled = true },

            -- Default list of enabled providers defined so that you can extend it
            -- elsewhere in your config, without redefining it, due to `opts_extend`
            sources = {
                default = { "lazydev", "lsp", "go_deep", "path", "snippets", "buffer", "copilot", "emoji", "sql" },
                providers = {
                    lazydev = {
                        name = "LazyDev",
                        module = "lazydev.integrations.blink",
                        -- make lazydev completions top priority (see `:h blink.cmp`)
                        score_offset = 100,
                    },
                    copilot = {
                        name = "copilot",
                        module = "blink-cmp-copilot",
                        score_offset = -100,
                        async = true,
                    },
                    emoji = {
                        module = "blink-emoji",
                        name = "Emoji",
                        score_offset = 15, -- Tune by preference
                        opts = { insert = true }, -- Insert emoji (default) or complete its name
                        should_show_items = function()
                            return vim.tbl_contains(
                            -- Enable emoji completion only for git commits and markdown.
                            -- By default, enabled for all file-types.
                                { "gitcommit", "markdown" },
                                vim.o.filetype
                            )
                        end,
                    },
                    sql = {
                        -- IMPORTANT: use the same name as you would for nvim-cmp
                        name = "sql",
                        module = "blink.compat.source",

                        -- all blink.cmp source config options work as normal:
                        score_offset = -3,

                        -- this table is passed directly to the proxied completion source
                        -- as the `option` field in nvim-cmp's source config
                        --
                        -- this is NOT the same as the opts in a plugin's lazy.nvim spec
                        opts = {},
                        should_show_items = function()
                            return vim.tbl_contains(
                            -- Enable emoji completion only for git commits and markdown.
                            -- By default, enabled for all file-types.
                                { "sql" },
                                vim.o.filetype
                            )
                        end,
                    },
                    go_deep = {
                        name = "go_deep",
                        module = "blink.compat.source",
                        min_keyword_length = 3,
                        max_items = 5,
                    },
                },
            },

            -- (Default) Rust fuzzy matcher for typo resistance and significantly better performance
            -- You may use a lua implementation instead by using `implementation = "lua"` or fallback to the lua implementation,
            -- when the Rust fuzzy matcher is not available, by using `implementation = "prefer_rust"`
            --
            -- See the fuzzy documentation for more information
            fuzzy = { implementation = "prefer_rust_with_warning" },
        },
        opts_extend = { "sources.default" },
        lazy = false,
    },

    {
        "giuxtaposition/blink-cmp-copilot",
        dependencies = { "zbirenbaum/copilot.lua" },
    },

    {
        "maxandron/goplements.nvim",
        lazy = true,
        ft = "go",
        opts = {},
    },
}
