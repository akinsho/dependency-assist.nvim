local yaml = require 'dependency_assist/yaml'
local api = require 'dependency_assist/dart/pubspec_api'
local formatter = require 'dependency_assist/dart/formatter'

--- @param buf_id number
--- @param callback function
local function show_dart_versions(buf_id, callback)
  local lines = vim.api.nvim_buf_get_lines(buf_id, 0, -1, false)
  if #lines > 0 then
    -- TODO empty lines are being omitted this breaks
    -- parsing for dependencies
    local buffer_text = table.concat(lines, '\n')
    local parsed_lines = yaml.eval(buffer_text)

    local deps = parsed_lines.dependencies
    if deps and not vim.tbl_isempty(deps) then
      api.check_outdated_packages(deps, function (latest)
        local lnum
        for idx, line in ipairs(lines) do
          if line:match(latest.name..':') then lnum = idx - 1 end
        end
        if lnum then callback(lnum, latest.version) end
      end)
    end
  end
end


local dart = {
  api = api,
  filename = 'pubspec.yaml',
  formatter = formatter,
  show_versions = show_dart_versions,
}

return dart
