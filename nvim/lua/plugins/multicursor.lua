return {
  "jake-stewart/multicursor.nvim",
  branch = "1.0",
  lazy = false,
  config = function()
    local mc = require "multicursor-nvim"

    mc.setup {
      DEBUG_MODE = false,
      updatetime = 100,
    }

    -- Distributed paste: paste clipboard lines across cursors 1:1
    local function get_system_clipboard()
      -- Try reading directly from OS clipboard tools
      local ok, result
      -- Wayland
      ok, result = pcall(vim.fn.system, "wl-paste --no-newline 2>/dev/null")
      if ok and vim.v.shell_error == 0 and result and result ~= "" then
        return result
      end
      -- X11
      ok, result = pcall(vim.fn.system, "xclip -selection clipboard -o 2>/dev/null")
      if ok and vim.v.shell_error == 0 and result and result ~= "" then
        return result
      end
      ok, result = pcall(vim.fn.system, "xsel --clipboard --output 2>/dev/null")
      if ok and vim.v.shell_error == 0 and result and result ~= "" then
        return result
      end
      -- Fallback to Neovim registers
      local reg = vim.fn.getreg "+"
      if reg and reg ~= "" then
        return reg
      end
      return vim.fn.getreg '"'
    end

    local function distributed_paste(paste_after)
      local clipboard = get_system_clipboard()
      if not clipboard or clipboard == "" then
        return
      end

      local clip_lines = vim.split(clipboard, "\n", { plain = true })
      -- Remove trailing empty line (vim registers often have one)
      if clip_lines[#clip_lines] == "" then
        table.remove(clip_lines)
      end

      local cursor_count = mc.numCursors()

      if #clip_lines == cursor_count then
        -- Distribute one line per cursor
        local i = 0
        mc.action(function()
          i = i + 1
          local line = clip_lines[i] or ""
          vim.fn.setreg('"', line, "c") -- "c" = characterwise
          if paste_after then
            vim.cmd 'normal! ""p'
          else
            vim.cmd 'normal! ""P'
          end
        end)
      else
        -- Line count doesn't match cursor count, paste full clipboard at each cursor
        mc.action(function()
          vim.fn.setreg('"', clipboard, "c")
          if paste_after then
            vim.cmd 'normal! ""p'
          else
            vim.cmd 'normal! ""P'
          end
        end)
      end
    end

    vim.keymap.set("n", "p", function()
      if mc.hasCursors() then
        distributed_paste(true)
      else
        vim.cmd 'normal! "+p'
      end
    end, { desc = "Smart paste (distributed in multicursor)" })

    vim.keymap.set("n", "P", function()
      if mc.hasCursors() then
        distributed_paste(false)
      else
        vim.cmd 'normal! "+P'
      end
    end, { desc = "Smart Paste before (distributed in multicursor)" })

    -- Clone caret mappings
    vim.keymap.set({ "n", "v" }, "<M-S-Up>", function()
      mc.lineAddCursor(-1)
    end, { desc = "Clone caret above" })

    vim.keymap.set({ "n", "v" }, "<M-S-Down>", function()
      mc.lineAddCursor(1)
    end, { desc = "Clone caret below" })

    -- JetBrains-style workflow
    vim.keymap.set("c", "<M-CR>", function()
      local search_term = vim.fn.getcmdline()

      if search_term == "" then
        return
      end

      -- Exit command mode and execute the search
      vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<CR>", true, false, true), "n", false)

      -- Small delay to ensure search is processed
      vim.defer_fn(function()
        -- Use the search register to get the processed pattern
        local processed_pattern = vim.fn.getreg "/"

        -- Count matches first
        local match_count = vim.fn.searchcount().total or 0

        if match_count > 0 then
          -- Use searchAllAddCursors with the processed pattern
          mc.searchAllAddCursors(processed_pattern)
          -- Select the match (Sublime-style) using pattern length
          local plen = #processed_pattern
          if plen > 1 then
            mc.action(function(ctx)
              ctx:forEachCursor(function(cursor)
                cursor:feedkeys("v" .. (plen - 1) .. "l", { remap = false })
              end)
            end)
          end

          vim.notify(string.format("Added cursors to %d matches", match_count))
        else
          vim.notify("No matches found", vim.log.levels.INFO)
        end
      end, 10)
    end, { desc = "Search and place cursors on all matches" })

    -- Normal mode Alt+Enter for current search pattern
    vim.keymap.set("n", "<M-CR>", function()
      local search_reg = vim.fn.getreg "/"
      if search_reg and search_reg ~= "" then
        local match_count = vim.fn.searchcount().total or 0

        if match_count > 0 then
          -- Use searchAllAddCursors with the current search pattern
          mc.searchAllAddCursors(search_reg)
          -- Select the match (Sublime-style) using pattern length
          local plen = #search_reg
          if plen > 1 then
            mc.action(function(ctx)
              ctx:forEachCursor(function(cursor)
                cursor:feedkeys("v" .. (plen - 1) .. "l", { remap = false })
              end)
            end)
          end

          vim.notify(string.format("Added cursors to %d matches", match_count))
        else
          vim.notify("No matches found", vim.log.levels.INFO)
        end
      else
        vim.notify("No search pattern", vim.log.levels.INFO)
      end
    end, { desc = "Place cursors on all matches of last search" })

    vim.keymap.set("v", "<M-CR>", function()
      mc.matchAllAddCursors()
    end, { desc = "Add cursors to all matches of selection" })

    vim.keymap.set("x", "<C-S-l>", function()
      mc.addCursorOperator()
      vim.schedule(function()
        mc.action(function(ctx)
          ctx:forEachCursor(function(cursor)
            cursor:feedkeys("$", { remap = false })
          end)
        end)
      end)
    end, { desc = "Add cursors at end of lines (Sublime-style)" })

    -- Sync multicursor yanks to system clipboard (Sublime-style)
    vim.keymap.set({ "n", "v" }, "y", function()
      if not mc.hasCursors() then
        local keys = vim.api.nvim_replace_termcodes("y", true, false, true)
        vim.api.nvim_feedkeys(keys, "n", false)
        return
      end
      mc.action(function(ctx)
        local lines = {}
        ctx:forEachCursor(function(cursor)
          cursor:feedkeys("y", { remap = false })
          table.insert(lines, vim.fn.getreg '"')
        end)
        local combined = table.concat(lines, "\n")
        vim.fn.setreg('"', combined)
        vim.fn.setreg("+", combined)
      end)
    end, { desc = "Yank with multicursor clipboard sync" })

    vim.keymap.set("n", "Y", function()
      if not mc.hasCursors() then
        local keys = vim.api.nvim_replace_termcodes("Y", true, false, true)
        vim.api.nvim_feedkeys(keys, "n", false)
        return
      end
      mc.action(function(ctx)
        local lines = {}
        ctx:forEachCursor(function(cursor)
          cursor:feedkeys("Y", { remap = false })
          table.insert(lines, vim.fn.getreg '"')
        end)
        local combined = table.concat(lines, "\n")
        vim.fn.setreg('"', combined)
        vim.fn.setreg("+", combined)
      end)
    end, { desc = "Yank line with multicursor clipboard sync" })

    -- Sublime-style paste: distribute lines across cursors when counts match
    local function mc_paste(paste_key)
      return function()
        if not mc.hasCursors() then
          require("smart-paste").paste { key = paste_key }
          return
        end

        local content = vim.fn.getreg "+"
        if not content or content == "" then
          content = vim.fn.getreg '"'
        end
        if not content or content == "" then
          return
        end

        -- Split content into lines, remove trailing empty line if present
        local lines = vim.split(content, "\n", { plain = true })
        if lines[#lines] == "" then
          table.remove(lines)
        end

        -- Count cursors
        local cursor_count = 0
        mc.action(function(ctx)
          ctx:forEachCursor(function()
            cursor_count = cursor_count + 1
          end)
        end)

        if #lines == cursor_count and cursor_count > 1 then
          -- Distribute one line per cursor
          mc.action(function(ctx)
            local i = 0
            ctx:forEachCursor(function(cursor)
              i = i + 1
              vim.fn.setreg('"', lines[i])
              cursor:feedkeys(paste_key, { remap = false })
            end)
          end)
          -- Restore full content to registers
          vim.fn.setreg('"', content)
          vim.fn.setreg("+", content)
        else
          -- Normal paste across all cursors
          mc.action(function(ctx)
            ctx:forEachCursor(function(cursor)
              cursor:feedkeys(paste_key, { remap = false })
            end)
          end)
        end
      end
    end

    vim.keymap.set({ "n", "v" }, "p", mc_paste "p", { desc = "Paste (Sublime-style multicursor)" })
    vim.keymap.set({ "n", "v" }, "P", mc_paste "P", { desc = "Paste before (Sublime-style multicursor)" })

    local hl = vim.api.nvim_set_hl
    hl(0, "MultiCursorCursor", { link = "Cursor" })
    hl(0, "MultiCursorVisual", { link = "Visual" })
    hl(0, "MultiCursorSign", { fg = "#50fa7b", bold = true })
    hl(0, "MultiCursorMatchPreview", { link = "IncSearch" })
    hl(0, "MultiCursorDisabledCursor", { link = "Visual" })
    hl(0, "MultiCursorDisabledVisual", { bg = "#44475a" })
    hl(0, "MultiCursorDisabledSign", { link = "NonText" })
  end,
}
