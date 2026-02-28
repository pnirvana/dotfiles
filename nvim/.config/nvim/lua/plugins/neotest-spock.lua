return {
  {
    -- Local plugin - point dir to wherever you put neotest-spock
    dir = vim.fn.stdpath("config") .. "/plugins/neotest-spock",
    name = "neotest-spock",
    dependencies = {
      "nvim-neotest/neotest",
      "nvim-treesitter/nvim-treesitter",
    },
  },
  {
    "nvim-neotest/neotest",
    opts = function(_, opts)
      opts.adapters = opts.adapters or {}
      table.insert(opts.adapters, require("neotest-spock"))
    end,
  },
}
