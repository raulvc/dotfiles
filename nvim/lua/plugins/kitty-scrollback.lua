local is_kitty_scrollback = vim.env.KITTY_SCROLLBACK_NVIM ~= nil

local ksb_prev_winopts = nil
local ksb_pending = nil

local function ksb_paste_windows()
  local paste_win, footer_win
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    local name = vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(win))
    if name:match("ksb_pastebuf$") then
      paste_win = win
    elseif name:match("ksb_footerbuf$") then
      footer_win = win
    end
  end
  return paste_win, footer_win
end

local function ksb_resize_paste_window(step)
  local paste_win, footer_win = ksb_paste_windows()
  if not paste_win then
    return
  end
  local cfg = vim.api.nvim_win_get_config(paste_win)
  if cfg.relative ~= "editor" then
    return
  end
  local max_h = footer_win and (vim.o.lines - 5) or (vim.o.lines - 2)
  local bottom = cfg.row + cfg.height
  local new_h = math.max(1, math.min(max_h, cfg.height + step))
  if new_h == cfg.height then
    return
  end
  cfg.height = new_h
  cfg.row = math.max(0, bottom - new_h)
  vim.api.nvim_win_set_config(paste_win, cfg)
  if footer_win then
    local fcfg = vim.api.nvim_win_get_config(footer_win)
    fcfg.row = new_h + 1
    fcfg.win = paste_win
    vim.api.nvim_win_set_config(footer_win, fcfg)
  end
end

local function ksb_maximize_paste_window()
  local paste_win, footer_win = ksb_paste_windows()
  if not paste_win then
    return
  end
  local cfg = vim.api.nvim_win_get_config(paste_win)
  if cfg.relative ~= "editor" then
    return
  end
  local max_h = footer_win and (vim.o.lines - 5) or (vim.o.lines - 2)
  if cfg.height >= max_h then
    if ksb_prev_winopts then
      local prev = ksb_prev_winopts
      ksb_prev_winopts = nil
      cfg.height = prev.height
      cfg.row = prev.row
      vim.api.nvim_win_set_config(paste_win, cfg)
      if footer_win then
        local fcfg = vim.api.nvim_win_get_config(footer_win)
        fcfg.row = prev.height + 1
        fcfg.win = paste_win
        vim.api.nvim_win_set_config(footer_win, fcfg)
      end
    end
    return
  end
  local bottom = cfg.row + cfg.height
  ksb_prev_winopts = { row = cfg.row, height = cfg.height }
  cfg.height = max_h
  cfg.row = math.max(0, bottom - max_h)
  vim.api.nvim_win_set_config(paste_win, cfg)
  if footer_win then
    local fcfg = vim.api.nvim_win_get_config(footer_win)
    fcfg.row = max_h + 1
    fcfg.win = paste_win
    vim.api.nvim_win_set_config(footer_win, fcfg)
  end
end

local function ksb_resize_step(default)
  return vim.v.count > 0 and vim.v.count or default
end

local function ksb_on_paste_window_ready(paste_window_data)
  local paste_buf = paste_window_data.paste_window.bufid
  for _, mode in ipairs({ "n", "i" }) do
    vim.keymap.set(mode, "<M-u>", function()
      ksb_resize_paste_window(ksb_resize_step(3))
    end, { buffer = paste_buf, silent = true })
    vim.keymap.set(mode, "<M-d>", function()
      ksb_resize_paste_window(-ksb_resize_step(3))
    end, { buffer = paste_buf, silent = true })
    vim.keymap.set(mode, "<M-e>", ksb_maximize_paste_window, { buffer = paste_buf, silent = true })
  end

  if ksb_pending then
    local pending = ksb_pending
    ksb_pending = nil
    if pending.maximize then
      ksb_maximize_paste_window()
    else
      ksb_resize_paste_window(pending.step)
    end
  end
end

local function ksb_set_scrollback_maps(buf)
  vim.keymap.set("n", "<M-u>", function()
    if ksb_paste_windows() then
      ksb_resize_paste_window(ksb_resize_step(3))
    else
      ksb_pending = { step = ksb_resize_step(3) }
      vim.api.nvim_feedkeys("i", "n", false)
    end
  end, { buffer = buf, silent = true })
  vim.keymap.set("n", "<M-d>", function()
    if ksb_paste_windows() then
      ksb_resize_paste_window(-ksb_resize_step(3))
    end
  end, { buffer = buf, silent = true })
  vim.keymap.set("n", "<M-e>", function()
    if ksb_paste_windows() then
      ksb_maximize_paste_window()
    else
      ksb_pending = { maximize = true }
      vim.api.nvim_feedkeys("i", "n", false)
    end
  end, { buffer = buf, silent = true })
