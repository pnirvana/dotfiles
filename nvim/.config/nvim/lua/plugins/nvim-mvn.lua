local maven_commands = {
  { label = "compile", args = { "clean", "compile" } },
  { label = "test", args = { "clean", "test" } },
  { label = "package", args = { "clean", "package" } },
  { label = "package (no tests)", args = { "clean", "package", "-DskipTests" } },
  { label = "verify", args = { "clean", "verify" } },
  { label = "clean", args = { "clean" } },
}

local function run_maven(root, args, label)
  local overseer = require("overseer")
  local mvnw = vim.fn.filereadable(root .. "/mvnw") == 1 and (root .. "/mvnw") or "mvn"

  local task = overseer.new_task({
    name = "Maven: " .. label,
    cmd = vim.list_extend({ mvnw }, args),
    cwd = root,
    components = {
      "maven_diagnostics",
      { "on_complete_notify", statuses = { "FAILURE", "SUCCESS" } },
      "on_exit_set_status",
    },
  })
  task:start()
end

local function mvn_select(root)
  local labels = vim.tbl_map(function(c)
    return c.label
  end, maven_commands)
  vim.ui.select(labels, { prompt = "Maven command:" }, function(choice)
    if not choice then
      return
    end
    for _, cmd in ipairs(maven_commands) do
      if cmd.label == choice then
        run_maven(root, cmd.args, choice)
        return
      end
    end
  end)
end

vim.api.nvim_create_autocmd("LspAttach", {
  callback = function(args)
    local client = vim.lsp.get_client_by_id(args.data.client_id)
    if not client or client.name ~= "jdtls" then
      return
    end

    local root = client.config.root_dir
    if not root then
      return
    end

    pcall(function()
      require("which-key").add({ { "<leader>m", group = "Maven" } })
    end)

    vim.api.nvim_create_user_command("MvnCompile", function()
      run_maven(root, { "clean", "compile", "-o" }, "compile (offline)")
    end, {})
    vim.api.nvim_create_user_command("MvnSelect", function()
      mvn_select(root)
    end, {})

    local opts = { buffer = args.buf, silent = true }
    vim.keymap.set("n", "<leader>mc", function()
      run_maven(root, { "compile", "-o", "-Dmaven.compiler.useIncrementalCompilation=false" }, "compile (offline)")
    end, vim.tbl_extend("force", opts, { desc = "Maven compile (offline)" }))
    vim.keymap.set("n", "<leader>mm", function()
      mvn_select(root)
    end, vim.tbl_extend("force", opts, { desc = "Maven menu" }))
  end,
})

return {}
