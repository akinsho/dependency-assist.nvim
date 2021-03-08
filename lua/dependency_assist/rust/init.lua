local api = require "dependency_assist/rust/crates_api"
local formatter = require "dependency_assist/rust/formatter"
local helpers = require "dependency_assist/utils/helpers"
local TOML = require "dependency_assist/toml"

local extension = "rs"
local dependency_file = "Cargo.toml"
local dev_block = "[dev-dependencies]"
local dependency_block = "[dependencies]"

local rust = {
  api = api,
  extension = extension,
  formatter = formatter,
  filename = dependency_file
}

function rust.find_dependency_file(buf_id)
  return helpers.find(buf_id, dependency_file)
end

---@param packages table
---@param callback function
function rust.get_packages(packages, callback)
  local versions = {}
  for _, pkg in ipairs(packages) do
    table.insert(
      versions,
      formatter.format_package_details(pkg.name, pkg.newest_version)
    )
  end
  callback(versions)
end

function rust.insert_dependencies(dependencies, is_dev)
  local target = is_dev and dev_block or dependency_block
  local location = vim.fn.searchpos(target)
  local lnum = location[1]
  vim.fn.append(lnum, dependencies)
end

--- @param dependencies table
--- @param lines table
--- @param callback function
local function report_outdated_packages(dependencies, lines, callback)
  if dependencies and not vim.tbl_isempty(dependencies) then
    api.check_outdated_packages(
      dependencies,
      function(pkg)
        local version = pkg.crate.newest_version
        local name = pkg.crate.name
        for lnum, line in ipairs(lines) do
          if line:match(name) then
            callback(lnum - 1, version)
          end
        end
      end
    )
  end
end

function rust.show_versions(buf_id, callback)
  local lines = vim.api.nvim_buf_get_lines(buf_id, 0, -1, false)
  local output = TOML.parse(table.concat(lines, "\n"))
  local dependencies = output and output.dependencies or {}
  local dev_dependencies = output and output.dev_dependencies or {}
  local deps = vim.tbl_extend("force", dependencies, dev_dependencies)
  for k, v in pairs(deps) do
    if type(v) == "table" then
      deps[k] = v.version
    end
  end
  report_outdated_packages(deps, lines, callback)
end

function rust.process_search_results(results)
  local selected = {}
  local found = {}
  for input, result in pairs(results) do
    found[input] = false
    for _, crate in ipairs(result.crates) do
      if crate.exact_match then
        table.insert(selected, crate)
        found[input] = true
        break
      end
    end
    if not found[input] then
      table.insert(selected, result.crates[1])
    end
  end
  return selected
end

return rust
