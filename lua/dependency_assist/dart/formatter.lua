require("dependency_assist/utils/levenshtein_distance")

local M = {}

function M.format_packages(content)
  local next_url = content.next_url
  local packages = {}
  for _, pkg in ipairs(content.packages) do
    local str = pkg.name .. ", version: " .. pkg.latest.version
    table.insert(packages, str)
  end
  return packages, next_url
end

function M.format_package_details(data)
  local result = {}
  local name
  if not data or not data.versions then
    return result
  end
  for i = #data.versions, 1, -1 do
    local pkg = data.versions[i]
    if not name then
      name = pkg.pubspec.name
    end
    table.insert(result, pkg.pubspec.name .. ": " .. pkg.version)
  end
  return result, name
end

function M.update_version(line, version)
  local version_regex = [[\zs[0-9\.\*+]\+\ze]]
  local quoted_regex = [[\v([''"])(.{-})\1]]
  local quoted = vim.fn.matchstr(line, quoted_regex)
  local regex = quoted ~= "" and quoted_regex or version_regex
  return vim.fn.substitute(line, regex, version, "")
end

return M
