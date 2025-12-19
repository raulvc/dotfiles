return {
  {
    "olimorris/codecompanion.nvim",
    lazy = false,
    opts = {},
    branch = "main",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-treesitter/nvim-treesitter",
      "ravitemer/codecompanion-history.nvim",
      "nvim-telescope/telescope.nvim",
    },
    config = function()
      require("codecompanion").setup {
        log_level = "DEBUG",

        display = {
          action_palette = {
            width = 95,
            height = 10,
            prompt = "Prompt ",
            provider = "telescope",
          },
          chat = {
            window = {
              layout = "vertical",
              width = 0.45,
              height = 0.8,
              relative = "editor",
            },
            show_token_count = true,
          },
        },

        -- ⚠️ FIX #1: Change 'strategies' to 'interactions'
        interactions = {
          chat = {
            adapter = "genplat",
            slash_commands = {
              ["buffer"] = {
                opts = {
                  provider = "telescope",
                  telescope_picker = function()
                    require("telescope").extensions.frecency.frecency {
                      workspace = "CWD",
                      prompt_title = "Select Buffer for CodeCompanion",
                    }
                  end,
                },
                keymaps = {
                  modes = {
                    i = "<C-b>",
                    n = { "<C-b>", "gb" },
                  },
                },
              },
            },
          },
        },

        adapters = {

          http = {
            opts = {
              show_presets = false, -- 🔑 This hides all built-in adapters
              show_model_choices = true,
              show_defaults = false,
            },

            genplat = function()
              return require("codecompanion.adapters").extend("openai", {
                env = {
                  api_key = "REQUESTER_TOKEN",
                  url = "GENPLAT_URL",
                  chat_url = "/v1/chat/completions",
                  models_endpoint = "/v1/models",
                },
                schema = {
                  model = {
                    default = "claude-opus-4-5-20251101-v1",
                    choices = {
                      "claude-sonnet-4-5-20250929-v1.0",
                      "claude-opus-4-5-20251101-v1",
                    },
                  },
                  temperature = {
                    default = 0,
                  },
                  top_p = {
                    default = 1,
                    enabled = function(self)
                      return false
                    end,
                  },
                },
                url = "${url}${chat_url}",
                headers = {
                  ["Authorization"] = "Bearer ${api_key}",
                  ["Content-Type"] = "application/json",
                },
              })
            end,

            copilot = function()
              return require("codecompanion.adapters").extend("copilot", {
                schema = {
                  model = {
                    default = "claude-sonnet-4.5",
                  },
                },
              })
            end,
          },
        },

        extensions = {
          history = {
            enabled = true,
            expiration_days = 30,
            max_entries = 50,
            opts = {
              summary = {
                generation_opts = {
                  adapter = "copilot",
                  model = "gpt-4o",
                },
              },
              title_generation_opts = {
                adapter = "copilot",
                model = "gpt-4o",
              },
            },
          },
        },
      }
    end,
  },
  {
    "zbirenbaum/copilot.lua",
    cmd = "Copilot",
    event = "InsertEnter",
    config = function()
      require("copilot").setup {
        panel = { enabled = false },
        suggestion = {
          enabled = true,
          auto_trigger = true,
          debounce = 500,
          keymap = {
            accept = "<C-l>",
            dismiss = "<Esc>",
          },
        },
      }
    end,
  },
}
