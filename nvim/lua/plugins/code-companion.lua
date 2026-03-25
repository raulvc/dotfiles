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
        opts = {
          log_level = "DEBUG",
        },

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

        interactions = {
          shared = {
            keymaps = {
              accept_change = {
                modes = { n = "ga" },
                description = "Accept the suggested change",
              },
              accept_all_changes = {
                modes = { n = "gA" },
              },
            },
          },
          chat = {
            adapter = "genplat",
            slash_commands = {
              ["buffer"] = {
                callback = function(chat)
                  if not _G.multi_select_picker_open then
                    vim.notify("multi_select_picker_open not loaded yet", vim.log.levels.ERROR)
                    return
                  end
                  _G.multi_select_picker_open {
                    on_select = function(_, entries)
                      for _, entry in ipairs(entries) do
                        local bufnr = entry.bufnr
                        if bufnr and vim.api.nvim_buf_is_valid(bufnr) then
                          local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
                          local content = table.concat(lines, "\n")
                          local rel_path = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(bufnr), ":.")
                          local ft = vim.bo[bufnr].filetype or ""
                          local id = "<buf>" .. rel_path .. "</buf>"

                          chat:add_context(
                            {
                              content = string.format(
                                "Here is the content from the buffer `%s` (with a filetype of `%s`):\n\n```%s\n%s\n```",
                                rel_path,
                                ft,
                                ft,
                                content
                              ),
                              role = "user",
                            },
                            "codecompanion.interactions.chat.slash_commands.builtin.buffer",
                            id,

                            {
                              bufnr = bufnr,
                              path = rel_path,
                              visible = false,
                            }
                          )
                        end
                      end
                    end,
                  }
                end,
                description = "Insert buffer(s) (multi-select)",
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
              show_presets = false,
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
                    default = "claude-opus-4-6-vertexai",
                    choices = {
                      "glm-5-maas",
                      "claude-opus-4-6-bedrock",
                      "claude-opus-4-6-vertexai",
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
