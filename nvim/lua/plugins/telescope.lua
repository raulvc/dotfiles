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

      -- Fast test file detection using plain string.find (no regex overhead)
      local test_file_hl = "TelescopeTestFile"
      local doc_file_hl = "TelescopeDocFile"
      local static_file_hl = "TelescopeStaticFile"
      local function is_static_file(filename)
        if not filename then
          return false
        end
        return filename:find "%.json$"
          or filename:find "%.ya?ml$"
          or filename:find "%.toml$"
          or filename:find "%.xml$"
          or filename:find "%.csv$"
          or filename:find "%.tsv$"
          or filename:find("%.env", 1, true)
          or filename:find "%.avsc$"
      end

      local function is_doc_file(filename)
        if not filename then
          return false
        end
        return filename:find "%.md$"
          or filename:find "%.mdx$"
          or filename:find "%.txt$"
          or filename:find "%.rst$"
          or filename:find "%.adoc$"
          or filename:find("README", 1, true)
          or filename:find("CHANGELOG", 1, true)
          or filename:find("LICENSE", 1, true)
          or filename:find("CONTRIBUTING", 1, true)
      end

      local function is_test_file(filename)
        if not filename then
          return false
        end
        -- Case-sensitive plain substring checks are the fastest possible approach
        return filename:find("test", 1, true)
          or filename:find("spec", 1, true)
          or filename:find("mock", 1, true)
          or filename:find("Test", 1, true)
          or filename:find("Spec", 1, true)
          or filename:find("Mock", 1, true)
      end

      -- Generic factory: wraps any entry maker to highlight test/doc/static files
      -- Returns a function that lazily initializes the underlying maker on first call,
      -- so it can be assigned directly to entry_maker (Telescope calls it with raw entries).
      local function wrap_entry_maker_with_test_hl(make_original)
        return function(opts)
          local original_maker = nil
          return function(entry)
            if not original_maker then
              original_maker = make_original(opts)
            end
            local made = original_maker(entry)
            if not made then
              return nil
            end
            local fname = made.filename or made.value
            if not fname then
              return made
            end
            local hl_group
            if is_test_file(fname) then
              hl_group = test_file_hl
            elseif is_doc_file(fname) then
              hl_group = doc_file_hl
            elseif is_static_file(fname) then
              hl_group = static_file_hl
            end
            if hl_group then
              made._file_hl_group = hl_group
              -- Wrap display to apply line highlight via display_highlights
              local orig_display = made.display
              made.display = function(m)
                if type(orig_display) == "function" then
                  local text, highlights = orig_display(m)
                  highlights = highlights or {}
                  table.insert(highlights, 1, { { 0, #text }, hl_group })
                  return text, highlights
                elseif type(orig_display) == "string" then
                  return orig_display, { { { 0, #orig_display }, hl_group } }
                end
                return orig_display, {}
              end
            end
            return made
          end
        end
      end

      local make_entry_with_test_highlight = wrap_entry_maker_with_test_hl(function(opts)
        return require("telescope.make_entry").gen_from_vimgrep(opts)
      end)

      local make_file_entry_with_test_highlight = wrap_entry_maker_with_test_hl(function(opts)
        return require("telescope.make_entry").gen_from_file(opts)
      end)

      local make_lsp_entry_with_test_highlight = wrap_entry_maker_with_test_hl(function(opts)
        return require("telescope.make_entry").gen_from_quickfix(opts)
      end)

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

        -- Multi-selection: open each selected file in a new tab
        if multi and #multi > 0 then
          actions.close(prompt_bufnr)
          vim.schedule(function()
            for _, entry in ipairs(multi) do
              local file_path = entry.filename or entry.path
              if file_path then
                vim.cmd("tabedit " .. vim.fn.fnameescape(file_path))
                if entry.lnum then
                  pcall(vim.api.nvim_win_set_cursor, 0, { entry.lnum, math.max(0, (entry.col or 1) - 1) })
                end
              end
            end
          end)
          return
        end

        -- Non-file entry - use default action
        if not is_file_entry(selection) then
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

        -- Lua pattern-based file type detection (no vim.regex overhead)
        local function get_filename_hl(fname)
          if is_test_file(fname) then
            return "TelescopeTestFile"
          end
          -- Static/config files
          if is_static_file(fname) then
            return static_file_hl
          end
          -- Go files
          if fname:match "%.go$" then
            return "Function"
          end
          -- Doc files
          if is_doc_file(fname) then
            return doc_file_hl
          end
          return "TelescopeResultsIdentifier"
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

          local filename_hl = get_filename_hl(filename)
          local is_special = filename_hl == test_file_hl or filename_hl == doc_file_hl or filename_hl == static_file_hl

          -- Pre-compute lengths
          local indent_len = #tree_indent
          local icon_len = #icon
          local dir_len = #dir

          local display_str = tree_indent .. icon .. " " .. dir .. filename

          -- Build highlights array once
          local highlights = {}

          -- For test/doc files, apply the highlight across the entire row first
          if is_special then
            highlights[#highlights + 1] = { { 0, #display_str }, filename_hl }
          end

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

          if not is_special then
            highlights[#highlights + 1] = { { pos, #display_str }, filename_hl }
          end

          -- Return pre-computed display
          base_entry.display = function()
            return display_str, highlights
          end

          return base_entry
        end
      end

      local previewers = require "telescope.previewers"
      local ns_pathbar = vim.api.nvim_create_namespace "TelescopePathBarNS"
      local ns_grep_match = vim.api.nvim_create_namespace "TelescopeGrepMatchHL"

      -- Apply grep match highlights to a preview buffer
      local function apply_grep_match_highlights(bufnr, prompt_bufnr)
        if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then
          return
        end
        local picker = action_state.get_current_picker(prompt_bufnr)
        if not picker then
          return
        end
        local prompt = picker:_get_prompt()
        if not prompt or prompt == "" then
          return
        end

        vim.api.nvim_buf_clear_namespace(bufnr, ns_grep_match, 0, -1)

        local has_upper = prompt:find "%u"
        local search_pat = has_upper and prompt or prompt:lower()
        local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
        for lnum, line in ipairs(lines) do
          local search_line = has_upper and line or line:lower()
          local start = 1
          while true do
            local s, e = search_line:find(search_pat, start, true)
            if not s then
              break
            end
            pcall(vim.api.nvim_buf_set_extmark, bufnr, ns_grep_match, lnum - 1, s - 1, {
              end_col = e,
              hl_group = "TelescopePreviewMatch",
              priority = 300,
              hl_mode = "combine",
            })
            start = e + 1
          end
        end
      end

      -- Factory: creates an LSP previewer that highlights a given symbol in the preview
      local function make_lsp_symbol_previewer(symbol)
        return function(opts)
          local base = previewers.vim_buffer_qflist.new(opts)
          local orig_preview = base.preview
          local orig_teardown = base.teardown
          local last_attached_buf = nil

          base.preview = function(self, entry, status)
            local ret = orig_preview(self, entry, status)

            if not symbol or symbol == "" then
              return ret
            end

            vim.schedule(function()
              local winid = status and status.preview_win
              if not winid or not vim.api.nvim_win_is_valid(winid) then
                return
              end
              local bufnr = vim.api.nvim_win_get_buf(winid)
              if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then
                return
              end

              local function apply_symbol_highlights(buf)
                if not buf or not vim.api.nvim_buf_is_valid(buf) then
                  return
                end
                vim.api.nvim_buf_clear_namespace(buf, ns_grep_match, 0, -1)
                local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
                for lnum, line in ipairs(lines) do
                  local start = 1
                  while true do
                    local s, e = line:find(symbol, start, true)
                    if not s then
                      break
                    end
                    pcall(vim.api.nvim_buf_set_extmark, buf, ns_grep_match, lnum - 1, s - 1, {
                      end_col = e,
                      hl_group = "TelescopePreviewMatch",
                      priority = 300,
                      hl_mode = "combine",
                    })
                    start = e + 1
                  end
                end
              end

              local line_count = vim.api.nvim_buf_line_count(bufnr)
              if line_count > 1 or (line_count == 1 and vim.api.nvim_buf_get_lines(bufnr, 0, 1, false)[1] ~= "") then
                apply_symbol_highlights(bufnr)
              end

              if last_attached_buf ~= bufnr then
                last_attached_buf = bufnr
                local applied = false
                vim.api.nvim_buf_attach(bufnr, false, {
                  on_lines = function(_, attached_buf)
                    if applied then
                      return true
                    end
                    if not vim.api.nvim_buf_is_valid(attached_buf) then
                      return true
                    end
                    applied = true
                    vim.schedule(function()
                      apply_symbol_highlights(attached_buf)
                    end)
                    return true
                  end,
                })
              end

              vim.defer_fn(function()
                if vim.api.nvim_buf_is_valid(bufnr) then
                  apply_symbol_highlights(bufnr)
                end
              end, 80)
            end)

            return ret
          end

          base.teardown = function(self)
            last_attached_buf = nil
            local bufnr2 = self.state and self.state.bufnr
            if bufnr2 and vim.api.nvim_buf_is_valid(bufnr2) then
              pcall(vim.api.nvim_buf_clear_namespace, bufnr2, ns_grep_match, 0, -1)
            end
            if orig_teardown then
              return orig_teardown(self)
            end
          end

          return base
        end
      end

      -- Custom grep previewer that highlights all matches of the search pattern
      local function grep_previewer_with_match_hl(opts)
        local base = previewers.vim_buffer_vimgrep.new(opts)
        local orig_preview = base.preview
        local orig_teardown = base.teardown
        local last_attached_buf = nil

        base.preview = function(self, entry, status)
          local ret = orig_preview(self, entry, status)

          vim.schedule(function()
            local winid = status and status.preview_win
            if not winid or not vim.api.nvim_win_is_valid(winid) then
              return
            end
            local bufnr = vim.api.nvim_win_get_buf(winid)
            if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then
              return
            end

            -- Try immediately in case content is already loaded
            local line_count = vim.api.nvim_buf_line_count(bufnr)
            if line_count > 1 or (line_count == 1 and vim.api.nvim_buf_get_lines(bufnr, 0, 1, false)[1] ~= "") then
              apply_grep_match_highlights(bufnr, status.prompt_bufnr)
            end

            -- Attach to buffer to catch async content loading
            if last_attached_buf ~= bufnr then
              last_attached_buf = bufnr
              local applied = false
              vim.api.nvim_buf_attach(bufnr, false, {
                on_lines = function(_, attached_buf)
                  if applied then
                    return true -- detach
                  end
                  if not vim.api.nvim_buf_is_valid(attached_buf) then
                    return true -- detach
                  end
                  applied = true
                  vim.schedule(function()
                    apply_grep_match_highlights(attached_buf, status.prompt_bufnr)
                  end)
                  return true -- detach after first application
                end,
              })
            end

            -- Fallback: re-apply after a short delay to catch treesitter redraws
            vim.defer_fn(function()
              if vim.api.nvim_buf_is_valid(bufnr) then
                apply_grep_match_highlights(bufnr, status.prompt_bufnr)
              end
            end, 80)
          end)

          return ret
        end

        base.teardown = function(self)
          last_attached_buf = nil
          local bufnr2 = self.state and self.state.bufnr
          if bufnr2 and vim.api.nvim_buf_is_valid(bufnr2) then
            pcall(vim.api.nvim_buf_clear_namespace, bufnr2, ns_grep_match, 0, -1)
          end
          if orig_teardown then
            return orig_teardown(self)
          end
        end

        return base
      end

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
          prompt_prefix = "   ",
          selection_caret = "  ",
          multi_icon = "󰄬 ",
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
              ["<kEnter>"] = smart_open_file,
            },
            i = {
              ["<Esc>"] = actions.close,
              ["<CR>"] = smart_open_file,
              ["<kEnter>"] = smart_open_file,
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
            previewer = with_preview_winbar(grep_previewer_with_match_hl) {},
            attach_mappings = function(prompt_bufnr, map)
              map("i", "<C-h>", toggle_no_ignore)
              map("n", "<C-h>", toggle_no_ignore)
              return true
            end,
            layout_config = {
              preview_width = 0.7, -- Slightly smaller for grep to see more results
            },
          },
          find_files = {
            entry_maker = make_tree_entry_for_files(),
            hidden = true,
            no_ignore = false,
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

      -- Expose for use in LSP keymaps
      _G._telescope_make_lsp_symbol_previewer = make_lsp_symbol_previewer
      _G._telescope_with_preview_winbar = with_preview_winbar

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
            map("i", "<kEnter>", confirm_selection)
            map("n", "<kEnter>", confirm_selection)
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
