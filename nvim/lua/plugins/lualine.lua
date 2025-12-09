return {
  {
    "nvim-lualine/lualine.nvim",
    lazy = false,
    dependencies = { "nvim-tree/nvim-web-devicons" },
    config = function()
      -- Custom component for visual selection
      local function visual_selection()
        local mode = vim.fn.mode()
        -- Check if we're in visual mode (v, V, or Ctrl-V)
        if mode:match "[vV\22]" then
          local start_line = vim.fn.line "v"
          local end_line = vim.fn.line "."
          local lines = math.abs(end_line - start_line) + 1

          -- For visual block mode, also show columns
          if mode == "\22" then -- Ctrl-V (visual block)
            local start_col = vim.fn.col "v"
            local end_col = vim.fn.col "."
            local cols = math.abs(end_col - start_col) + 1
            return string.format("%d×%d", lines, cols)
          elseif mode == "V" then -- Line visual mode
            return string.format("%dL", lines)
          else -- Character visual mode
            local start_pos = vim.fn.getpos "v"
            local end_pos = vim.fn.getpos "."
            local chars = 0

            if start_line == end_line then
              chars = math.abs(end_pos[3] - start_pos[3]) + 1
            else
              -- Multi-line selection - count all characters
              local lines_text = vim.api.nvim_buf_get_text(
                0,
                math.min(start_line, end_line) - 1,
                math.min(start_pos[3], end_pos[3]) - 1,
                math.max(start_line, end_line) - 1,
                math.max(start_pos[3], end_pos[3]),
                {}
              )
              for _, line in ipairs(lines_text) do
                chars = chars + #line
              end
            end
            return string.format("%dL %dC", lines, chars)
          end
        end
        return ""
      end

      require("lualine").setup {
        options = {
          theme = "auto",
        },
        sections = {
          lualine_a = { "mode" },
          lualine_b = { "branch", "diff", "diagnostics" },
          lualine_c = { "filename" },
          lualine_x = { visual_selection, "encoding", "fileformat", "filetype" },
          lualine_y = { "progress" },
          lualine_z = { "location" },
        },
      }
    end,
  },
}
