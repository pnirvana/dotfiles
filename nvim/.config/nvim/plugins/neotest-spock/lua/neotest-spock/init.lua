local lib = require("neotest.lib")

local QUERY = [[
(class_definition
  name: (identifier) @namespace.name) @namespace.definition

(function_definition
  function: (quoted_identifier
    (string_content) @test.name)) @test.definition
]]

local function find_maven_root(path)
  return lib.files.match_root_pattern("pom.xml")(path)
end

-- Decode common XML entities
local function decode_xml(s)
  return s:gsub("&#10;", "\n")
    :gsub("&#13;", "\r")
    :gsub("&amp;", "&")
    :gsub("&lt;", "<")
    :gsub("&gt;", ">")
    :gsub("&quot;", '"')
    :gsub("&apos;", "'")
end

-- Parse a surefire XML report file.
-- Returns { [test_name] = { status, short, output } }
local function parse_surefire_xml(xml_path)
  local ok, content = pcall(lib.files.read, xml_path)
  if not ok then
    return {}
  end

  -- Replace newlines with \0 so '.' matches across lines in Lua patterns
  local flat = content:gsub("\r?\n", "\0")

  local results = {}

  -- Normalize self-closing <testcase ... /> to <testcase ...></testcase>
  -- so the body pattern can't mistake the / as part of attrs and bleed into the next testcase
  flat = flat:gsub("<testcase([^/]-)/>", "<testcase%1></testcase>")

  -- All testcases now have a body
  for attrs, body in flat:gmatch("<testcase([^>]-)>(.-)</testcase>") do
    local name = attrs:match('name="([^"]*)"')
    if not name then
      goto continue
    end

    if body:find("<skipped") then
      results[name] = { status = "skipped", short = nil, output = "" }
    elseif body:find("<failure") then
      -- Extract message attribute and CDATA content separately
      local msg = decode_xml((body:match('<failure[^>]-message="([^"]*)"') or ""):gsub("%z", "\n"))
      local cdata = body:match("<!%[CDATA%[(.-)%]%]>") or ""
      cdata = cdata:gsub("%z", "\n"):gsub("^\n+", ""):gsub("\n+$", "")
      local output = cdata ~= "" and cdata or msg
      local short = msg:gsub("\n+$", ""):gsub("\n+", " ")
      results[name] = { status = "failed", short = short, output = output }
    elseif body:find("<error") then
      local msg = decode_xml((body:match('<error[^>]-message="([^"]*)"') or ""):gsub("%z", "\n"))
      local cdata = body:match("<!%[CDATA%[(.-)%]%]>") or ""
      cdata = cdata:gsub("%z", "\n"):gsub("^\n+", ""):gsub("\n+$", "")
      local output = cdata ~= "" and cdata or msg
      local short = msg:gsub("\n+$", ""):gsub("\n+", " ")
      results[name] = { status = "failed", short = short, output = output }
    else
      results[name] = { status = "passed", short = nil, output = "" }
    end

    ::continue::
  end

  return results
end

local function write_temp(str)
  local path = os.tmpname()
  local f = io.open(path, "w")
  if f then
    f:write(str:gsub("%z", ""))
    f:close()
  end
  return path
end

---------------------------------------------------------------------------
local adapter = { name = "neotest-spock" }

function adapter.root(dir)
  return find_maven_root(dir)
end

function adapter.filter_dir(name)
  local skip = { target = true, [".git"] = true, [".idea"] = true, node_modules = true }
  return not skip[name]
end

function adapter.is_test_file(file_path)
  return file_path:match("Spec%.groovy$") ~= nil and file_path:match("[/\\]src[/\\]test[/\\]") ~= nil
end

function adapter.discover_positions(path)
  return lib.treesitter.parse_positions(path, QUERY, {
    nested_tests = false,
    require_namespaces = true,
    language = "groovy",
  })
end

