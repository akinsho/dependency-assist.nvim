local yaml = require 'dependency_assist/yaml'
local api = require 'dependency_assist/dart/pubspec_api'
local formatter = require 'dependency_assist/dart/formatter'
local helpers = require 'dependency_assist/helpers'

local extension = 'dart'
local dependency_file = 'pubspec.yaml'

--- @param buf_id number
--- @param callback function
local function show_dart_versions(buf_id, callback)
  local lines = vim.api.nvim_buf_get_lines(buf_id, 0, -1, false)
  if #lines > 0 then
    local buffer_text = ''
    -- NOTE: filter out blank lines otherwise the parser fails
    for _,line in ipairs(lines) do
      if line ~= "" then
        buffer_text = buffer_text..'\n' .. line
      end
    end
    if buffer_text == "" then return end
    -- parsing the buffer text should NOT throw an error just fail silently for now
    local success, parsed_lines = pcall(yaml.eval, buffer_text)
    if not success then return end
    local deps = parsed_lines.dependencies
    if deps and not vim.tbl_isempty(deps) then
      api.check_outdated_packages(deps, function (latest)
        local lnum
        -- FIXME this matches any lines where the name is the
        -- not specifically the one dependency
        for idx, line in ipairs(lines) do
          if line:match(latest.name..':') then lnum = idx - 1 end
        end
        if lnum then callback(lnum, latest.version) end
      end)
    end
  end
end

--- Find the path of the project's pubspec.yaml
--- @param buf_id number
local function find_pubspec_file(buf_id)
  local dirname = helpers.find_dependency_file(buf_id, function(dir)
    return vim.fn.filereadable(helpers.path_join(dir, dependency_file)) == 1
  end)
  return helpers.path_join(dirname, dependency_file)
end


local dart = {
  api = api,
  filename = dependency_file,
  formatter = formatter,
  show_versions = show_dart_versions,
  find_dependency_file = find_pubspec_file,
  extension = extension
}

return dart
