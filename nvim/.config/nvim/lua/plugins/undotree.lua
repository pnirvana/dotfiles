return {
  "jiaoshijie/undotree",
  opts = {
    -- your options
  },
  keys = { -- load the plugin only when using it's keybinding:
    {
      "<leader>fh",
      function()
        require("undotree").toggle()
      end,
      desc = "Local history",
    },
  },
  setup = { -- load the plugin only when using it's keybinding:
    vim.api.nvim_create_user_command("Undotree", function(opts)
      local args = opts.fargs
      local cmd = args[1]

      local cb = require("undotree")[cmd]

      if cmd == "setup" or cb == nil then
        vim.notify("Invalid subcommand: " .. (cmd or ""), vim.log.levels.ERROR)
      else
        cb()
      end
    end, {
      nargs = 1,
      complete = function(arg_lead)
        return vim.tbl_filter(function(cmd)
          return vim.startswith(cmd, arg_lead)
        end, { "toggle", "open", "close" })
      end,
      desc = "Undotree command with subcommands: toggle, open, close",
    }),
  },
}
