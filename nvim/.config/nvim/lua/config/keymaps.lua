-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here
vim.keymap.set("n", "<leader>co", function()
  vim.lsp.buf.code_action({
    context = { only = { "source.organizeImports" } },
    apply = true,
  })
end, { desc = "Organize Imports" })

local wk = require("which-key")
wk.add({
  { "<leader>j", group = "Java" },
})

-- ~/.config/nvim/lua/config/keymaps.lua
vim.keymap.set("n", "<M-h>", "<cmd>vertical resize -5<cr>", { desc = "Resize left" })
vim.keymap.set("n", "<M-l>", "<cmd>vertical resize +5<cr>", { desc = "Resize right" })
vim.keymap.set("n", "<M-j>", "<cmd>resize -5<cr>", { desc = "Resize down" })
vim.keymap.set("n", "<M-k>", "<cmd>resize +5<cr>", { desc = "Resize up" })
