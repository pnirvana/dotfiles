local maven_commands = {
  { label = "compile", args = { "clean", "compile" } },
  { label = "test", args = { "clean", "test" } },
  { label = "package", args = { "clean", "package" } },
  { label = "package (no tests)", args = { "clean", "package", "-DskipTests" } },
  { label = "verify", args = { "clean", "verify" } },
  { label = "clean", args = { "clean" } },
}

local function find_root()
  local path = vim.api.nvim_buf_get_name(0)
  if path == "" then
    path = vim.uv.cwd()
  end
  local root = vim.fs.find("pom.xml", { upward = true, path = vim.fn.fnamemodify(path, ":p:h") })[1]
  if not root then
    vim.notify("No pom.xml found", vim.log.levels.WARN, { title = "Maven" })
    return nil
  end
  return vim.fn.fnamemodify(root, ":p:h")
end

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
  require("overseer").open({ enter = true })
end

local function mvn_select()
  local root = find_root()
  if not root then return end
  local labels = vim.tbl_map(function(c)
    return c.label
  end, maven_commands)
  vim.ui.select(labels, { prompt = "Maven command:" }, function(choice)
    if not choice then return end
    for _, cmd in ipairs(maven_commands) do
      if cmd.label == choice then
        run_maven(root, cmd.args, choice)
        return
      end
    end
  end)
end

require("which-key").add({ { "<leader>m", group = "Maven" } })

vim.api.nvim_create_user_command("MvnCompile", function()
  local root = find_root()
  if root then run_maven(root, { "clean", "compile", "-o" }, "compile (offline)") end
end, {})

vim.api.nvim_create_user_command("MvnSelect", function()
  mvn_select()
end, {})

vim.keymap.set("n", "<leader>mc", function()
  local root = find_root()
  if root then run_maven(root, { "compile", "-o", "-Dmaven.compiler.useIncrementalCompilation=false" }, "compile (offline)") end
end, { desc = "Maven compile (offline)" })

vim.keymap.set("n", "<leader>mm", mvn_select, { desc = "Maven menu" })

return {
  {
    "nvim-lualine/lualine.nvim",
    opts = function(_, opts)
      table.insert(opts.sections.lualine_x, 1, { "overseer" })
    end,
  },
}
