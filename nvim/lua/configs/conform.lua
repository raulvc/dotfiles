local options = {
  formatters_by_ft = {
    lua = { "stylua" },
    python = { "isort", "black", "autoflake", "docformatter" },
    -- You can customize some of the format options for the filetype (:help conform.format)
    rust = { "rustfmt" },
    go = { "gofumpt" },
    -- Conform will run the first available formatter
    javascript = { "prettierd" },
    typescript = { "prettierd" },
    -- css = { "prettier" },
    -- html = { "prettier" },
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
  },

  formatters = {
    fixjson = {
      args = { "--indent", "2" },
    },
    yamlfmt = {
      args = { "-formatter", "indent=2,retain_line_breaks=true" },
    },
    -- Enhanced black configuration
    black = {
      prepend_args = {
        "--line-length",
        "88", -- Default is 88, adjust if needed
        "--target-version",
        "py39", -- Adjust to your Python version
        "--preview", -- Enable preview features (optional)
      },
    },
    -- Enhanced isort configuration
    isort = {
      prepend_args = {
        "--profile",
        "black", -- Make isort compatible with black
        "--line-length",
        "88",
        "--multi-line",
        "3",
        "--trailing-comma",
      },
    },
    -- Hadolint for Dockerfile linting/formatting
    hadolint = {
      command = "hadolint",
      args = { "--no-color", "$FILENAME" },
    },
    -- Buf for Protocol Buffers formatting
    buf = {
      command = "buf",
      args = { "format", "-w", "$FILENAME" },
    },
    -- Terraform fmt for HCL files
    terraform_fmt = {
      command = "terraform",
      args = { "fmt", "-" },
      stdin = true,
    },
    ["google-java-format"] = {
      command = "google-java-format",
      stdin = true,
    },
    xmlformat = {
      command = "xmlformat",
      args = { "--indent", "2", "-" },
      stdin = true,
    },
    checkmake = {
      command = "checkmake",
      args = { "$FILENAME" },
      stdin = false,
    },

    -- cookstyle = {
    --   command = "cookstyle",
    --   args = { "--autocorrect", "--format", "quiet", "--stdin", "$FILENAME" },
    --   stdin = true,
    -- },
  },

  format_on_save = {
    -- These options will be passed to conform.format()
    timeout_ms = 2000,
    lsp_format = "never",
  },
}

return options
