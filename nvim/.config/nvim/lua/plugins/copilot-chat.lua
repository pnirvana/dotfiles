-- ~/.config/nvim/lua/plugins/copilot-chat.lua
return {
  {
    "CopilotC-Nvim/CopilotChat.nvim",
    opts = {
      auto_insert_mode = false,
      tools = "copilot", -- always enable copilot tools without typing @copilot
    },
  },
}
