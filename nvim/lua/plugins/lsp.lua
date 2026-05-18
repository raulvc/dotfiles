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
          "jsonls",
          "yamlls",
          "ts_ls",
          "sqls",
          "buf_ls",
          "terraformls",
          "ruby_lsp",
          "lemminx",
          "jdtls",
          "groovyls",
        },
      }
    end,
  },
  {
    "neovim/nvim-lspconfig",
    lazy = false,
    config = function()
      require("configs.jar-sources").setup()

      -- Prevent LSP from ever attaching to diffview:// buffers
      local orig_buf_attach = vim.lsp.buf_attach_client
      vim.lsp.buf_attach_client = function(bufnr, client_id)
        if not vim.api.nvim_buf_is_valid(bufnr) then
          return false
        end
        local bufname = vim.api.nvim_buf_get_name(bufnr)
        if bufname:match "^diffview://" then
          return false
        end
        return orig_buf_attach(bufnr, client_id)
      end

      local capabilities = require("blink.cmp").get_lsp_capabilities()
      local builtin = require "telescope.builtin"

      -- Compatibility patches for Go plugins on Neovim 0.11+
      do
        local ok, goplements = pcall(require, "goplements")
        if ok and type(goplements) == "table" then
          local original_impl_callback = goplements.implementation_callback
          if type(original_impl_callback) == "function" then
            goplements.implementation_callback = function(fcache, result, publish_names)
              local wrapped_publish = function(names)
                publish_names(names or {})
              end

              local ok_cb, err = pcall(original_impl_callback, fcache, result, wrapped_publish)
              if ok_cb then
                return
              end

              local names = {}
              if result then
                for _, impl in pairs(result) do
                  local uri = impl.uri
                  local impl_line = impl.range.start.line
                  local impl_start = impl.range.start.character
                  local impl_end = impl.range["end"].character
                  local data = {}
                  local buf = vim.uri_to_bufnr(uri)

                  if vim.api.nvim_buf_is_loaded(buf) then
                    data = vim.api.nvim_buf_get_lines(buf, 0, impl_line + 1, false)
                  else
                    local file = vim.uri_to_fname(uri)
                    data = fcache[file]
                    if not data then
                      local ok_read, read_result = pcall(vim.fn.readfile, file)
                      data = ok_read and read_result or {}
                      fcache[file] = data
                    end
                  end

                  local package_name = ""
                  if goplements.config and goplements.config.display_package then
                    package_name = goplements.get_package_name(data)
                    if package_name ~= "" then
                      package_name = package_name .. "."
                    end
                  end

                  local impl_text = data[impl_line + 1]
                  if type(impl_text) == "string" and impl_text ~= "" then
                    local safe_start = math.max(1, impl_start + 1)
                    local safe_end = math.max(safe_start, impl_end)
                    local name = impl_text:sub(safe_start, safe_end)
                    if name ~= "" then
                      table.insert(names, package_name .. name)
                    end
                  end
                end
              end

              vim.schedule(function()
                vim.notify(
                  "goplements fallback patch handled implementation parsing failure: " .. tostring(err),
                  vim.log.levels.DEBUG
                )
              end)
              wrapped_publish(names)
            end
          end

          local original_setup = goplements.setup
          if type(original_setup) == "function" then
            goplements.setup = function(opts)
              original_setup(opts)
              if goplements._namespace == 0 then
                goplements._namespace = vim.api.nvim_create_namespace(
                  (goplements.config and goplements.config.namespace_name) or "goplements"
                )
              end
            end
          end
        end
      end

      local original_bufload = vim.fn.bufload
      vim.fn.bufload = function(buf)
        local ok, result = pcall(original_bufload, buf)
        if not ok then
          local msg = tostring(result)
          if msg:match "E325" then
            return 0
          end
          error(result)
        end
        return result
      end

      -- Fix: "Cursor position outside buffer" when navigating to external files
      -- (e.g. decompiled .class files from Kotlin LSP with custom URI schemes)
      -- The LSP may return positions beyond the buffer's current line count when
      -- content is loaded asynchronously. We patch nvim_win_set_cursor to clamp.
      local original_win_set_cursor = vim.api.nvim_win_set_cursor
      ---@diagnostic disable-next-line: duplicate-set-field
      vim.api.nvim_win_set_cursor = function(win, pos)
        local row, col = pos[1], pos[2]
        local ok, bufnr = pcall(vim.api.nvim_win_get_buf, win)
        if ok and bufnr then
          -- Try to load the buffer if it isn't loaded yet
          if not vim.api.nvim_buf_is_loaded(bufnr) then
            vim.fn.bufload(bufnr)
          end
          local line_count = vim.api.nvim_buf_line_count(bufnr)
          if row > line_count then
            row = math.max(1, line_count)
            col = 0
          end
        end
        return original_win_set_cursor(win, { row, col })
      end

      -- Track user-initiated buffer modifications so we can distinguish
      -- user edits from LSP-pushed edits in format_on_save
      vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
        callback = function(args)
          local dominated_fts = { kotlin = true, java = true, groovy = true }
          if dominated_fts[vim.bo[args.buf].filetype] then
            vim.b[args.buf]._user_modified = true
          end
        end,
      })

      -- Block unsolicited workspace/applyEdit from jdtls on Java buffers
      -- jdtls pushes import reorganization edits asynchronously after indexing,
      -- which conflicts with conform's google-java-format on save.
      -- Block jdtls from responding to willSaveWaitUntil (pre-save edits)
      local orig_will_save = vim.lsp.handlers["textDocument/willSaveWaitUntil"]
      vim.lsp.handlers["textDocument/willSaveWaitUntil"] = function(err, result, ctx, config)
        local client = vim.lsp.get_client_by_id(ctx.client_id)
        if client and client.name == "jdtls" then
          return nil
        end
        if orig_will_save then
          return orig_will_save(err, result, ctx, config)
        end
      end

      local orig_apply = vim.lsp.handlers["workspace/applyEdit"]
      vim.lsp.handlers["workspace/applyEdit"] = function(err, result, ctx, config)
        local client = vim.lsp.get_client_by_id(ctx.client_id)
        if client and client.name == "jdtls" then
          local label = result and result.label or ""
          -- Allow only explicitly user-triggered edits (rename, extract, etc.)
          local allowed = {
            "rename",
            "extract",
            "inline",
            "move",
            "generate",
            "override",
            "implement",
            "delegate",
          }
          local dominated = true
          for _, keyword in ipairs(allowed) do
            if label:lower():find(keyword) then
              dominated = false
              break
            end
          end
          if dominated then
            return { applied = false }
          end
        end
        return orig_apply(err, result, ctx, config)
      end

      -- Configure servers using vim.lsp.config (Neovim 0.11+)
      vim.lsp.config("lua_ls", {
        capabilities = capabilities,
        settings = {
          Lua = {
            format = {
              enable = false, -- Disable LSP formatting, let conform handle it
            },
          },
        },
      })

      vim.lsp.config("bashls", {
        capabilities = capabilities,
        filetypes = { "sh", "bash" },
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
              unusedvariable = true,
              unusedwrite = true,
              useany = true,
              unreachable = true,
              nilness = true,
              shadow = true,
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
        settings = {
          python = {
            analysis = {
              -- Enable all analysis features
              typeCheckingMode = "basic", -- or "strict" for more rigorous checking
              autoSearchPaths = true,
              useLibraryCodeForTypes = true,
              autoImportCompletions = true,
              diagnosticMode = "openFilesOnly",

              -- Disable specific diagnostics if needed
              diagnosticSeverityOverrides = {
                reportMissingImports = "error",
                reportMissingTypeStubs = "warning",
                reportUnusedImport = "information",
                reportUnusedClass = "information",
                reportUnusedFunction = "information",
                reportUnusedVariable = "information",
                reportDuplicateImport = "warning",
                reportWildcardImportFromLibrary = "warning",
              },

              -- Include/exclude paths
              include = {},
              exclude = {
                "**/node_modules",
                "**/__pycache__",
                "**/.*",
              },

              -- Stub search paths
              stubPath = "",

              -- Virtual environment support
              venvPath = "",
              venv = "",
            },

            -- Formatting (disable if using external formatters like black)
            formatting = {
              provider = "none", -- Let conform.nvim or other tools handle formatting
            },

            -- Linting (disable if using external linters like flake8, pylint)
            linting = {
              enabled = false, -- Let external linters handle this
            },
          },
        },
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

      -- Locate the kotlin-lsp launcher shipped by Mason. The Mason package
      -- nests its payload under a versioned directory, so glob for it.
      local function resolve_kotlin_lsp_cmd()
        local pkg_root = vim.fn.expand "~/.local/share/nvim/mason/packages/kotlin-lsp"
        -- Prefer the new launcher (bin/intellij-server); fall back to the
        -- deprecated kotlin-lsp.sh for older Mason builds.
        local patterns = {
          "/kotlin-server-*/bin/intellij-server",
          "/kotlin-server-*/kotlin-lsp.sh",
        }
        for _, pat in ipairs(patterns) do
          for _, path in ipairs(vim.fn.glob(pkg_root .. pat, true, true)) do
            if vim.fn.executable(path) == 1 then
              return path
            end
          end
        end
        vim.schedule(function()
          vim.notify(
            "kotlin_lsp: launcher not found under " .. pkg_root .. ". Run :MasonInstall kotlin-lsp",
            vim.log.levels.ERROR
          )
        end)
        return nil
      end

      local kotlin_lsp_launcher = resolve_kotlin_lsp_cmd()

      vim.lsp.config("kotlin_lsp", {
        capabilities = capabilities,
        root_markers = {
          "settings.gradle",
          "settings.gradle.kts",
          "build.gradle",
          "build.gradle.kts",
          "pom.xml",
          ".git",
        },
        init_options = {
          storagePath = vim.fn.stdpath "cache" .. "/kotlin-language-server",
        },
        cmd = kotlin_lsp_launcher and { kotlin_lsp_launcher, "--stdio" } or { "false" },
        settings = {
          kotlin = {
            compiler = {
              jvm = {
                target = "17",
              },
            },
            completion = {
              snippets = {
                enabled = true,
              },
            },
            linting = {
              debounceTime = 500,
            },
            hints = {
              typeHints = false,
              parameterHints = false,
              chainingHints = false,
            },
            formatting = {
              -- Disable if using ktlint/ktfmt via conform.nvim
              enabled = false,
            },
            indexing = {
              enabled = true,
            },
            externalSources = {
              useKlsScheme = true,
              autoConvertToKotlin = false,
            },
            debugAdapter = {
              enabled = false,
              path = "",
            },
          },
        },
      })

      vim.lsp.config("jsonls", {
        capabilities = capabilities,
        settings = {
          json = {
            format = {
              enable = false, -- Disable LSP formatting, let conform handle it
            },
          },
        },
      })

      vim.lsp.config("yamlls", {
        capabilities = capabilities,
        settings = {
          yaml = {
            format = {
              enable = false, -- Disable LSP formatting, let conform handle it
            },
            validate = true,
            completion = true,
            hover = true,
            -- Enable schema store for automatic schema detection
            schemaStore = {
              enable = true,
              url = "https://www.schemastore.org/api/json/catalog.json",
            },
            -- Allow custom tags (optional, but useful for some YAML files)
            customTags = {
              "!reference sequence",
              "!reference mapping",
              "!reference scalar",
            },
            schemas = {
              -- GitLab CI/CD
              ["https://gitlab.com/gitlab-org/gitlab/-/raw/master/app/assets/javascripts/editor/schema/ci.json"] = {
                "/.gitlab-ci.yml",
                "/.gitlab-ci.yaml",
                "/*gitlab-ci*.{yml,yaml}",
                "/.gitlab/ci/*.{yml,yaml}",
              },
              -- GitHub (keeping for reference)
              ["https://json.schemastore.org/github-workflow.json"] = "/.github/workflows/*",
              ["https://json.schemastore.org/github-action.json"] = "/action.{yml,yaml}",
              -- Docker
              ["https://json.schemastore.org/docker-compose.json"] = {
                "/*docker-compose*.{yml,yaml}",
                "/compose.{yml,yaml}",
              },
              -- Kubernetes
              ["https://json.schemastore.org/kustomization.json"] = "/kustomization.{yml,yaml}",
              kubernetes = "/*.k8s.{yml,yaml}",
              -- Ansible
              ["https://json.schemastore.org/ansible-playbook.json"] = {
                "/*playbook*.{yml,yaml}",
                "/playbooks/**/*.{yml,yaml}",
              },
              ["https://json.schemastore.org/ansible-inventory.json"] = {
                "/inventory.{yml,yaml}",
                "/inventory/*.{yml,yaml}",
              },
              -- Helm
              ["https://json.schemastore.org/helmfile.json"] = "/helmfile.{yml,yaml}",
              ["https://json.schemastore.org/chart.json"] = "/Chart.{yml,yaml}",
              -- CI/CD Tools
              ["https://json.schemastore.org/azure-pipelines.json"] = "/azure-pipelines.{yml,yaml}",
              ["https://json.schemastore.org/circleciconfig.json"] = "/.circleci/config.{yml,yaml}",
              ["https://json.schemastore.org/travisci.json"] = "/.travis.{yml,yaml}",
              -- Config files
              ["https://json.schemastore.org/prettierrc.json"] = "/.prettierrc.{yml,yaml}",
              ["https://json.schemastore.org/dependabot-2.0.json"] = "/.github/dependabot.{yml,yaml}",
              ["https://json.schemastore.org/renovate.json"] = {
                "/renovate.{yml,yaml}",
                "/.renovaterc.{yml,yaml}",
                "/.github/renovate.{yml,yaml}",
              },
            },
          },
        },
      })

      vim.lsp.config("ts_ls", {
        capabilities = capabilities,
        settings = {
          typescript = {
            format = {
              enable = false, -- Disable LSP formatting, let conform handle it
            },
            inlayHints = {
              includeInlayParameterNameHints = "all",
              includeInlayParameterNameHintsWhenArgumentMatchesName = false,
              includeInlayFunctionParameterTypeHints = true,
              includeInlayVariableTypeHints = true,
              includeInlayPropertyDeclarationTypeHints = true,
              includeInlayFunctionLikeReturnTypeHints = true,
              includeInlayEnumMemberValueHints = true,
            },
            suggest = {
              includeCompletionsForModuleExports = true,
            },
            preferences = {
              importModuleSpecifier = "relative",
              includePackageJsonAutoImports = "auto",
            },
          },
          javascript = {
            format = {
              enable = false, -- Disable LSP formatting, let conform handle it
            },
            inlayHints = {
              includeInlayParameterNameHints = "all",
              includeInlayParameterNameHintsWhenArgumentMatchesName = false,
              includeInlayFunctionParameterTypeHints = true,
              includeInlayVariableTypeHints = true,
              includeInlayPropertyDeclarationTypeHints = true,
              includeInlayFunctionLikeReturnTypeHints = true,
              includeInlayEnumMemberValueHints = true,
            },
            suggest = {
              includeCompletionsForModuleExports = true,
            },
          },
        },
      })

      vim.lsp.config("sqls", {
        capabilities = capabilities,
        settings = {
          sqls = {
            connections = {
              -- Add your database connections here if needed
              -- Example:
              -- {
              --   driver = "postgresql",
              --   dataSourceName = "host=127.0.0.1 port=5432 user=postgres password=password dbname=mydb sslmode=disable",
              -- },
            },
          },
        },
      })

      vim.lsp.config("buf_ls", {
        capabilities = capabilities,
        settings = {
          -- buf_ls uses buf.yaml for most configuration
          -- Additional settings can be added here if needed
        },
      })

      vim.lsp.config("terraformls", {
        capabilities = capabilities,
        filetypes = { "terraform", "tf", "hcl" },
        settings = {
          terraform = {
            -- Enable experimental features
            experimentalFeatures = {
              validateOnSave = true,
              prefillRequiredFields = true,
            },
          },
        },
      })

      vim.lsp.config("ruby_lsp", {
        capabilities = capabilities,
        filetypes = { "ruby", "eruby" },
        settings = {
          rubyLsp = {
            formatter = "none", -- Let conform/cookstyle handle formatting
            linters = {}, -- Disable built-in linters, use cookstyle via conform
            enabledFeatures = {
              "documentHighlights",
              "documentSymbols",
              "foldingRanges",
              "selectionRanges",
              "semanticHighlighting",
              "formatting",
              "diagnostics",
              "codeActions",
              "codeLens",
              "completion",
              "definition",
              "hover",
              "references",
              "rename",
              "signatureHelp",
              "workspaceSymbol",
            },
          },
        },
      })

      vim.lsp.config("lemminx", {
        capabilities = capabilities,
        filetypes = { "xml", "xsd", "xsl", "xslt", "svg" },
        settings = {
          xml = {
            catalogs = {},
            logs = { client = true },
            format = {
              enabled = true,
              splitAttributes = false,
            },
            validation = {
              enabled = true,
              noGrammar = "hint",
            },
            completion = {
              autoCloseTags = true,
            },
            -- Maven specific settings
            java = {
              home = vim.fn.getenv "JAVA_HOME",
            },
            downloadExternalResources = {
              enabled = true,
            },
            fileAssociations = {
              {
                pattern = "pom.xml",
                systemId = "https://maven.apache.org/xsd/maven-4.0.0.xsd",
              },
            },
          },
        },
      })

      vim.lsp.config("groovyls", {
        capabilities = capabilities,
        filetypes = { "groovy" },
        settings = {
          groovy = {
            format = {
              enable = false,
            },
          },
        },
      })

      vim.lsp.config("jdtls", {
        capabilities = capabilities,
        filetypes = { "java" },
        cmd = {
          "jdtls",
          "--jvm-arg=-javaagent:" .. vim.fn.expand "~/.local/share/java/lombok.jar",
          "--jvm-arg=-Xmx1g",
          "--jvm-arg=-XX:+UseG1GC",
          "--jvm-arg=-XX:+UseStringDeduplication",
        },
        settings = {
          java = {
            format = {
              enabled = false,
              onType = { enabled = false },
            },
            signatureHelp = { enabled = true },
            contentProvider = { preferred = "fernflower" },
            completion = {
              favoriteStaticMembers = {
                "org.junit.Assert.*",
                "org.junit.jupiter.api.Assertions.*",
                "org.mockito.Mockito.*",
                "lombok.Builder",
                "lombok.Data",
                "lombok.Getter",
                "lombok.Setter",
              },
            },
            sources = {
              organizeImports = {
                starThreshold = 9999,
                staticStarThreshold = 9999,
              },
            },
            saveActions = {
              organizeImports = false,
            },
            autobuild = { enabled = false },
            cleanup = {
              actionsOnSave = {},
            },
            codeGeneration = {
              toString = {
                template = "${object.className}{${member.name()}=${member.value}, ${otherMembers}}",
              },
            },
            edit = {
              validateAllOpenBuffersOnChanges = false,
            },
            references = {
              includeDecompiledSources = false,
            },
            implementationsCodeLens = { enabled = false },
            referencesCodeLens = { enabled = false },
            inlayHints = {
              parameterNames = { enabled = "none" },
            },
            import = {
              exclusions = {
                "**/node_modules/**",
                "**/.metadata/**",
                "**/archetype-resources/**",
                "**/META-INF/maven/**",
              },
            },
          },
        },
      })

      -- Disable LSP formatting and save actions for filetypes where conform is the sole formatter
      vim.api.nvim_create_autocmd("LspAttach", {
        callback = function(args)
          local client = vim.lsp.get_client_by_id(args.data.client_id)
          if not client then
            return
          end

          -- Detach LSP from diffview buffers
          local bufname = vim.api.nvim_buf_get_name(args.buf)
          if bufname:match "^diffview://" then
            vim.schedule(function()
              pcall(vim.lsp.buf_detach_client, args.buf, client.id)
            end)
            return
          end

          -- For jdtls specifically, aggressively disable all formatting/edit capabilities
          if client.name == "jdtls" then
            client.server_capabilities.documentFormattingProvider = false
            client.server_capabilities.documentRangeFormattingProvider = false
            client.server_capabilities.documentOnTypeFormattingProvider = nil
            if client.server_capabilities.textDocumentSync then
              if type(client.server_capabilities.textDocumentSync) == "table" then
                client.server_capabilities.textDocumentSync.willSaveWaitUntil = false
                client.server_capabilities.textDocumentSync.willSave = false
              elseif type(client.server_capabilities.textDocumentSync) == "number" then
                client.server_capabilities.textDocumentSync = 0 -- None
              end
            end
            return
          end

          local dominated_fts = { kotlin = true, groovy = true }
          if dominated_fts[vim.bo[args.buf].filetype] then
            client.server_capabilities.documentFormattingProvider = false
            client.server_capabilities.documentRangeFormattingProvider = false
            if client.server_capabilities.textDocumentSync then
              if type(client.server_capabilities.textDocumentSync) == "table" then
                client.server_capabilities.textDocumentSync.willSaveWaitUntil = false
                client.server_capabilities.textDocumentSync.willSave = false
              end
            end
          end
        end,
      })

      -- Keymappings with improved workspace symbols
      -- vim.keymap.set("n", "<leader>gd", builtin.lsp_definitions, { desc = "[G]oto [D]efinition" })
      -- vim.keymap.set("n", "<leader>gi", builtin.lsp_implementations, { desc = "[G]oto [I]mplementation" })
      -- vim.keymap.set("n", "<leader>gr", builtin.lsp_references, { desc = "[G]oto [R]eferences" })
      vim.keymap.set("n", "<leader>gs", builtin.lsp_dynamic_workspace_symbols, { desc = "[G]oto [S]ymbol" })
      vim.keymap.set("n", "<leader>ds", builtin.lsp_document_symbols, { desc = "[D]ocument [S]ymbols" })
      vim.keymap.set("n", "<leader>rn", function()
        return ":IncRename " .. vim.fn.expand "<cword>"
      end, { expr = true, desc = "[R]e[n]ame" })
      -- vim.keymap.set({ "n", "v" }, "<leader>ca", vim.lsp.buf.code_action, { desc = "[C]ode [A]ctions" })
      vim.keymap.set("n", "<C-q>", vim.lsp.buf.hover, { desc = "Hover Documentation" })
      local function lsp_picker_with_symbol_hl(picker_fn)
        return function()
          local symbol = vim.fn.expand "<cword>"
          local previewer_factory = _G._telescope_make_lsp_symbol_previewer
          local winbar_wrapper = _G._telescope_with_preview_winbar
          local opts = {}
          if symbol and symbol ~= "" and previewer_factory and winbar_wrapper then
            opts.previewer = winbar_wrapper(previewer_factory(symbol)) {}
          end
          picker_fn(opts)
        end
      end

      vim.keymap.set("n", "<M-r>", lsp_picker_with_symbol_hl(builtin.lsp_references), { desc = "[G]oto [R]eferences" })
      vim.keymap.set(
        "n",
        "<M-g>",
        lsp_picker_with_symbol_hl(builtin.lsp_implementations),
        { desc = "[G]oto [I]mplementation" }
      )
      vim.keymap.set("n", "<M-d>", lsp_picker_with_symbol_hl(builtin.lsp_definitions), { desc = "[G]oto [D]efinition" })
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
        trigger = { prefetch_on_insert = false },
        documentation = { auto_show = true },
        list = { selection = { auto_insert = false } },
        menu = {
          draw = {
            -- We don't need label_description now because label and label_description are already
            -- combined together in label by colorful-menu.nvim.
            columns = { { "kind_icon" }, { "label", gap = 1 } },
            components = {
              label = {
                text = function(ctx)
                  return require("colorful-menu").blink_components_text(ctx)
                end,
                highlight = function(ctx)
                  return require("colorful-menu").blink_components_highlight(ctx)
                end,
              },
            },
          },
        },
      },

      signature = { enabled = true },

      -- Default list of enabled providers defined so that you can extend it
      -- elsewhere in your config, without redefining it, due to `opts_extend`
      sources = {
        default = { "lazydev", "lsp", "go_deep", "path", "snippets", "buffer", "minuet", "emoji", "sql" },
        providers = {
          lazydev = {
            name = "LazyDev",
            module = "lazydev.integrations.blink",
            -- make lazydev completions top priority (see `:h blink.cmp`)
            score_offset = 100,
          },
          minuet = {
            name = "minuet",
            module = "minuet.blink",
            score_offset = -100,
            async = true,
            timeout_ms = 3000,
            should_show_items = function()
              local ft = vim.bo.filetype
              return not vim.tbl_contains({
                "codecompanion",
                "codecompanion-chat",
                "codecompanion-inline",
                "codecompanion_actions",
                "codecompanion_chat",
                "codecompanion_inline",
                "CodeCompanion",
              }, ft)
            end,
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
    "milanglacier/minuet-ai.nvim",
    lazy = false,
    config = function()
      require("minuet").setup {
        provider = "openai_compatible",
        n_completions = 1,
        context_window = 2048,
        throttle = 400,
        debounce = 200,
        request_timeout = 4,
        virtualtext = {
          auto_trigger_ft = { "*" },
          keymap = {
            accept = "<C-l>",
            accept_line = "<A-a>",
            prev = "<A-[>",
            next = "<A-]>",
            dismiss = "<A-e>",
          },
        },
        provider_options = {
          openai_compatible = {
            api_key = "REQUESTER_TOKEN",
            end_point = (vim.env.GENPLAT_URL or "") .. "/v1/chat/completions",
            model = "gpt-4.1-nano",
            name = "GenPlat",
            stream = true,
            optional = {
              max_tokens = 128,
              -- no reasoning_effort — this isn't a reasoning model
            },
          },
        },
      }

      vim.api.nvim_create_autocmd("FileType", {
        pattern = { "codecompanion-chat", "codecompanion_chat" },
        callback = function(args)
          pcall(function()
            require("minuet").toggle_auto_trigger(args.buf, false)
          end)
        end,
      })
    end,
  },

  {
    "maxandron/goplements.nvim",
    lazy = true,
    ft = "go",
    opts = function()
      local ok, goplements = pcall(require, "goplements")
      if ok and type(goplements) == "table" and goplements._namespace == 0 then
        goplements._namespace = vim.api.nvim_create_namespace "goplements"
      end
      return {}
    end,
  },
}
