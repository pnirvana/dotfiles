return {
  "nickjvandyke/opencode.nvim",
  version = "*", -- Latest stable release
  dependencies = {
    {
      -- `snacks.nvim` integration is recommended, but optional
      ---@module "snacks" <- Loads `snacks.nvim` types for configuration intellisense
      "folke/snacks.nvim",
      optional = true,
      opts = {
        input = {}, -- Enhances `ask()`
        picker = { -- Enhances `select()`
          actions = {
            opencode_send = function(...)
              return require("opencode").snacks_picker_send(...)
            end,
          },
          win = {
            input = {
              keys = {
                ["<a-a>"] = { "opencode_send", mode = { "n", "i" } },
              },
            },
          },
        },
      },
    },
  },
  config = function()
    ---@type opencode.Opts
    vim.g.opencode_opts = {
      -- Your configuration, if any; goto definition on the type or field for details
    }

    vim.o.autoread = true -- Required for `opts.events.reload`

    -- Recommended/example keymaps
    vim.keymap.set({ "n", "x" }, "<C-a>", function()
      require("opencode").ask("@this: ", { submit = true })
    end, { desc = "Ask opencode…" })
    vim.keymap.set({ "n", "x" }, "<C-x>", function()
      require("opencode").select()
    end, { desc = "Execute opencode action…" })
    vim.keymap.set({ "n", "t" }, "<C-.>", function()
      require("opencode").toggle()
    end, { desc = "Toggle opencode" })

    vim.keymap.set({ "n", "x" }, "go", function()
      return require("opencode").operator("@this ")
    end, { desc = "Add range to opencode", expr = true })
    vim.keymap.set("n", "goo", function()
      return require("opencode").operator("@this ") .. "_"
    end, { desc = "Add line to opencode", expr = true })

    vim.keymap.set("n", "<S-C-u>", function()
      require("opencode").command("session.half.page.up")
    end, { desc = "Scroll opencode up" })
    vim.keymap.set("n", "<S-C-d>", function()
      require("opencode").command("session.half.page.down")
    end, { desc = "Scroll opencode down" })

    -- You may want these if you use the opinionated `<C-a>` and `<C-x>` keymaps above — otherwise consider `<leader>o…` (and remove terminal mode from the `toggle` keymap)
    vim.keymap.set("n", "+", "<C-a>", { desc = "Increment under cursor", noremap = true })
    vim.keymap.set("n", "-", "<C-x>", { desc = "Decrement under cursor", noremap = true })

    local review_detail_buf = nil
    local review_detail_win = nil
    local review_qf_pending = false

    local function create_detail_pane(qf_win, qf_buf)
      review_detail_buf = vim.api.nvim_create_buf(false, true)
      vim.bo[review_detail_buf].buftype = "nofile"
      vim.bo[review_detail_buf].filetype = "markdown"

      -- split below the qf window
      vim.api.nvim_set_current_win(qf_win)
      vim.cmd("belowright split")
      review_detail_win = vim.api.nvim_get_current_win()
      vim.api.nvim_win_set_buf(review_detail_win, review_detail_buf)
      vim.api.nvim_win_set_height(review_detail_win, 8)
      vim.wo[review_detail_win].wrap = true
      vim.wo[review_detail_win].linebreak = true
      vim.wo[review_detail_win].number = false
      vim.wo[review_detail_win].signcolumn = "no"

      -- return focus to qf
      vim.api.nvim_set_current_win(qf_win)

      -- update detail pane on cursor move
      vim.api.nvim_create_autocmd("CursorMoved", {
        buffer = qf_buf,
        callback = function()
          if not review_detail_buf or not vim.api.nvim_buf_is_valid(review_detail_buf) then
            return
          end
          local items = vim.fn.getqflist()
          local item = items[vim.fn.line(".")]
          if item then
            local lines = vim.split(item.text, "\n", { plain = true })
            vim.api.nvim_buf_set_lines(review_detail_buf, 0, -1, false, lines)
          end
        end,
      })

      -- cleanup when qf closes
      vim.api.nvim_create_autocmd("BufWinLeave", {
        buffer = qf_buf,
        once = true,
        callback = function()
          if review_detail_win and vim.api.nvim_win_is_valid(review_detail_win) then
            vim.api.nvim_win_close(review_detail_win, true)
          end
          review_detail_buf = nil
          review_detail_win = nil
        end,
      })
    end

    -- hook into qf window open, scoped to review findings via flag
    vim.api.nvim_create_autocmd("FileType", {
      pattern = "qf",
      callback = function()
        if not review_qf_pending then
          return
        end
        review_qf_pending = false
        local qf_win = vim.api.nvim_get_current_win()
        local qf_buf = vim.api.nvim_get_current_buf()
        -- defer to let bqf finish its own setup
        vim.schedule(function()
          create_detail_pane(qf_win, qf_buf)
          local items = vim.fn.getqflist()
          if items and items[1] then
            local lines = vim.split(items[1].text, "\n", { plain = true })
            vim.api.nvim_buf_set_lines(assert(review_detail_buf), 0, -1, false, lines)
          end
        end)
      end,
    })

    vim.api.nvim_create_user_command("ReviewLoad", function()
      local findings_file = vim.fn.getcwd() .. "/.opencode/review_findings.txt"
      review_qf_pending = true
      vim.cmd("cgetfile " .. findings_file)
      vim.cmd("copen")
    end, {})
  end,
}
