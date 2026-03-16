return {
  {
    "nvim-telescope/telescope.nvim",
    cmd = "Telescope",
    dependencies = {
      "nvim-treesitter/nvim-treesitter",
      "nvim-tree/nvim-tree.lua",
      "nvim-lua/plenary.nvim",
      { "nvim-telescope/telescope-fzf-native.nvim", build = "make" },
      "nvim-telescope/telescope-ui-select.nvim",
      "nvim-tree/nvim-web-devicons",
      "debugloop/telescope-undo.nvim",
      "nvim-telescope/telescope-frecency.nvim",
      "nvim-telescope/telescope-smart-history.nvim",
      "kkharji/sqlite.lua",
    },
    lazy = false,
    config = function()
      local actions = require "telescope.actions"
      local action_state = require "telescope.actions.state"

      -- Pre-compile patterns for better performance
      local test_pattern_compiled = vim.regex [[\v(test|spec|mock|Test|Spec|Mock)]]

      -- Faster test file check using single regex
      local function is_test_file(filename)
        if not filename then
          return false
        end
        return test_pattern_compiled:match_str(filename) ~= nil
      end

      -- Cached highlight for test files
      local test_file_hl = "TelescopeTestFile"

      -- Optimized entry maker for live_grep - minimal allocation version
      local function make_entry_with_test_highlight()
        local make_entry = require "telescope.make_entry"
        local original_maker = make_entry.gen_from_vimgrep()

        return function(entry)
          local made = original_maker(entry)
          if not made or not made.filename then
            return made
          end

          -- Quick test: skip regex if no potential match characters
          local fname = made.filename
          if
            not (
              fname:find("test", 1, true)
              or fname:find("spec", 1, true)
              or fname:find("mock", 1, true)
              or fname:find("Test", 1, true)
              or fname:find("Spec", 1, true)
              or fname:find("Mock", 1, true)
            )
          then
            return made
          end

          if test_pattern_compiled:match_str(fname) then
            local original_display = made.display
            if type(original_display) == "function" then
              made.display = function(e)
                local text, existing_hl = original_display(e)
                if type(text) == "table" then
                  return text
                end
                local hl = existing_hl or {}
                table.insert(hl, { { 0, #text }, "TelescopeTestFile" })
                return text, hl
              end
            end
          end

          return made
        end
      end

      -- Optimized file entry maker
      local function make_file_entry_with_test_highlight()
        local make_entry = require "telescope.make_entry"
        local original_maker = make_entry.gen_from_file()

        return function(entry)
          local made = original_maker(entry)
          if not made or not made.value then
            return made
          end

          if is_test_file(made.value) then
            local original_display = made.display
            local is_callable = type(original_display) == "function"

            made.display = function(e)
              local display_text, existing_hl
              if is_callable then
                display_text, existing_hl = original_display(e)
              else
                display_text = original_display
              end
              if type(display_text) == "table" then
                return display_text
              end
              local hl = existing_hl or {}
              table.insert(hl, { { 0, #display_text }, test_file_hl })
              return display_text, hl
            end
          end

          return made
        end
      end

      -- Optimized LSP entry maker
      local function make_lsp_entry_with_test_highlight()
        local make_entry = require "telescope.make_entry"
        local original_maker = make_entry.gen_from_quickfix()

        return function(entry)
          local made = original_maker(entry)
          if not made then
            return nil
          end

          if is_test_file(made.filename) then
            local original_display = made.display
            local is_callable = type(original_display) == "function"

            made.display = function(e)
              local display_text, existing_hl
              if is_callable then
                display_text, existing_hl = original_display(e)
              else
                display_text = original_display
              end
              if type(display_text) == "table" then
                return display_text
              end
              local hl = existing_hl or {}
              table.insert(hl, { { 0, #display_text }, test_file_hl })
              return display_text, hl
            end
          end
          return made
        end
      end

      local function is_file_entry(entry)
        if not entry then
          return false
        end
        if entry.path or entry.filename then
          return true
        end
        if entry.bufnr then
          local name = vim.api.nvim_buf_get_name(entry.bufnr)
          return name ~= nil and name ~= ""
        end
        return false
      end

      local function smart_open_file(prompt_bufnr)
        local selection = action_state.get_selected_entry()
        local picker = action_state.get_current_picker(prompt_bufnr)
        local multi = picker and picker:get_multi_selection() or {}

        -- Handle non-file selections (like commands) - use default action
        if not selection or (not selection.path and not selection.filename) then
          pcall(actions.select_default, prompt_bufnr)
          return
        end

        -- Multi-selection or non-file - use default action
        if (multi and #multi > 0) or not is_file_entry(selection) then
          pcall(actions.select_default, prompt_bufnr)
          return
        end

        -- For file selections, we need custom behavior
        -- Store the file info before closing
        local file_path = selection.filename or selection.path
        local lnum = selection.lnum
        local col = selection.col

        if not file_path then
          pcall(actions.select_default, prompt_bufnr)
          return
        end

        -- Use default action to let telescope-all-recent track it
        pcall(actions.select_default, prompt_bufnr)

        -- Then immediately apply our custom navigation logic
        vim.schedule(function()
          local tree_was_open = false
          local ok_tree, api = pcall(require, "nvim-tree.api")
          if ok_tree then
            tree_was_open = pcall(api.tree.is_visible) and api.tree.is_visible()
          end

          local content_windows = 0
          for _, win in ipairs(vim.api.nvim_list_wins()) do
            local success, buf = pcall(vim.api.nvim_win_get_buf, win)
            if success then
              local buf_name = pcall(vim.api.nvim_buf_get_name, buf) and vim.api.nvim_buf_get_name(buf) or ""
              local filetype_ok, filetype = pcall(vim.api.nvim_buf_get_option, buf, "filetype")
              if filetype_ok and filetype ~= "NvimTree" and not buf_name:match "NvimTree" then
                content_windows = content_windows + 1
              end
            end
          end

          -- Re-navigate based on our smart logic
          if content_windows <= 1 then
            pcall(vim.cmd, "tabedit " .. vim.fn.fnameescape(file_path))
          end
          -- If multiple windows, file is already open from select_default

          if lnum and col then
            pcall(vim.api.nvim_win_set_cursor, 0, { lnum, math.max(0, (col - 1)) })
            pcall(vim.cmd, "normal! zz")
          end

          if tree_was_open and ok_tree then
            pcall(function()
              if not api.tree.is_visible() then
                api.tree.open()
              end
              vim.schedule(function()
                pcall(api.tree.find_file, file_path)
                pcall(vim.api.nvim_set_current_win, vim.api.nvim_get_current_win())
              end)
            end)
          end
        end)
      end

      -- Optimized tree entry maker with pre-cached values
      local function make_tree_entry_for_files()
        local devicons = require "nvim-web-devicons"
        local make_entry = require "telescope.make_entry"
        local base_maker = make_entry.gen_from_file {}

        -- Pre-compile patterns
        local test_pat = vim.regex [[\v(test|spec|mock)]]
        local config_pat = vim.regex [[\v\.(json|ya?ml|toml)$]]
        local go_pat = vim.regex [[\.go$]]
        local doc_pat = vim.regex [[\v\.(md|txt)$]]

        -- Cache indent strings to avoid repeated string.rep calls
        local indent_cache = {}
        local function get_indent(depth)
          if depth == 0 then
            return ""
          end
          if not indent_cache[depth] then
            indent_cache[depth] = string.rep("  ", depth) .. "└─ "
          end
          return indent_cache[depth]
        end

        return function(entry)
          local base_entry = base_maker(entry)
          if not base_entry then
            return nil
          end

          local path = base_entry.value
          local relative = vim.fn.fnamemodify(path, ":.")
          local segments = vim.split(relative, "/", { plain = true })
          local depth = #segments - 1
          local filename = segments[#segments]

          -- Build directory path
          local dir = depth > 0 and (table.concat(segments, "/", 1, depth) .. "/") or ""

          local tree_indent = get_indent(depth)
          local icon, icon_hl = devicons.get_icon(filename, nil, { default = true })
          icon = icon or "󰈚"
          icon_hl = icon_hl or "DevIconDefault"

          -- Determine highlight using pre-compiled patterns
          local filename_hl
          if test_pat:match_str(filename) then
            filename_hl = "TelescopeTestFile"
          elseif config_pat:match_str(filename) then
            filename_hl = "String"
          elseif go_pat:match_str(filename) then
            filename_hl = "Function"
          elseif doc_pat:match_str(filename) then
            filename_hl = "Special"
          else
            filename_hl = "TelescopeResultsIdentifier"
          end

          -- Pre-compute lengths
          local indent_len = #tree_indent
          local icon_len = #icon
          local dir_len = #dir

          local display_str = tree_indent .. icon .. " " .. dir .. filename

          -- Build highlights array once
          local highlights = {}
          local pos = 0

          if indent_len > 0 then
            highlights[#highlights + 1] = { { pos, indent_len }, "TelescopeTreeIndent" }
          end
          pos = indent_len

          highlights[#highlights + 1] = { { pos, pos + icon_len }, icon_hl }
          pos = pos + icon_len + 1

          if dir_len > 0 then
            highlights[#highlights + 1] = { { pos, pos + dir_len }, "Comment" }
          end
          pos = pos + dir_len

          highlights[#highlights + 1] = { { pos, #display_str }, filename_hl }

          -- Return pre-computed display
          base_entry.display = function()
            return display_str, highlights
          end

          return base_entry
        end
      end

      local previewers = require "telescope.previewers"
      local ns_pathbar = vim.api.nvim_create_namespace "TelescopePathBarNS"

      local function with_preview_winbar(new_previewer)
        return function(opts)
          local p = new_previewer(opts)
          local method = p.preview_fn and "preview_fn" or "preview"
          local orig_preview = p[method]
          local orig_teardown = p.teardown
          local last_timer = nil

          p[method] = function(self, entry, status)
            local ret = orig_preview(self, entry, status)

            local winid = status and status.preview_win
            local path = entry and (entry.filename or entry.path or entry.value)

            -- Cancel any pending timer to avoid stale updates
            if last_timer then
              pcall(vim.fn.timer_stop, last_timer)
              last_timer = nil
            end

            vim.schedule(function()
              -- Validate window still exists
              if not winid or not vim.api.nvim_win_is_valid(winid) then
                return
              end

              local bufnr = vim.api.nvim_win_get_buf(winid)

              -- Set winbar
              if path then
                local shown = vim.fn.fnamemodify(path, ":~:.")
                local left_sep, right_sep = "\u{e0b6}", "\u{e0b4}" -- Nerd Font
                local bar = table.concat {
                  "%#TelescopePathBarSep#",
                  left_sep,
                  "%#TelescopePathBar#",
                  " ",
                  shown,
                  " ",
                  "%#TelescopePathBarSep#",
                  right_sep,
                  "%*",
                }
                pcall(vim.api.nvim_set_option_value, "winbar", bar, { win = winid })
              end

              -- Clear old extmarks and add spacer
              if bufnr and vim.api.nvim_buf_is_valid(bufnr) then
                pcall(vim.api.nvim_buf_clear_namespace, bufnr, ns_pathbar, 0, -1)
                local line_count = vim.api.nvim_buf_line_count(bufnr)
                if line_count > 0 then
                  pcall(vim.api.nvim_buf_set_extmark, bufnr, ns_pathbar, 0, 0, {
                    virt_lines = { { { " ", "TelescopeNormal" } } },
                    virt_lines_above = true,
                    hl_mode = "combine",
                  })
                end
              end
            end)

            return ret
          end

          p.teardown = function(self)
            if last_timer then
              pcall(vim.fn.timer_stop, last_timer)
              last_timer = nil
            end
            local winid2 = self.state and self.state.winid
            local bufnr2 = self.state and self.state.bufnr
            if winid2 and vim.api.nvim_win_is_valid(winid2) then
              pcall(vim.api.nvim_set_option_value, "winbar", "", { win = winid2 })
            end
            if bufnr2 and vim.api.nvim_buf_is_valid(bufnr2) then
              pcall(vim.api.nvim_buf_clear_namespace, bufnr2, ns_pathbar, 0, -1)
            end
            if orig_teardown then
              return orig_teardown(self)
            end
          end

          return p
        end
      end

      -- Toggle state for no-ignore
      local grep_no_ignore = false
      local files_no_ignore = false

      local function toggle_no_ignore(prompt_bufnr)
        local picker = action_state.get_current_picker(prompt_bufnr)
        local prompt = picker:_get_prompt()

        actions.close(prompt_bufnr)

        grep_no_ignore = not grep_no_ignore

        local args = {
          "rg",
          "--color=never",
          "--no-heading",
          "--with-filename",
          "--line-number",
          "--column",
          "--smart-case",
          "--hidden",
          "--glob=!.git/",
        }

        if grep_no_ignore then
          table.insert(args, "--no-ignore")
        end

        vim.schedule(function()
          require("telescope.builtin").live_grep {
            default_text = prompt,
            vimgrep_arguments = args,
            prompt_title = grep_no_ignore and "Live Grep (incl. ignored)" or "Live Grep",
          }
        end)
      end

      local function toggle_files_no_ignore(prompt_bufnr)
        local picker = action_state.get_current_picker(prompt_bufnr)
        local prompt = picker:_get_prompt()

        actions.close(prompt_bufnr)
        files_no_ignore = not files_no_ignore

        vim.schedule(function()
          require("telescope.builtin").find_files {
            default_text = prompt,
            no_ignore = files_no_ignore,
            prompt_title = files_no_ignore and "Find Files (incl. ignored)" or "Find Files",
          }
        end)
      end

      require("telescope").setup {
        defaults = {
          prompt_prefix = "  ",
          selection_caret = "▸ ",
          multi_icon = "+ ",
          sorting_strategy = "ascending",
          border = true,
          borderchars = { "─", "│", "─", "│", "╭", "╮", "╯", "╰" },
          vimgrep_arguments = {
            "rg",
            "--color=never",
            "--no-heading",
            "--with-filename",
            "--line-number",
            "--column",
            "--smart-case",
            "--hidden",
            "--glob=!.git/", -- Exclude .git directory for performance
          },
          file_ignore_patterns = { "^.git/" }, -- Exclude .git directory
          path_display = { "smart" },
          layout_config = {
            horizontal = {
              prompt_position = "top",
              preview_width = 0.5, -- Better balance: 50% preview, 50% files
              results_width = 0.5,
            },
            center = {
              prompt_position = "top",
              preview_cutoff = 40,
            },
            width = 0.95, -- Use 95% of screen width
            height = 0.90, -- Use 90% of screen height
            preview_cutoff = 120,
          },
          history = {
            path = vim.fn.stdpath "data" .. "/telescope_history.sqlite3",
            limit = 100,
          },
          mappings = {
            n = {
              ["q"] = actions.close,
              ["<Esc>"] = actions.close,
              ["<CR>"] = smart_open_file,
              ["<C-h>"] = toggle_no_ignore, -- Toggle hidden/ignored files
            },
            i = {
              ["<Esc>"] = actions.close,
              ["<CR>"] = smart_open_file,
              ["<C-h>"] = toggle_no_ignore, -- Toggle hidden/ignored files
              ["<C-Down>"] = require("telescope.actions").cycle_history_next,
              ["<C-Up>"] = require("telescope.actions").cycle_history_prev,
            },
          },
          file_previewer = with_preview_winbar(previewers.vim_buffer_cat.new),
          grep_previewer = with_preview_winbar(previewers.vim_buffer_vimgrep.new),
          qflist_previewer = with_preview_winbar(previewers.vim_buffer_qflist.new),
        },

        pickers = {
          live_grep = {
            entry_maker = make_entry_with_test_highlight(),
            layout_config = {
              preview_width = 0.7, -- Slightly smaller for grep to see more results
            },
          },
          find_files = {
            entry_maker = make_tree_entry_for_files(),
            hidden = true,
            no_ignore = true,
            find_command = {
              "fd",
              "--type",
              "f",
              "--strip-cwd-prefix",
              "--hidden",
              "--exclude",
              ".git",
            },
            mappings = {
              i = { ["<C-h>"] = toggle_files_no_ignore },
              n = { ["<C-h>"] = toggle_files_no_ignore },
            },
            layout_config = {
              preview_width = 0.5, -- Balanced for file browsing
            },
          },
          buffers = {
            previewer = false, -- No preview needed for buffers
            sort_lastused = true,
            layout_config = {
              width = 0.7, -- Smaller width when no preview
              height = 0.6,
            },
          },
          commands = {
            layout_config = {
              width = 0.8, -- Slightly wider for commands
              height = 0.7,
              preview_width = 0.4, -- Less preview space for commands
            },
          },
          help_tags = {
            layout_config = {
              preview_width = 0.6, -- Larger preview for help content
            },
          },
          lsp_references = {
            entry_maker = make_lsp_entry_with_test_highlight(),
            layout_config = {
              preview_width = 0.7,
            },
          },
          lsp_implementations = {
            entry_maker = make_lsp_entry_with_test_highlight(),
            layout_config = {
              preview_width = 0.7,
            },
          },
          lsp_definitions = {
            entry_maker = make_lsp_entry_with_test_highlight(),
            layout_config = {
              preview_width = 0.7,
            },
          },
          lsp_type_definitions = {
            entry_maker = make_lsp_entry_with_test_highlight(),
            layout_config = {
              preview_width = 0.7,
            },
          },
          oldfiles = {
            layout_config = {
              preview_width = 0.7, -- Slightly smaller for grep to see more results
            },
          },
        },

        extensions = {
          ["ui-select"] = {
            require("telescope.themes").get_dropdown {
              winblend = 10,
              border = true,
              previewer = false,
              shorten_path = false,
            },
          },
          fzf = {
            fuzzy = true,
            override_generic_sorter = true,
            override_file_sorter = true,
            case_mode = "smart_case",
          },
          advanced_git_search = {
            diff_plugin = "diffview",
            git_flags = {},
            git_diff_flags = {},
            show_builtin_git_pickers = false,
            entry_default_author_or_date = "author",
            keymaps = {
              toggle_date_author = "<C-w>",
              open_commit_in_browser = "<C-o>",
              copy_commit_hash = "<C-y>",
            },
            telescope_theme = {
              diff_commit_line = {
                layout_strategy = "horizontal",
                layout_config = {
                  width = 0.85,
                  height = 0.75,
                  preview_width = 0.8, -- Code preview takes 80%
                  prompt_position = "top",
                  mirror = true, -- This flips the layout - preview on left, results on right
                },
                sorting_strategy = "ascending",
              },
              diff_commit_file = {
                layout_strategy = "horizontal",
                layout_config = {
                  width = 0.85,
                  height = 0.75,
                  preview_width = 0.8, -- Code preview takes 80%
                  prompt_position = "top",
                  mirror = true, -- This flips the layout - preview on left, results on right
                },
                sorting_strategy = "ascending",
              },
            },
          },
        },
      }

      -- Kanagawa-inspired telescope highlights
      local function set_telescope_highlights()
        local function hex_to_rgb(hex)
          hex = hex:gsub("#", "")
          return tonumber(hex:sub(1, 2), 16), tonumber(hex:sub(3, 4), 16), tonumber(hex:sub(5, 6), 16)
        end
        local function rgb_to_hex(r, g, b)
          return string.format("#%02x%02x%02x", math.floor(r + 0.5), math.floor(g + 0.5), math.floor(b + 0.5))
        end
        local function blend(fg, bg, alpha)
          local fr, fgc, fb = hex_to_rgb(fg)
          local br, bgC, bb = hex_to_rgb(bg)
          return rgb_to_hex(br + (fr - br) * alpha, bgC + (fgc - bgC) * alpha, bb + (fb - bb) * alpha)
        end

        local colors = {
          bg = "#1f1f28", -- Unified background for all windows
          bg_dark = "#16161d", -- Slightly darker for subtle depth
          fg = "#dcd7ba", -- Kanagawa foreground
          blue = "#7e9cd8", -- Kanagawa blue
          cyan = "#6a9589", -- Kanagawa cyan
          green = "#98bb6c", -- Kanagawa green
          orange = "#ff9e3b", -- Kanagawa orange
          purple = "#957fb8", -- Kanagawa purple
          red = "#e82424", -- Kanagawa red
          yellow = "#e6c384", -- Kanagawa yellow
          gray = "#54546d", -- Kanagawa gray
          border = "#54546d", -- Softer border using gray
        }

        local bar_bg = blend(colors.yellow, colors.bg, 0.22) -- subtle yellow tint
        local bar_fg = blend(colors.yellow, colors.fg, 0.35) -- soft yellow text

        local highlights = {
          TelescopeNormal = { bg = colors.bg, fg = colors.fg },
          TelescopeBorder = { bg = colors.bg, fg = colors.border },
          TelescopePromptNormal = { bg = colors.bg, fg = colors.fg },
          TelescopePromptBorder = { bg = colors.bg, fg = colors.blue },
          TelescopePromptTitle = { bg = colors.blue, fg = colors.bg, bold = true },
          TelescopePromptPrefix = { bg = colors.bg, fg = colors.blue },
          TelescopeResultsNormal = { bg = colors.bg, fg = colors.fg },
          TelescopeResultsBorder = { bg = colors.bg, fg = colors.border },
          TelescopeResultsTitle = { bg = colors.bg, fg = colors.fg },
          TelescopePreviewNormal = { bg = colors.bg, fg = colors.fg },
          TelescopePreviewBorder = { bg = colors.bg, fg = colors.border },
          TelescopePreviewTitle = { bg = colors.green, fg = colors.bg, bold = true },
          TelescopeSelection = { bg = colors.gray, fg = colors.fg, bold = true },
          TelescopeSelectionCaret = { fg = colors.blue, bold = true },
          TelescopeMultiSelection = { fg = colors.cyan, bold = true },
          TelescopeMatching = { fg = colors.orange, bold = true },
          TelescopeTestFile = { bg = "#2a3f2a", fg = colors.green }, -- Green tint for test files
          TelescopePathBar = { bg = bar_bg, fg = bar_fg, bold = true },
          TelescopePathBarSep = { bg = colors.bg, fg = bar_bg },
          -- Additional highlights for tree view
          TelescopeResultsIdentifier = { fg = colors.blue },
          TelescopeTreeIndent = { fg = colors.gray },
        }

        for group, opts in pairs(highlights) do
          vim.api.nvim_set_hl(0, group, opts)
        end
      end

      -- Set highlights after colorscheme loads
      vim.api.nvim_create_autocmd("ColorScheme", {
        pattern = "*",
        callback = set_telescope_highlights,
      })

      -- Set highlights immediately
      set_telescope_highlights()

      require("telescope").load_extension "ui-select"
      require("telescope").load_extension "fzf"
      require("telescope").load_extension "frecency"
      require("telescope").load_extension "smart_history"

      if not vim.env.KITTY_SCROLLBACK_NVIM then
        require("telescope").load_extension "noice"
      end

      require("telescope").load_extension "undo"
      vim.api.nvim_create_user_command("UndoTelescope", function()
        require("telescope").extensions.undo.undo()
      end, { desc = "Open Telescope Undo" })

      -- ============================================================
      -- Multi-select buffer picker for CodeCompanion
      -- ============================================================
      local ms_ns = vim.api.nvim_create_namespace "TelescopeMultiSelectNS"

      local function ms_refresh_pane(sel_buf, selected_order)
        if not sel_buf or not vim.api.nvim_buf_is_valid(sel_buf) then
          return
        end
        vim.api.nvim_set_option_value("modifiable", true, { buf = sel_buf })

        local lines = {}
        if #selected_order == 0 then
          lines = { "  No files selected" }
        else
          for i, path in ipairs(selected_order) do
            local icon = require("nvim-web-devicons").get_icon(path, nil, { default = true }) or "󰈚"
            lines[i] = "  " .. icon .. "  " .. path
          end
        end

        vim.api.nvim_buf_set_lines(sel_buf, 0, -1, false, lines)
        vim.api.nvim_buf_clear_namespace(sel_buf, ms_ns, 0, -1)

        if #selected_order == 0 then
          vim.api.nvim_buf_add_highlight(sel_buf, ms_ns, "Comment", 0, 0, -1)
        else
          for i, path in ipairs(selected_order) do
            local icon = require("nvim-web-devicons").get_icon(path, nil, { default = true }) or "󰈚"
            local icon_end = 2 + #icon
            local path_start = icon_end + 2
            vim.api.nvim_buf_add_highlight(sel_buf, ms_ns, "TelescopeMultiSelectedIcon", i - 1, 0, icon_end)
            vim.api.nvim_buf_add_highlight(sel_buf, ms_ns, "TelescopeMultiSelected", i - 1, path_start, -1)
          end
        end

        vim.api.nvim_set_option_value("modifiable", false, { buf = sel_buf })
      end

      local function ms_highlight_rows(prompt_bufnr, selected_map)
        local picker = action_state.get_current_picker(prompt_bufnr)
        if not picker or not picker.results_bufnr then
          return
        end
        local results_buf = picker.results_bufnr
        if not vim.api.nvim_buf_is_valid(results_buf) then
          return
        end

        vim.api.nvim_buf_clear_namespace(results_buf, ms_ns, 0, -1)

        local manager = picker.manager
        if not manager then
          return
        end

        for i = 1, manager:num_results() do
          local entry = manager:get_entry(i)
          if entry then
            local path = entry.filename or entry.path or entry.value
            if path and selected_map[path] then
              -- Use extmark with high priority so it renders over Telescope's own highlights
              vim.api.nvim_buf_set_extmark(results_buf, ms_ns, i - 1, 0, {
                end_row = i - 1,
                end_col = 0,
                hl_eol = true,
                line_hl_group = "TelescopeMultiSelected",
                priority = 200,
              })
            end
          end
        end
      end

      -- Test keymap to debug the multi-select picker independently
      vim.keymap.set("n", "<leader>mb", function()
        _G.multi_select_picker_open {
          on_select = function(paths)
            vim.notify("Selected: " .. table.concat(paths, ", "), vim.log.levels.INFO)
          end,
        }
      end, { desc = "Test multi-select picker" })

      -- Expose globally so CodeCompanion config can call it
      _G.multi_select_picker_open = function(opts)
        opts = opts or {}
        local on_select = opts.on_select

        local selected_map = {}
        local selected_order = {}
        local selected_entries = {}

        local sel_buf = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = sel_buf })

        local sel_win = nil

        -- Get listed buffers sorted by last used (matching C-Tab behavior)
        local bufs = vim.fn.getbufinfo { buflisted = 1 }
        table.sort(bufs, function(a, b)
          return a.lastused > b.lastused
        end)

        -- Build a bufnr lookup and a plain path list for the entry maker
        local bufnr_map = {}
        local path_list = {}
        for _, buf in ipairs(bufs) do
          local name = buf.name
          if name and name ~= "" and not name:match "NvimTree" then
            local rel = vim.fn.fnamemodify(name, ":.")
            path_list[#path_list + 1] = rel
            bufnr_map[rel] = buf.bufnr
            bufnr_map[name] = buf.bufnr
          end
        end

        local telescope_pickers = require "telescope.pickers"
        local telescope_finders = require "telescope.finders"
        local telescope_conf = require("telescope.config").values

        local function cleanup()
          if sel_win and vim.api.nvim_win_is_valid(sel_win) then
            pcall(vim.api.nvim_win_close, sel_win, true)
          end
          if sel_buf and vim.api.nvim_buf_is_valid(sel_buf) then
            pcall(vim.api.nvim_buf_delete, sel_buf, { force = true })
          end
          sel_win = nil
        end

        local picker_inst = telescope_pickers.new(opts, {
          prompt_title = "Select Buffers",
          results_title = "Open Buffers",
          previewer = require("telescope.config").values.file_previewer {},
          finder = telescope_finders.new_table {
            results = path_list,
            entry_maker = make_tree_entry_for_files(),
          },
          sorter = telescope_conf.generic_sorter(opts),
          attach_mappings = function(prompt_bufnr, map)
            local function toggle_selection()
              local entry = action_state.get_selected_entry()
              if not entry then
                return
              end

              local path = entry.filename or entry.path or entry.value
              if selected_map[path] then
                selected_map[path] = nil
                selected_entries[path] = nil
                for i, p in ipairs(selected_order) do
                  if p == path then
                    table.remove(selected_order, i)
                    break
                  end
                end
              else
                selected_map[path] = true
                selected_entries[path] = {
                  bufnr = entry.bufnr or bufnr_map[path] or bufnr_map[entry.path or ""],
                  path = entry.path or path,
                }
                selected_order[#selected_order + 1] = path
              end

              ms_refresh_pane(sel_buf, selected_order)
              ms_highlight_rows(prompt_bufnr, selected_map)
              actions.move_selection_next(prompt_bufnr)
            end

            local function confirm_selection()
              actions.close(prompt_bufnr)
              cleanup()
              if on_select and #selected_order > 0 then
                local entries = {}
                for _, path in ipairs(selected_order) do
                  entries[#entries + 1] = selected_entries[path]
                end
                on_select(selected_order, entries)
              end
            end

            local function close_picker()
              actions.close(prompt_bufnr)
              cleanup()
            end

            map("i", "<Tab>", toggle_selection)
            map("n", "<Tab>", toggle_selection)
            map("i", "<CR>", confirm_selection)
            map("n", "<CR>", confirm_selection)
            map("i", "<Esc>", close_picker)
            map("n", "<Esc>", close_picker)
            map("n", "q", close_picker)

            -- Re-apply highlights when results change after filtering
            vim.schedule(function()
              local p = action_state.get_current_picker(prompt_bufnr)
              if p then
                local orig_process_complete = p.process_complete
                if orig_process_complete then
                  p.process_complete = function(self2, ...)
                    local ret = orig_process_complete(self2, ...)
                    vim.schedule(function()
                      ms_highlight_rows(prompt_bufnr, selected_map)
                    end)
                    return ret
                  end
                end
              end
            end)

            return true
          end,
        })

        picker_inst:find()

        -- Create floating selection pane below the Telescope layout
        vim.defer_fn(function()
          local picker_obj = action_state.get_current_picker(picker_inst.prompt_bufnr)
          if not picker_obj then
            return
          end

          -- Find the Telescope border window to position relative to it
          local layout = picker_obj.layout
          local results_win = picker_obj.results_win
          if not results_win or not vim.api.nvim_win_is_valid(results_win) then
            return
          end

          -- Get the position of the results window
          local results_pos = vim.api.nvim_win_get_position(results_win)
          local results_width = vim.api.nvim_win_get_width(results_win)
          local results_height = vim.api.nvim_win_get_height(results_win)

          -- Shrink the results window to make room for selection pane
          local sel_height = 8
          local new_results_height = results_height - sel_height - 2
          if new_results_height < 5 then
            new_results_height = 5
            sel_height = results_height - new_results_height - 2
          end
          vim.api.nvim_win_set_height(results_win, new_results_height)

          -- Position the selection pane float below results
          local sel_row = results_pos[1] + new_results_height + 1
          local sel_col = results_pos[2]

          sel_win = vim.api.nvim_open_win(sel_buf, false, {
            relative = "editor",
            row = sel_row,
            col = sel_col,
            width = results_width,
            height = sel_height,
            style = "minimal",
            border = { "╭", "─", "╮", "│", "╯", "─", "╰", "│" },
            title = " 󰈚 Selected Files ",
            title_pos = "center",
            focusable = false,
            zindex = 100,
          })

          vim.api.nvim_set_option_value("number", false, { win = sel_win })
          vim.api.nvim_set_option_value("relativenumber", false, { win = sel_win })
          vim.api.nvim_set_option_value("cursorline", false, { win = sel_win })
          vim.api.nvim_set_option_value(
            "winhighlight",
            "Normal:TelescopeNormal,FloatBorder:TelescopeBorder,FloatTitle:TelescopePromptTitle",
            { win = sel_win }
          )

          ms_refresh_pane(sel_buf, selected_order)

          -- Auto-close selection pane when picker closes
          vim.api.nvim_create_autocmd("BufWipeout", {
            buffer = picker_inst.prompt_bufnr,
            once = true,
            callback = function()
              vim.schedule(cleanup)
            end,
          })
        end, 50)
      end
    end,
  },
  {
    "nvim-telescope/telescope-symbols.nvim",
    lazy = true,
  },
  {
    "prochri/telescope-all-recent.nvim",
    lazy = false,
    dependencies = {
      "nvim-telescope/telescope.nvim",
      "kkharji/sqlite.lua",
      "nvim-telescope/telescope-ui-select.nvim",
    },
    opts = {
      -- Database configuration
      database = {
        folder = vim.fn.stdpath "data",
        file = "telescope-all-recent.sqlite3",
        max_timestamps = 10,
      },
      debug = false,
      -- Pickers to enable
      default = {
        disable = true, -- Disable for all by default
        sorting = "recent",
      },
      pickers = {
        -- Enable only for these pickers
        find_files = {
          disable = false,
          use_cwd = true,
        },
        live_grep = {
          disable = false,
          use_cwd = true,
        },
        commands = {
          disable = false,
          use_cwd = false,
        },
      },
    },
  },
}
