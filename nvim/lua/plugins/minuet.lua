return {
  {
    "milanglacier/minuet-ai.nvim",
    lazy = true,
    cmd = { "Minuet" },
    keys = {
      {
        "<leader>cm",
        function()
          require("minuet.virtualtext").action.toggle_auto_trigger()
        end,
        mode = { "n", "i" },
        desc = "Toggle Minuet completion (current buffer)",
      },
    },
    config = function()
      require("minuet").setup {
        provider = "openai_compatible",
        n_completions = 1,
        context_window = 2048,
        throttle = 400,
        debounce = 200,
        request_timeout = 4,
        virtualtext = {
          -- No filetypes auto-trigger by default; <leader>cm toggles per-buffer.
          auto_trigger_ft = {},
          keymap = {
            accept = "<C-l>",
            accept_line = "<A-a>",
            prev = "<A-[>",
            next = "<A-]>",
            dismiss = "<A-e>",
          },
        },
        provider_options = {
          openai_compatible = {
            api_key = "REQUESTER_TOKEN",
            end_point = (vim.env.GENPLAT_URL or "") .. "/v1/chat/completions",
            model = "gpt-4.1-nano",
            name = "GenPlat",
            stream = true,
            optional = {
              max_tokens = 128,
              -- no reasoning_effort — this isn't a reasoning model
            },
          },
        },
      }
    end,
  },
}
