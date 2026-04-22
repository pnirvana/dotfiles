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

local function find_source_file(root, classname)
  local simple = classname:match("%.([^%.]+)$") or classname
  local dirs = {
    root .. "/src/test/java",
    root .. "/src/test/groovy",
    root .. "/src/main/java",
    root .. "/src/main/groovy",
  }
  for _, dir in ipairs(dirs) do
    for _, ext in ipairs({ "java", "groovy" }) do
      local hits = vim.fn.glob(dir .. "/**/" .. simple .. "." .. ext, false, true)
      if #hits > 0 then return hits[1] end
    end
  end
end

local function decode_xml(s)
  return s:gsub("&#10;", "\n"):gsub("&#13;", "\r")
          :gsub("&amp;", "&"):gsub("&lt;", "<"):gsub("&gt;", ">")
          :gsub("&quot;", '"'):gsub("&apos;", "'")
end

local function parse_surefire_xml(xml_path, root, start_time)
  local stat = vim.uv.fs_stat(xml_path)
  if not stat or stat.mtime.sec < start_time then return {} end

  local ok, raw = pcall(vim.fn.readfile, xml_path)
  if not ok then return {} end
  local content = table.concat(raw, "\n")

  local classname = content:match('<testsuite[^>]-name="([^"]*)"')
  if not classname then return {} end

  local source_file = find_source_file(root, classname)
  local simple = classname:match("%.([^%.]+)$") or classname

  local flat = content:gsub("\r?\n", "\0")
  flat = flat:gsub("<testcase([^/]-)/>", "<testcase%1></testcase>")

  local errors = {}
  for attrs, body in flat:gmatch("<testcase([^>]-)>(.-)</testcase>") do
    local method = attrs:match('name="([^"]*)"')
    if not method then goto continue end

    local is_failure = body:find("<failure") or body:find("<error")
    if not is_failure then goto continue end

    local raw_msg = body:match('<[fe][^>]-message="([^"]*)"') or "Test failed"
    local msg = decode_xml(raw_msg):gsub("%z", " "):gsub("%s+$", "")
    local first_line = msg:match("^([^\n]+)") or msg

    local lnum = 1
    if source_file then
      local ext = source_file:match("%.(%a+)$") or "java"
      local search = body:match("<failure[^>]*>(.-)</failure>")
                  or body:match("<error[^>]*>(.-)</error>")
                  or body
      local ln = search:match(vim.pesc(simple) .. "%." .. ext .. ":(%d+)")
              or search:match("%." .. ext .. ":(%d+)")
      lnum = ln and tonumber(ln) or 1
    end

    table.insert(errors, {
      filename = source_file or "",
      lnum = lnum,
      col = 1,
      text = method .. ": " .. first_line,
      type = "E",
      valid = source_file and 1 or 0,
    })

    ::continue::
  end
  return errors
end

local function parse_test_failures(root, start_time)
  local errors = {}
  for _, dir in ipairs({ root .. "/target/surefire-reports", root .. "/target/failsafe-reports" }) do
    for _, xml in ipairs(vim.fn.glob(dir .. "/TEST-*.xml", false, true)) do
      vim.list_extend(errors, parse_surefire_xml(xml, root, start_time))
    end
  end
  return errors
end

local function apply_diagnostics(errors)
  vim.diagnostic.reset(ns)
  local by_buf = {}
  for _, err in ipairs(errors) do
    if err.valid == 1 then
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
  end
  for bufnr, diags in pairs(by_buf) do
    vim.diagnostic.set(ns, bufnr, diags)
  end
end

return {
  desc = "Parse Maven Java/Groovy compiler errors and test failures into quickfix and diagnostics",
  params = {},
  constructor = function()
    local lines = {}
    local start_time = os.time() - 1
    local origin_win = vim.api.nvim_get_current_win()
    return {
      on_output_lines = function(_, _, new_lines)
        vim.list_extend(lines, new_lines)
      end,
      on_complete = function(_, task)
        local compile_errors = parse_errors(lines)
        lines = {}
        local ok, test_errors = pcall(parse_test_failures, task.cwd, start_time)
        if not ok then
          vim.notify("Maven test parsing error: " .. tostring(test_errors), vim.log.levels.WARN, { title = "Maven" })
          test_errors = {}
        end
        local all_errors = vim.list_extend(vim.deepcopy(compile_errors), test_errors)
        vim.schedule(function()
          vim.fn.setqflist({}, "r", { title = task.name, items = all_errors })
          apply_diagnostics(all_errors)
          if #all_errors > 0 then
            require("overseer").close()
            local ok, trouble = pcall(require, "trouble")
            if ok then
              trouble.open({ mode = "maven" })
            else
              if vim.api.nvim_win_is_valid(origin_win) then
                vim.api.nvim_set_current_win(origin_win)
              end
              vim.cmd("copen")
            end
          end
        end)
      end,
    }
  end,
}
