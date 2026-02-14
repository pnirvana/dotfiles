return {
  "mfussenegger/nvim-dap",
  optional = true,
  config = function()
    local dap = require("dap")

    -- This is a Java debug adapter config (type="java")
    -- but we register it under groovy so nvim-java doesn't enrich it as a Java "launch".
    dap.configurations.groovy = dap.configurations.groovy or {}
    table.insert(dap.configurations.groovy, {
      type = "java",
      request = "attach",
      name = "Attach: Groovy LS (localhost:5005)",
      hostName = "127.0.0.1",
      port = 5005,
    })
  end,
}
