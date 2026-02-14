return {
  "folke/snacks.nvim",
  keys = {
    {
      "<leader>.",
      function()
        local scratch_dir = vim.fn.stdpath("data") .. "/scratch/"
        if vim.fn.isdirectory(scratch_dir) == 0 then
          vim.fn.mkdir(scratch_dir, "p")
        end

        local cwd = vim.fn.getcwd()
        local hash = vim.fn.sha256(cwd):sub(1, 8)
        local default_name = "scratch_" .. hash .. ".md"

        vim.ui.input({
          prompt = "Scratch file: ",
          default = default_name,
        }, function(filename)
          if not filename or filename == "" then
            return
          end
          vim.cmd("edit " .. scratch_dir .. filename)

          local bufnr = vim.api.nvim_get_current_buf()
          vim.api.nvim_create_autocmd({ "BufLeave", "BufHidden" }, {
            buffer = bufnr,
            callback = function()
              if vim.bo[bufnr].modified then
                vim.api.nvim_buf_call(bufnr, function()
                  vim.cmd("silent! write")
                end)
              end
            end,
          })
        end)
      end,
      desc = "Scratch Buffer",
    },
    {
      "<leader>S",
      function()
        local scratch_dir = vim.fn.stdpath("data") .. "/scratch/"
        Snacks.picker.files({ cwd = scratch_dir })
      end,
      desc = "Select Scratch Buffer",
    },
  },
}
