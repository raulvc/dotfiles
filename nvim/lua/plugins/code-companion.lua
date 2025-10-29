return {
  {
    "olimorris/codecompanion.nvim",
    lazy = false,
    opts = {},
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-treesitter/nvim-treesitter",
      "ravitemer/codecompanion-history.nvim",
      "nvim-telescope/telescope.nvim",
      {
        "Davidyz/VectorCode",
        version = "*", -- optional, depending on whether you're on nightly or release
        dependencies = { "nvim-lua/plenary.nvim" },
        cmd = "VectorCode", -- if you're lazy-loading VectorCode
      },
    },
    config = function()
      require("codecompanion").setup {
        log_level = "DEBUG",

        display = {
          action_palette = {
            width = 95,
            height = 10,
            prompt = "Prompt ",
            provider = "telescope", -- or "default"
          },
          chat = {
            window = {
              layout = "vertical", -- "vertical", "horizontal", "float", "buffer"
              width = 0.45, -- % of the editor width
              height = 0.8, -- % of the editor height
              relative = "editor", -- "editor", "win"
            },
            show_token_count = true, -- Display token usage
          },
        },

        strategies = {
          chat = {
            adapter = "copilot",
            -- adapter = "genplat",
            slash_commands = {
              ["buffer"] = {
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
          copilot = function()
            return require("codecompanion.adapters").extend("copilot", {
              schema = {
                model = {
                  default = "claude-sonnet-4.5", -- Start with the most powerful model
                },
              },
            })
          end,
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
                  default = "claude-sonnet-4-5-20250929-v1.0",
                  choices = {
                    "claude-sonnet-4-5-20250929-v1.0",
                    "claude-opus-4-1-20250805-v1.0",
                  },
                },
                temperature = {
                  default = 0, -- Deterministic output, best for coding
                },
                top_p = {
                  default = 1,
                  condition = function(self)
                    return false -- Never include top_p
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
        },
        extensions = {
          history = {
            enabled = true,
            expiration_days = 90,
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
              memory = {
                tool_opts = {
                  -- Default number of memories to retrieve
                  default_num = 30,
                },
                index_on_startup = vim.env.KITTY_SCROLLBACK_NVIM == nil,
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