end

return {
  { "rmagatti/auto-session", enabled = not is_kitty_scrollback },
  { "milanglacier/minuet-ai.nvim", enabled = not is_kitty_scrollback },
  { "saghen/blink.cmp", enabled = not is_kitty_scrollback },
  { "xzbdmw/colorful-menu.nvim", enabled = not is_kitty_scrollback },

  -- Disable git-related plugins
  { "gitsigns.nvim", enabled = not is_kitty_scrollback },
  { "git-blame.nvim", enabled = not is_kitty_scrollback },
  { "diffview.nvim", enabled = not is_kitty_scrollback },
  { "gitlineage.nvim", enabled = not is_kitty_scrollback },

  -- Disable treesitter parsing
  { "tree-sitter-manager.nvim", enabled = not is_kitty_scrollback },
  { "nvim-treesitter-context", enabled = not is_kitty_scrollback },
  { "nvim-treesitter-textobjects", enabled = not is_kitty_scrollback },

  -- Disable LSP and linting
  { "nvim-lspconfig", enabled = not is_kitty_scrollback },
  { "nvim-lint", enabled = not is_kitty_scrollback },
  { "fidget.nvim", enabled = not is_kitty_scrollback },

  -- Disable UI enhancements
  { "noice.nvim", enabled = not is_kitty_scrollback },

  -- Disable DAP (debugger) plugins
  { "nvim-dap", enabled = not is_kitty_scrollback },
  { "nvim-dap-view", enabled = not is_kitty_scrollback },
  { "nvim-dap-go", enabled = not is_kitty_scrollback },
  { "mason-nvim-dap.nvim", enabled = not is_kitty_scrollback },

  -- Disable neotest plugins
  { "neotest", enabled = not is_kitty_scrollback },
  { "neotest-golang", enabled = not is_kitty_scrollback },
  { "neotest-jest", enabled = not is_kitty_scrollback },
  { "neotest-plenary", enabled = not is_kitty_scrollback },
  { "neotest-python", enabled = not is_kitty_scrollback },
  { "neotest-rust", enabled = not is_kitty_scrollback },
  { "neotest-vim-test", enabled = not is_kitty_scrollback },

  {
    "mikesmithgh/kitty-scrollback.nvim",
    enabled = true,
    lazy = true,
    cmd = { "KittyScrollbackGenerateKittens", "KittyScrollbackCheckHealth" },
    event = { "User KittyScrollbackLaunch" },
    config = function()
      vim.api.nvim_create_autocmd("FileType", {
        pattern = "kitty-scrollback",
        group = vim.api.nvim_create_augroup("KittyScrollbackPasteWindowResize", { clear = true }),
        callback = function(args)
          ksb_set_scrollback_maps(args.buf)
        end,
      })

      require("kitty-scrollback").setup {
        {
          -- Default configuration (edit mode - no auto-search)
          paste_window = {
            yank_register_enabled = true,
            yank_register = "+",
          },
          status_window = {
            enabled = true,
            style_simple = false,
          },
          callbacks = {
            after_paste_window_ready = ksb_on_paste_window_ready,
          },
          keymaps_enabled = true,
          restore_options = true,
          highlight_overrides = {
            KittyScrollbackNvimStatusWinNormal = { link = "Normal" },
            KittyScrollbackNvimPasteWinNormal = { link = "Normal" },
          },
        },

        -- Configuration for search mode
        ksb_builtin_search = function()
          return {
            paste_window = {
              yank_register_enabled = true,
              yank_register = "+",
            },
            status_window = {
              enabled = true,
              style_simple = false,
            },
            callbacks = {
              after_paste_window_ready = ksb_on_paste_window_ready,
              after_ready = function()
                vim.schedule(function()
                  vim.api.nvim_feedkeys("/", "n", false)
                end)
              end,
            },
          }
        end,

        -- Configuration for fzf search
        ksb_builtin_last_cmd_output = function()
          return {
            paste_window = {
              yank_register_enabled = false,
            },
            callbacks = {
              after_paste_window_ready = ksb_on_paste_window_ready,
              after_ready = function()
                vim.schedule(function()
                  vim.api.nvim_feedkeys("/", "n", false)
                end)
              end,
            },
          }
        end,
      }
    end,
  },
}
