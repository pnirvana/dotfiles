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

    -- user command for opencode review agent to open the findings in a picker when done
    vim.api.nvim_create_user_command("ReviewFindings", function()
      local findings_file = vim.fn.getcwd() .. "/.opencode/review_findings.txt"
      local ok, lines = pcall(vim.fn.readfile, findings_file)
      if not ok or #lines == 0 then
        vim.notify("No review findings found", vim.log.levels.WARN)
        return
      end

      local cwd = vim.fn.getcwd()

      local function short_path(file)
        local rel = vim.fn.fnamemodify(cwd .. "/" .. file, ":~:.")
        return rel:match("[^/]+/[^/]+$") or rel
      end

      local items = {}
      for _, line in ipairs(lines) do
        if line ~= "" and not line:match("^#") then
          local file, lnum, col, severity, msg = line:match("^([^:]+):(%d+):(%d+):%s*(%w+)%s+(.+)$")
          if file then
            local severity_hl = ({
              error = "DiagnosticError",
              warning = "DiagnosticWarn",
              info = "DiagnosticInfo",
            })[severity:lower()] or "DiagnosticInfo"

            table.insert(items, {
              text = string.format("[%s] %s:%s — %s", severity:upper(), short_path(file), lnum, msg),
              file = cwd .. "/" .. file,
              pos = { tonumber(lnum), tonumber(col) - 1 },
              filename = file,
              lnum = tonumber(lnum),
              col = tonumber(col),
              severity = severity,
              message = msg,
              hl = { { severity_hl, 1, #severity + 2 } },
            })
          end
        end
      end

      if #items == 0 then
        vim.notify("No actionable findings (all commented out)", vim.log.levels.INFO)
        return
      end

      Snacks.picker.pick({
        title = string.format("Review Findings (%d)", #items),
        items = items,
        format = "text",
        preview = "file",
        layout = "vertical",
      })
    end, {})

    -- user command to write the filtered findings back
    vim.api.nvim_create_user_command("ReviewWrite", function()
      local findings_file = vim.fn.getcwd() .. "/.opencode/review_findings_to_fix.txt"
      local items = vim.fn.getqflist()
      local lines = {}
      for _, item in ipairs(items) do
        local fname = vim.api.nvim_buf_get_name(item.bufnr)
        local rel = vim.fn.fnamemodify(fname, ":~:.")
        table.insert(
          lines,
          string.format(
            "%s:%d:%d: %s %s",
            rel,
            item.lnum,
            item.col,
            item.type == "E" and "error" or item.type == "W" and "warning" or "info",
            item.text
          )
        )
      end
      vim.fn.writefile(lines, findings_file)
      vim.notify(string.format("Wrote %d findings to %s", #lines, findings_file), vim.log.levels.INFO)
    end, {})
  end,
}
