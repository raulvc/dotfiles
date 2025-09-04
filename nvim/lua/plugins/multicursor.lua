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
          -- Removed vim.cmd "startinsert" - stay in normal mode

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

          vim.notify(string.format("Added cursors to %d matches", match_count))
        else
          vim.notify("No matches found", vim.log.levels.INFO)
        end
      else
        vim.notify("No search pattern", vim.log.levels.INFO)
      end
    end, { desc = "Place cursors on all matches of last search" })

    vim.keymap.set("x", "<C-S-l>", mc.addCursorOperator)

    local hl = vim.api.nvim_set_hl
    hl(0, "MultiCursorCursor", { reverse = true })
    hl(0, "MultiCursorVisual", { link = "Visual" })
    hl(0, "MultiCursorSign", { link = "SignColumn" })
    hl(0, "MultiCursorMatchPreview", { link = "Search" })
    hl(0, "MultiCursorDisabledCursor", { reverse = true })
    hl(0, "MultiCursorDisabledVisual", { link = "Visual" })
    hl(0, "MultiCursorDisabledSign", { link = "SignColumn" })
  end,
}
