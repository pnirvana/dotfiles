local maven_commands = {
  { label = "compile", args = { "clean", "compile" } },
  { label = "test", args = { "clean", "test" } },
  { label = "package", args = { "clean", "package" } },
  { label = "package (no tests)", args = { "clean", "package", "-DskipTests" } },
  { label = "verify", args = { "clean", "verify" } },
  { label = "clean", args = { "clean" } },
}

local function mvn_run(root, args)
  vim.notify("Running mvn " .. table.concat(args, " ") .. "...", vim.log.levels.INFO)

  local output = {}

  vim.fn.jobstart(vim.list_extend({ root .. "/mvnw" }, args), {
    cwd = root,
    on_stdout = function(_, data)
      if data then
        for _, line in ipairs(data) do
          table.insert(output, line)
        end
      end
    end,
    on_stderr = function(_, data)
      if data then
        for _, line in ipairs(data) do
          table.insert(output, line)
        end
      end
    end,
    on_exit = function()
      vim.schedule(function()
        local combined = table.concat(output, "\n")
        if combined:find("BUILD FAILURE") then
          vim.notify("mvn failed", vim.log.levels.ERROR)
        elseif combined:find("BUILD SUCCESS") then
          vim.notify("mvn succeeded", vim.log.levels.INFO)
        else
          vim.notify("mvn: unexpected output", vim.log.levels.WARN)
        end
      end)
    end,
  })
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
        mvn_run(root, cmd.args)
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

    vim.api.nvim_create_user_command("MvnCompile", function()
      mvn_run(root, { "clean", "compile", "-o" })
    end, {})
    vim.api.nvim_create_user_command("MvnSelect", function()
      mvn_select(root)
    end, {})

    vim.keymap.set("n", "<leader>mc", function()
      mvn_run(root, { "compile", "-o", "-Dmaven.compiler.useIncrementalCompilation=false" })
    end, {
      buffer = args.buf,
      desc = "Maven compile (offline)",
    })
    vim.keymap.set("n", "<leader>mm", function()
      mvn_select(root)
    end, {
      buffer = args.buf,
      desc = "Maven menu",
    })
  end,
})

return {}
