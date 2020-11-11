local M = {}

function M.format_packages(content)
  print("content:" .. vim.inspect(content))
  return {}, nil
end

function M.format_package_details(name, version)
  return name .. " = " .. string.format('"%s"', version)
end

function M.update_version(line, version)
  print("line:" .. vim.inspect(line))
  print("version:" .. vim.inspect(version))
  return ""
end

return M
