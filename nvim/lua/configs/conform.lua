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
    hcl = { "hclfmt" },
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
      args = { "-formatter", "indent=2", "-formatter", "retain_line_breaks_single=true", "-formatter", "trim_trailing_whitespace=true", "-" },
      stdin = true,
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
    docformatter = {
      args = { "-" },
      stdin = true,
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
    hclfmt = {
      command = "hclfmt",
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
      args = { "--format", "--stdin", "--log-level=none" },
      stdin = true,
    },
    checkmake = {
      command = "checkmake",
      args = { "$FILENAME" },
      stdin = false,
    },
  },

  -- All formatting is async via format_after_save (BufWritePost):
  -- the file writes first, then conform formats in the background and
  -- re-writes if anything changed. This keeps the UI non-blocking.
  format_on_save = false,

  format_after_save = function(bufnr)
    if _formatting_guard[bufnr] then
      return nil
    end
    _formatting_guard[bufnr] = true
    vim.defer_fn(function()
      _formatting_guard[bufnr] = nil
    end, 10000)
    return {
      lsp_format = "never",
    }
  end,

  notify_on_error = true,
}

return options
