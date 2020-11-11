local api = require "dependency_assist/rust/crates_api"
local formatter = require "dependency_assist/rust/formatter"
local helpers = require "dependency_assist/utils/helpers"

local extension = "rs"
local dependency_file = "Cargo.toml"
local dev_block = "[dev_dependencies]"
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

function rust.show_versions(buf_id, callback)
  -- TODO parse dependency_file and get the dependencies
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
