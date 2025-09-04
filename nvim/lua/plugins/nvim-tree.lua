return {
  {
    "nvim-tree/nvim-tree.lua",
    cmd = { "NvimTreeToggle", "NvimTreeFocus" },
    dependencies = {
      "nvim-tree/nvim-web-devicons", -- Enhanced file icons
    },
    config = function()
      -- Enhanced colors for nvim-tree
      vim.api.nvim_set_hl(0, "NvimTreeFolderIcon", { fg = "#61afef" })
      vim.api.nvim_set_hl(0, "NvimTreeFolderName", { fg = "#61afef" })
      vim.api.nvim_set_hl(0, "NvimTreeOpenedFolderName", { fg = "#61afef", bold = true })
      vim.api.nvim_set_hl(0, "NvimTreeEmptyFolderName", { fg = "#61afef" })
      vim.api.nvim_set_hl(0, "NvimTreeIndentMarker", { fg = "#3b4261" })
      vim.api.nvim_set_hl(0, "NvimTreeWinSeparator", { fg = "#3b4261" })
      vim.api.nvim_set_hl(0, "NvimTreeRootFolder", { fg = "#e06c75", bold = true })
      vim.api.nvim_set_hl(0, "NvimTreeSymlink", { fg = "#56b6c2" })
      vim.api.nvim_set_hl(0, "NvimTreeExecFile", { fg = "#98c379" })
      vim.api.nvim_set_hl(0, "NvimTreeImageFile", { fg = "#d19a66" })
      vim.api.nvim_set_hl(0, "NvimTreeSpecialFile", { fg = "#e5c07b" })
      vim.api.nvim_set_hl(0, "NvimTreeNormal", { bg = "#21252b" })
      vim.api.nvim_set_hl(0, "NvimTreeCursorLine", { bg = "#2c313c" })

      -- Git status colors
      vim.api.nvim_set_hl(0, "NvimTreeGitDirty", { fg = "#e06c75" })
      vim.api.nvim_set_hl(0, "NvimTreeGitStaged", { fg = "#98c379" })
      vim.api.nvim_set_hl(0, "NvimTreeGitMerge", { fg = "#d19a66" })
      vim.api.nvim_set_hl(0, "NvimTreeGitRenamed", { fg = "#d19a66" })
      vim.api.nvim_set_hl(0, "NvimTreeGitNew", { fg = "#98c379" })
      vim.api.nvim_set_hl(0, "NvimTreeGitDeleted", { fg = "#e06c75" })
      vim.api.nvim_set_hl(0, "NvimTreeGitIgnored", { fg = "#5c6370" })

      vim.api.nvim_set_hl(0, "NvimTreeTestFile", { bg = "#252c25", fg = "#76946a" })

      vim.api.nvim_create_autocmd({ "BufEnter", "BufWritePost" }, {
        pattern = "*",
        callback = function()
          if vim.bo.filetype == "NvimTree" then
            vim.defer_fn(function()
              -- Clear any existing matches
              vim.fn.clearmatches()

              -- Highlight test files line by line
              local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
              for i, line in ipairs(lines) do
                if line:match "_test%.go" or line:match "test%.go" then
                  vim.fn.matchadd("NvimTreeTestFile", "\\%" .. i .. "l.*", 10)
                end
              end
            end, 50)
          end
        end,
      })

      local api = require "nvim-tree.api"

      local function get_git_root(cwd)
        cwd = cwd or vim.fn.getcwd()
        if vim.fn.executable "git" ~= 1 then
          return cwd
        end
        local out = vim.fn.systemlist { "git", "-C", cwd, "rev-parse", "--show-toplevel" }
        if vim.v.shell_error ~= 0 or not out[1] or out[1] == "" then
          return cwd
        end
        -- Use the path as returned by git, normalized to absolute
        return vim.fn.fnamemodify(out[1], ":p")
      end

      local function ensure_tree_open_and_focus()
        if not api.tree.is_visible() then
          api.tree.open()
        end
        api.tree.focus()
      end

      -- Build/cache module list: dir -> { path, version }
      local go_mod_cache = nil
      local function build_go_mod_cache()
        go_mod_cache = {}
        if vim.fn.executable "go" ~= 1 then
          return go_mod_cache
        end
        -- Faster, parse-friendly output
        local lines = vim.fn.systemlist { "go", "list", "-m", "-f", "{{.Dir}}\t{{.Path}}\t{{.Version}}", "all" }
        for _, line in ipairs(lines or {}) do
          local dir, path, ver = line:match "^([^\t]+)\t([^\t]+)\t([^\t]*)$"
          if dir and path then
            go_mod_cache[vim.fn.fnamemodify(dir, ":p:h")] = {
              path = path,
              version = ver ~= "" and ver or "workspace",
            }
          end
        end
        return go_mod_cache
      end

      local function ensure_go_mod_cache()
        if not go_mod_cache then
          build_go_mod_cache()
        end
        return go_mod_cache
      end

      -- Find the module root (Dir) for a given absolute file/dir path
      local function find_module_dir_for_path(abs_path)
        abs_path = vim.fn.fnamemodify(abs_path, ":p:h")
        local cache = ensure_go_mod_cache()
        if not cache then
          return nil
        end
        local probe = abs_path
        while probe and probe ~= "/" and probe ~= "" do
          if cache[probe] then
            return probe
          end
          local parent = vim.fn.fnamemodify(probe, ":h")
          if parent == probe then
            break
          end
          probe = parent
        end
        return nil
      end

      local function get_module_info_for_dir(dir)
        local cache = ensure_go_mod_cache()
        return cache and cache[vim.fn.fnamemodify(dir, ":p:h")] or nil
      end

      local function get_gomodcache()
        if vim.fn.executable "go" ~= 1 then
          return nil
        end
        local out = vim.fn.systemlist { "go", "env", "GOMODCACHE" }
        if vim.v.shell_error ~= 0 or not out[1] or out[1] == "" then
          return nil
        end
        return vim.fn.fnamemodify(out[1], ":p")
      end
      local gomodcache = get_gomodcache()

      local function is_dep_dir(path)
        path = vim.fn.fnamemodify(path or "", ":p")
        if not path or path == "" then
          return false
        end
        if gomodcache and path:sub(1, #gomodcache) == gomodcache then
          return true
        end
        -- heuristic fallback (GOPATH/pkg/mod)
        if path:find "/pkg/mod/" then
          return true
        end
        return false
      end

      -- Commands:
      -- :GoDeps — pick a dependency and root nvim-tree there
      vim.api.nvim_create_user_command("GoDeps", function()
        local cache = ensure_go_mod_cache()
        if not cache or vim.tbl_isempty(cache) then
          vim.notify("No Go modules found (run inside a Go module and ensure `go` is installed)", vim.log.levels.WARN)
          return
        end
        local items = {}
        for dir, info in pairs(cache) do
          -- Skip the main module if you prefer only external deps; keep it for completeness
          table.insert(items, { label = (info.path .. "@" .. info.version), dir = dir })
        end
        table.sort(items, function(a, b)
          return a.label < b.label
        end)

        vim.ui.select(items, {
          prompt = "Go modules",
          format_item = function(it)
            return it.label
          end,
        }, function(choice)
          if not choice then
            return
          end
          if not is_dep_dir(current_tree_root) then
            last_project_root = current_tree_root
          end
          set_tree_root(choice.dir)
          ensure_tree_open_and_focus()
        end)
      end, {})

      -- :GoDepsHere — root nvim-tree at the dependency of the current buffer
      vim.api.nvim_create_user_command("GoDepsHere", function()
        local buf = vim.api.nvim_get_current_buf()
        local path = vim.api.nvim_buf_get_name(buf)
        if path == "" then
          vim.notify("Current buffer has no file path", vim.log.levels.WARN)
          return
        end
        local mod_dir = find_module_dir_for_path(path)
        if not mod_dir then
          vim.notify("No Go module found for current file", vim.log.levels.WARN)
          return
        end
        api.tree.change_root(mod_dir)
        ensure_tree_open_and_focus()
      end, {})

      -- Optional: refresh the module cache
      vim.api.nvim_create_user_command("GoDepsReload", function()
        go_mod_cache = nil
        build_go_mod_cache()
        vim.notify("Go module cache reloaded", vim.log.levels.INFO)
      end, {})

      -- Improve the root label to show module@version when rooted inside a dependency
      local function go_dep_root_label(path)
        local dir = find_module_dir_for_path(path)
        if not dir then
          return nil
        end
        local info = get_module_info_for_dir(dir)
        if not info then
          return nil
        end
        local short = info.path:match "([^/]+)$" or info.path
        return "📦 " .. short .. "@" .. info.version .. " (" .. info.path .. ")"
      end

      -- Track roots so we can reliably restore
      local current_tree_root = vim.fn.fnamemodify(vim.fn.getcwd(), ":p")
      local last_project_root = get_git_root(current_tree_root)

      local function set_tree_root(new_root)
        new_root = vim.fn.fnamemodify(new_root, ":p")
        current_tree_root = new_root
        api.tree.change_root(new_root)
      end

      require("nvim-tree").setup {
        filters = {
          dotfiles = false,
          git_clean = false,
          no_buffer = false,
          custom = { "^.git$" },
        },
        actions = {
          open_file = {
            window_picker = {
              enable = false,
            },
            quit_on_open = false,
          },
        },
        disable_netrw = true,
        hijack_cursor = true,
        view = {
          width = 30,
          preserve_window_proportions = true,
          adaptive_size = true,
        },
        renderer = {
          root_folder_label = function(path)
            local dep_label = go_dep_root_label(path)
            if dep_label then
              return dep_label
            end
            -- Your existing project-root label for go.mod projects
            local go_mod = path .. "/go.mod"
            if vim.fn.filereadable(go_mod) == 1 then
              local lines = vim.fn.readfile(go_mod)
              for _, line in ipairs(lines) do
                local module = line:match "^module%s+(.+)"
                if module then
                  local short_name = module:match "([^/]+)$" or module
                  return "🐹 " .. short_name .. " (" .. module .. ")"
                end
              end
            end
            return "📁 " .. vim.fn.fnamemodify(path, ":t")
          end,

          highlight_git = true,
          indent_markers = { enable = true },
          icons = {
            web_devicons = {
              file = {
                enable = true,
                color = true,
              },
              folder = {
                enable = true,
                color = true,
              },
            },
            git_placement = "before",
            modified_placement = "after",
            diagnostics_placement = "signcolumn",
            bookmarks_placement = "signcolumn",
            show = {
              file = true,
              folder = true,
              folder_arrow = true,
              git = true,
              modified = true,
              diagnostics = true,
              bookmarks = true,
            },
            glyphs = {
              default = "󰈚",
              folder = {
                default = "",
                empty = "",
                empty_open = "",
                open = "",
                symlink = "",
              },
              git = {
                unmerged = "",
              },
            },
          },
        },

        update_focused_file = {
          enable = true,
          update_root = {
            enable = false,
          },
        },

        tab = {
          sync = {
            open = false, -- Don't open nvim-tree in new tabs
            close = false,
          },
        },
        on_attach = function(bufnr)
          local api = require "nvim-tree.api"

          -- Show full name in command line when cursor moves
          vim.api.nvim_create_autocmd("CursorMoved", {
            buffer = bufnr,
            callback = function()
              local node = api.tree.get_node_under_cursor()
              if node then
                vim.cmd('echo "' .. node.absolute_path:gsub('"', '\\"') .. '"')
              end
            end,
          })

          -- Clear the command line when leaving nvim-tree
          vim.api.nvim_create_autocmd("BufLeave", {
            buffer = bufnr,
            callback = function()
              vim.cmd 'echo ""'
            end,
          })

          -- Default mappings
          api.config.mappings.default_on_attach(bufnr)

          vim.keymap.set("n", "<C-n>", api.fs.create, { buffer = bufnr, desc = "Create new file" })
          vim.keymap.set("n", "<F2>", api.fs.rename, { buffer = bufnr, desc = "Rename file" })
          vim.keymap.set("n", "<Delete>", api.fs.remove, { buffer = bufnr, desc = "Delete file" })
          -- Copy paths
          vim.keymap.set("n", "y", function()
            local node = api.tree.get_node_under_cursor()
            if node then
              local absolute_path = node.absolute_path
              vim.fn.setreg("+", absolute_path) -- Copy to system clipboard
              vim.fn.setreg('"', absolute_path) -- Copy to default register
              vim.notify("Copied: " .. absolute_path, vim.log.levels.INFO)
            end
          end, { buffer = bufnr, desc = "Copy absolute path" })

          vim.keymap.set("n", "<C-y>", function()
            local node = api.tree.get_node_under_cursor()
            if node then
              local relative_path = vim.fn.fnamemodify(node.absolute_path, ":.")
              vim.fn.setreg("+", relative_path) -- Copy to system clipboard
              vim.fn.setreg('"', relative_path) -- Copy to default register
              vim.notify("Copied relative: " .. relative_path, vim.log.levels.INFO)
            end
          end, { buffer = bufnr, desc = "Copy relative path" })
        end,
      }
    end,
  },
}
