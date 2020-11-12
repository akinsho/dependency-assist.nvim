local M = {}

function M.update_version(line, version)
  local is_version_table = line:match("version%s*=%s*")
  local version_regex = [[version\s*=\s*"\zs[0-9\.\*]\+\ze"]]
  local string_regex = [["\zs[0-9\.\*]\+\ze"]]
  local regex = is_version_table and version_regex or string_regex
  return vim.fn.substitute(line, regex, version, "")
end

function M.format_package_details(name, version)
  return name .. " = " .. string.format('"%s"', version)
end

return M