function adapter.build_spec(args)
  local position = args.tree:data()
  local root = find_maven_root(position.path)
  if not root then
    return nil
  end

  local class_name, method_name

  if position.type == "test" then
    local parent = args.tree:parent():data()
    class_name = parent.name
    method_name = position.name
  elseif position.type == "namespace" then
    class_name = position.name
  elseif position.type == "file" then
    class_name = vim.fn.fnamemodify(position.path, ":t:r")
  end

  local test_filter = ""
  if class_name then
    if method_name then
      test_filter = string.format('-Dtest="%s#%s"', class_name, method_name)
    else
      test_filter = string.format('-Dtest="%s"', class_name)
    end
  end

  local module_root = find_maven_root(vim.fn.fnamemodify(position.path, ":h")) or root

  local mvn_cmd = vim.fn.filereadable(root .. "/mvnw") == 1 and (root .. "/mvnw") or "mvn"

  local reports_dir = module_root .. "/target/surefire-reports"
  local is_dap = args.strategy == "dap"
  local debug_flags = is_dap
      and '-Dmaven.surefire.debug="-agentlib:jdwp=transport=dt_socket,server=y,suspend=y,address=*:5005"'
    or ""

  local command = string.format(
    "cd %s && rm -rf %s && %s test %s %s -Dsurefire.failIfNoSpecifiedTests=false",
    vim.fn.shellescape(module_root),
    vim.fn.shellescape(reports_dir),
    mvn_cmd,
    test_filter,
    debug_flags
  )

  local spec = {
    command = command,
    context = {
      results_dir = reports_dir,
    },
  }

  if is_dap then
    spec.strategy = function(run_spec, _context)
      -- Run Maven in a plain job, capture output to a temp file
      local output_path = vim.fn.tempname()
      local output_file = io.open(output_path, "w")
      local done = false
      local exit_code = 0

      local job_id = vim.fn.jobstart(run_spec.command, {
        on_stdout = function(_, data)
          if output_file and data then
            output_file:write(table.concat(data, "\n"))
          end
        end,
        on_stderr = function(_, data)
          if output_file and data then
            output_file:write(table.concat(data, "\n"))
          end
        end,
        on_exit = function(_, code)
          if output_file then
            output_file:close()
            output_file = nil
          end
          exit_code = code
          done = true
        end,
        stdout_buffered = false,
        stderr_buffered = false,
      })

      -- Poll for JDWP port then attach DAP, bypassing nvim-java enricher
      local function try_attach(attempts)
        if attempts <= 0 then
          vim.notify("neotest-spock: timed out waiting for debug port 5005", vim.log.levels.ERROR)
          return
        end
        local tcp = vim.uv.new_tcp()
        tcp:connect("127.0.0.1", 5005, function(err)
          tcp:close()
          if err then
            vim.defer_fn(function()
              try_attach(attempts - 1)
            end, 500)
          else
            vim.schedule(function()
              local dap = require("dap")
              -- Register a separate adapter type so nvim-java's enricher doesn't intercept it
              if not dap.adapters["java-maven-debug"] then
                dap.adapters["java-maven-debug"] = dap.adapters["java"]
              end
              dap.run({
                type = "java-maven-debug",
                request = "attach",
                name = "neotest-spock attach",
                hostName = "127.0.0.1",
                port = 5005,
                -- Pre-populate fields nvim-java's enrich_config checks,
                -- triggering its early-return so it doesn't require mainClass
                mainClass = "",
                projectName = "",
                modulePaths = {},
                classPaths = {},
                javaExec = "",
              })
            end)
          end
        end)
      end
      vim.defer_fn(function()
        try_attach(60)
      end, 1000)

      return {
        output_stream = function()
          return function()
            return nil
          end
        end,
        result = function()
          local nio = require("nio")
          while not done do
            nio.sleep(200)
          end
          return exit_code
        end,
        output = function()
          return output_path
        end,
        stop = function()
          vim.fn.jobstop(job_id)
        end,
        attach = function() end,
      }
    end
  end

  return spec
end

function adapter.results(spec, result, tree)
  local results = {}
  local results_dir = spec.context.results_dir

  -- Build map: test name → position id
  local name_to_id = {}
  for _, node in tree:iter_nodes() do
    local data = node:data()
    if data.type == "test" then
      name_to_id[data.name] = data.id
    end
  end

  local xml_files = vim.fn.glob(results_dir .. "/TEST-*.xml", false, true)

  if vim.tbl_isempty(xml_files) then
    local file_data = tree:data()
    results[file_data.id] = {
      status = result.code == 0 and "passed" or "failed",
      output = result.output,
    }
    return results
  end

  -- Parse XML and update cache with fresh results
  for _, xml_file in ipairs(xml_files) do
    for test_name, test_result in pairs(parse_surefire_xml(xml_file)) do
      local id = name_to_id[test_name]
      if id then
        local full_output = test_result.output and test_result.output ~= "" and test_result.output or nil
        local output_path = full_output and write_temp(full_output) or result.output

        local errors = nil
        if test_result.status == "failed" then
          local line_nr = full_output and tonumber(full_output:match("%.groovy:(%d+)"))
          errors = { { message = test_result.short or "Test failed", line = line_nr and (line_nr - 1) or 0 } }
        end

        results[id] = {
          status = test_result.status,
          short = test_result.short,
          errors = errors,
          output = output_path,
        }
      end
    end
  end

  return results
end

setmetatable(adapter, {
  __call = function(_, _opts)
    return adapter
  end,
})

return adapter
