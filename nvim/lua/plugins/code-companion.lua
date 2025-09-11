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
      local function get_available_copilot_models()
        local ok, models = pcall(function()
          return require("copilot.api").get_models()
        end)

        if ok and models then
          return models
        else
          -- Fallback to your known models
          return {
            "gpt-5",
            "gpt-5-mini",
            "claude-sonnet-4",
            "claude-3-7-sonnet",
            "claude-3-5-sonnet",
            "gemini-2.5-pro",
            "gemini-2.0-flash",
            "o4-mini",
            "o3-mini",
          }
        end
      end

      require("codecompanion").setup {
        log_level = "DEBUG",
        strategies = {
          chat = {
            -- adapter = "copilot",
            adapter = "genplat",
          },
        },
        adapters = {
          copilot = function()
            return require("codecompanion.adapters").extend("copilot", {
              schema = {
                model = {
                  default = "gpt-5", -- Start with the most powerful model
                },
              },
            })
          end,
          genplat = function()
            return require("codecompanion.adapters").extend("openai", {
              env = {
                api_key = "REQUESTER_TOKEN",
                url = "https://generative-ai-platform.ifood-sandbox.com.br/api/v2",
                chat_url = "/v1/chat/completions",
                models_endpoint = "/v1/models",
              },
              schema = {
                model = {
                  default = "claude-sonnet-4-20250514-v1.0",
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
                index_on_startup = true,
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
