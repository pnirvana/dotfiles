local ns = vim.api.nvim_create_namespace("maven")

local function strip_ansi(s)
  return s:gsub("\27%[[0-9;]*[A-Za-z]", "")
end

local function parse_errors(lines)
  local errors = {}
  local seen = {}
  for _, line in ipairs(lines) do
    line = strip_ansi(line)
    local file, lnum, col, msg
    -- Java (javac): [ERROR] /path/Foo.java:[42,13] message
    file, lnum, col, msg = line:match("^%[ERROR%] (.+%.java):%[(%d+),(%d+)%] (.+)$")
    if not file then
      -- Groovy (GMavenPlus): [ERROR] /path/Bar.groovy: 42: message @ line 42, column 5.
      file, lnum, msg = line:match("^%[ERROR%] (.+%.groovy): (%d+): (.+)$")
      if file then
        col = msg:match("@ line %d+, column (%d+)%.")
        msg = msg:gsub(" @ line %d+, column %d+%.$", ""):gsub("%s+$", "")
      end
    end
    if file then
      local key = file .. "\0" .. lnum .. "\0" .. (col or "") .. "\0" .. msg
      if not seen[key] then
        seen[key] = true
        table.insert(errors, { filename = file, lnum = tonumber(lnum), col = col and tonumber(col) or 1, text = msg, type = "E", valid = 1 })
      end
    end
  end
  return errors
end

local function apply_diagnostics(errors)
  vim.diagnostic.reset(ns)
  local by_buf = {}
  for _, err in ipairs(errors) do
    local bufnr = vim.fn.bufadd(err.filename)
    by_buf[bufnr] = by_buf[bufnr] or {}
    table.insert(by_buf[bufnr], {
      lnum = err.lnum - 1,
      col = (err.col or 1) - 1,
      message = err.text,
      severity = vim.diagnostic.severity.ERROR,
      source = "maven",
    })
  end
  for bufnr, diags in pairs(by_buf) do
    vim.diagnostic.set(ns, bufnr, diags)
  end
end

return {
  desc = "Parse Maven Java/Groovy compiler errors into quickfix and diagnostics",
  params = {},
  constructor = function()
    local lines = {}
    return {
      on_output_lines = function(_, _, new_lines)
        vim.list_extend(lines, new_lines)
      end,
      on_complete = function(_, task)
        local errors = parse_errors(lines)
        lines = {}
        vim.schedule(function()
          vim.fn.setqflist({}, "r", { title = task.name, items = errors })
          apply_diagnostics(errors)
          if #errors > 0 then
            vim.cmd("copen")
          end
        end)
      end,
    }
  end,
}
