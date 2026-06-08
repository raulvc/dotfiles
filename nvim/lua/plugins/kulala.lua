return {
  {
    "mistweaverco/kulala.nvim",
    keys = {
      { "<leader>R", "", desc = "+Rest (Kulala)" },
      { "<leader>Rs", desc = "Send request" },
      { "<leader>Ra", desc = "Send all requests" },
      { "<leader>Rb", desc = "Open scratchpad" },
      { "<leader>Rc", desc = "Copy as cURL" },
      { "<leader>RC", desc = "Paste from cURL" },
      { "<leader>Rg", desc = "Download GraphQL schema" },
      { "<leader>Ri", desc = "Inspect current request" },
      { "<leader>Rn", desc = "Jump to next request" },
      { "<leader>Rp", desc = "Jump to previous request" },
      { "<leader>Rq", desc = "Close window" },
      { "<leader>Rr", desc = "Replay last request" },
      { "<leader>Rt", desc = "Toggle headers/body" },
      { "<leader>RS", desc = "Show stats" },
    },
    ft = { "http", "rest" },
    opts = {
      -- Enable default keymaps under <leader>R
      global_keymaps = true,
      global_keymaps_prefix = "<leader>R",
      kulala_keymaps_prefix = "",

      -- Use default env unless overridden by http-client.env.json
      default_env = "dev",

      -- Pick up .vscode/settings.json rest-client.environmentVariables
      vscode_rest_client_environmentvars = true,

      ui = {
        display_mode = "split", -- "split" | "float"
        split_direction = "vertical",
        default_view = "body", -- "body" | "headers" | "headers_body" | "verbose"
        winbar = true,
        default_winbar_panes = { "body", "headers", "headers_body", "verbose", "script_output", "stats" },
        show_variable_info_text = "float",
        show_request_summary = true,
        show_icons = "on_request",
        disable_news_popup = true,
        report = {
          show_script_output = "on_error",
          show_asserts_output = "on_error",
          show_summary = true,
        },
      },

      lsp = {
        enable = true,
        formatter = {
          split_params = 4,
          sort = {
            metadata = true,
            variables = true,
            commands = false,
            json = true,
          },
          quote_json_variables = true,
          indent = 2,
        },
      },

      -- 2 = error + warn (quieter than default 3)
      debug = 2,
    },
  },
}
