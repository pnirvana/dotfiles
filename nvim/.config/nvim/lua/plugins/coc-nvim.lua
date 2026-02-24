return {
  "neoclide/coc.nvim",
  branch = "release",
  ft = { "groovy" }, -- only load for groovy files
  config = function()
    vim.g.coc_global_extensions = { "coc-groovy" }

    -- prevent coc from messing with Java files
    vim.g.coc_filetype_map = {}

    -- basic keymaps scoped to groovy buffers
    vim.api.nvim_create_autocmd("FileType", {
      pattern = "groovy",
      callback = function()
        local opts = { silent = true, buffer = true }
        vim.keymap.set("n", "gd", "<Plug>(coc-definition)", opts)
        vim.keymap.set("n", "gr", "<Plug>(coc-references)", opts)
        vim.keymap.set("n", "<leader>rn", "<Plug>(coc-rename)", opts)
        vim.keymap.set("n", "K", function()
          vim.fn.CocAction("doHover")
        end, opts)
      end,
    })
  end,
}
