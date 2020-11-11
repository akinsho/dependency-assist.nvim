local M = {}

function M.update_version(line, version)
  -- TODO implement me!
  return ""
end

function M.format_package_details(name, version)
  return name .. " = " .. string.format('"%s"', version)
end

return M
