-- Global re-entry guard to prevent double-formatting
-- (keyed by bufnr, cleared after formatting completes)
local _formatting_guard = {}

local options = {
  formatters_by_ft = {
    lua = { "stylua" },
    python = { "isort", "black", "autoflake", "docformatter" },
    rust = { "rustfmt" },
    go = { "gofumpt" },
    javascript = { "prettierd" },
    typescript = { "prettierd" },
    sh = { "shfmt" },
    bash = { "shfmt" },
    json = { "fixjson" },
    yaml = { "yamlfmt" },
    yml = { "yamlfmt" },
    dockerfile = { "hadolint" },
    proto = { "buf" },
    terraform = { "terraform_fmt" },
    tf = { "terraform_fmt" },
    hcl = { "terraform_fmt" },
    ruby = { "cookstyle" },
    java = { "google-java-format" },
    xml = { "xmlformat" },
    groovy = { "npm-groovy-lint" },
    kotlin = { "ktlint" },
  },

  formatters = {
    fixjson = {
      args = { "--indent", "2" },
    },
    yamlfmt = {
      args = { "-formatter", "indent=2,retain_line_breaks=true" },
    },
    black = {
      prepend_args = {
        "--line-length",
        "88",
        "--target-version",
        "py39",
        "--preview",
      },
    },
    isort = {
      prepend_args = {
        "--profile",
        "black",
        "--line-length",
        "88",
        "--multi-line",
        "3",
        "--trailing-comma",
      },
    },
    hadolint = {
      command = "hadolint",
      args = { "--no-color", "$FILENAME" },
    },
    buf = {
      command = "buf",
      args = { "format", "-w", "$FILENAME" },
    },
    terraform_fmt = {
      command = "terraform",
      args = { "fmt", "-" },
      stdin = true,
    },
    ["google-java-format"] = {
      command = "google-java-format",
      args = { "--aosp", "-" },
      stdin = true,
    },
    xmlformat = {
      command = "xmlformat",
      args = { "--indent", "4", "-" },
      stdin = true,
    },
    ["npm-groovy-lint"] = {
      command = "npm-groovy-lint",
      args = { "--format", "--files", "$FILENAME" },
      stdin = false,
    },
    ktlint = {
      command = "ktlint",
      args = { "--format", "$FILENAME" },
      stdin = false,
    },
    checkmake = {
      command = "checkmake",
      args = { "$FILENAME" },
      stdin = false,
    },
  },

  format_on_save = function(bufnr)
    -- Re-entry guard: if already formatting this buffer, skip
    if _formatting_guard[bufnr] then
      return nil
    end
    _formatting_guard[bufnr] = true
    vim.defer_fn(function()
      _formatting_guard[bufnr] = nil
    end, 5000)

    local slow_filetypes = { kotlin = true, java = true, groovy = true }
    if slow_filetypes[vim.bo[bufnr].filetype] then
      return {
        timeout_ms = 30000,
        lsp_format = "never",
      }
    end
    return {
      timeout_ms = 2000,
      lsp_format = "never",
    }
  end,

  notify_on_error = true,
}

return options
