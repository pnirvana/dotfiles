vim.api.nvim_create_autocmd("User", {
  pattern = "TSUpdate",
  callback = function()
    require("nvim-treesitter.parsers").groovy = {
      install_info = {
        url = "https://github.com/murtaza64/tree-sitter-groovy",
        branch = "main",
        files = { "src/parser.c", "src/scanner.c" },
      },
      filetype = "groovy",
    }
  end,
})

return {}
