local yaml = require "dependency_assist/yaml"
local api = require "dependency_assist/dart/pubspec_api"
local formatter = require "dependency_assist/dart/formatter"
local helpers = require "dependency_assist/utils/helpers"

local extension = "dart"
local dependency_file = "pubspec.yaml"
local dev_block = "devDependencies:"
local dependency_block = "dependencies:"

local dart = {
  api = api,
  extension = extension,
  formatter = formatter,
  filename = dependency_file
}

--- @param name string
--- @param version string
--- @param line string
local function is_matching_pkg(name, version, line)
  if helpers.any(helpers.is_empty, line, name, version) then
    return false
  end
  local escaped = helpers.escape_pattern(version)
  return line:gsub('"', ""):match(name .. ": " .. escaped)
end

--- This function determines position of dependencies by searching through
--- the relevant buffer content. Ideally it should only check the relevant sections
--- @param deps table
--- @param lines table
--- @param callback function
local function report_outdated_packages(deps, lines, callback)
  if deps and not vim.tbl_isempty(deps) then
    api.check_outdated_packages(
      deps,
      function(pkg)
        local lnum
        local is_string = type(pkg.previous) == "string"
        for idx, line in ipairs(lines) do
          if is_string and is_matching_pkg(pkg.name, pkg.previous, line) then
            lnum = idx - 1
          end
        end
        if lnum then
          callback(lnum, pkg.latest)
        end
      end
    )
  end
end

local function parse_pubspec(buf_id, should_truncate)
  should_truncate = should_truncate ~= nil and should_truncate or true
  local lines = vim.api.nvim_buf_get_lines(buf_id, 0, -1, false)
  if #lines > 0 then
    local buffer_text = ""
    -- NOTE: filter out blank lines otherwise the parser fails
    local dependency_section_seen = false
    for _, line in ipairs(lines) do
      -- Filter out all lines that don't relate to our dependencies
      -- unless we have specified that we should not truncate the lines
      if line:match(dependency_block) or line:match(dev_block) then
        dependency_section_seen = true
      end
      if line ~= "" and (not should_truncate or dependency_section_seen) then
        buffer_text = buffer_text .. "\n" .. line
      end
    end

    -- parsing the buffer text should NOT throw an error just fail silently for now
    if buffer_text == "" then
      return
    end
    local success, parsed_lines = pcall(yaml.eval, buffer_text)
    if not success then
      return
    end
    return parsed_lines, lines
  end
end

--- @param buf_id number
--- @param callback function
function dart.show_versions(buf_id, callback)
  local output, lines = parse_pubspec(buf_id)
  local dependencies = output and output.dependencies or {}
  local dev_dependencies = output and output.dev_dependencies or {}
  local deps = vim.tbl_extend("force", dependencies, dev_dependencies)
  report_outdated_packages(deps, lines, callback)
end

--- @param dependencies string[]
--- @param is_dev boolean
function dart.insert_dependencies(dependencies, is_dev)
  local buf_id = vim.api.nvim_get_current_buf()
  local parsed_lines, lines = parse_pubspec(buf_id, false)
  local data = is_dev and parsed_lines.dev_dependencies or parsed_lines.dependencies
  local length = vim.tbl_count(data)
  local index = 1
  local last_inserted
  -- search through our dev or main dependencies and find the last one
  -- alphabetically. We don't have another way to search since trying
  -- to use the file structure is brittle and the yaml parser doesn't
  -- give us back a line number
  for k, v in pairs(data) do
    if index == length then
      last_inserted = {name = k, version = v}
    end
    index = index + 1
  end
  local lnum
  -- Try to match the "last inserted" dependency i.e. the alphabetically
  -- furthest with a line number
  for idx, line in ipairs(lines) do
    local is_match = is_matching_pkg(last_inserted.name, last_inserted.version, line)
    if is_match then
      lnum = idx - 1
    end
  end
  if lnum then
    helpers.insert_beneath(lnum, dependencies)
  else
    helpers.echomsg("Couldn't find the last inserted dependency")
  end
end

--- Find the path of the project's pubspec.yaml
--- @param buf_id number
function dart.find_dependency_file(buf_id)
  return helpers.find(buf_id, dependency_file)
end

function dart.process_search_results(results)
  local selected = {}
  for input, result in pairs(results) do
    local match
    local score
    for _, pkg in ipairs(result.packages) do
      local distance = string.levenshtein(input, pkg.package)
      if score == nil or distance < score then
        score = distance
        match = pkg.package
      end
    end
    if match then
      table.insert(selected, match)
    end
  end
  return selected
end

function dart.get_packages(packages, callback)
  api.get_packages(
    packages,
    function(data)
      local all_latest = {}
      for _, result in pairs(data) do
        local versions = formatter.format_package_details(result)
        table.insert(all_latest, versions[1])
      end
      callback(all_latest)
    end
  )
end

return dart
